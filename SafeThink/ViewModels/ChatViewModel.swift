import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isGenerating = false
    @Published var streamingText = ""
    @Published var tokensPerSecond: Double = 0
    @Published var currentTokenCount = 0
    @Published var maxTokenCount = 8192
    @Published var searchQuery = ""
    @Published var searchResults: [Message] = []
    @Published var selectedImages: [UIImage] = []
    @Published var attachedDocumentURL: URL?
    @Published var isWebSearchEnabled = false
    @Published var showTemplates = false
    @Published var errorMessage: String?
    @Published var showNoModelAlert = false

    private let inferenceService = InferenceService.shared
    private let databaseService = DatabaseService.shared
    private let memoryService = MemoryService.shared
    private let searchService = SearchService.shared
    private let documentService = DocumentService.shared
    private let imageService = ImageService.shared

    var contextUsage: String {
        "\(currentTokenCount) / \(maxTokenCount) tokens"
    }

    // MARK: - Conversation Management

    func loadConversations() {
        conversations = (try? databaseService.fetchConversations()) ?? []
    }

    func createNewConversation() {
        let modelId = inferenceService.loadedModelId ?? "unknown"
        let conversation = Conversation(modelId: modelId)
        try? databaseService.createConversation(conversation)
        currentConversation = conversation
        messages = []
        streamingText = ""
        loadConversations()
    }

    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversation
        messages = (try? databaseService.fetchMessages(conversationId: conversation.id)) ?? []
        streamingText = ""
    }

    func deleteConversation(_ conversation: Conversation) {
        try? databaseService.deleteConversation(id: conversation.id)
        if currentConversation?.id == conversation.id {
            currentConversation = nil
            messages = []
        }
        loadConversations()
    }

    func togglePin(_ conversation: Conversation) {
        var updated = conversation
        updated.isPinned.toggle()
        updated.updatedAt = Date()
        try? databaseService.updateConversation(updated)
        syncCurrentConversation(with: updated)
        loadConversations()
    }

    func toggleArchive(_ conversation: Conversation) {
        var updated = conversation
        updated.isArchived.toggle()
        updated.updatedAt = Date()
        try? databaseService.updateConversation(updated)
        syncCurrentConversation(with: updated)
        loadConversations()
    }

    func renameConversation(_ conversation: Conversation, to title: String) {
        var updated = conversation
        updated.title = title
        updated.updatedAt = Date()
        try? databaseService.updateConversation(updated)
        syncCurrentConversation(with: updated)
        loadConversations()
    }

    // MARK: - Message Sending

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty else { return }

        guard inferenceService.isModelLoaded else {
            showNoModelAlert = true
            return
        }

        // Create conversation if needed
        if currentConversation == nil {
            createNewConversation()
        }

        guard let conversation = currentConversation else { return }

        // Auto-title from first message
        if messages.isEmpty && !text.isEmpty {
            let title = String(text.prefix(50))
            renameConversation(conversation, to: title)
        }

        // Check for web search command
        if text.hasPrefix("/search ") {
            let query = String(text.dropFirst(8))
            inputText = ""
            await performWebSearch(query: query, in: conversation)
            return
        }

        // Handle image attachment
        let attachedImage = selectedImages.first
        var userContent = text
        var editedImagePath: String?

        if let image = attachedImage {
            let uuid = UUID().uuidString
            let preprocessed = imageService.preprocessForLLM(image)
            if let path = saveImage(preprocessed, name: "original_\(uuid)") {
                userContent = text.isEmpty ? "[IMAGE:\(path)]" : "\(text)\n[IMAGE:\(path)]"
            }

            // Parse editing intent from text
            if !text.isEmpty {
                let ops = Self.parseImageEditOperations(text)
                if !ops.isEmpty {
                    let edited = await applyImageEdits(image, operations: ops)
                    editedImagePath = saveImage(edited, name: "edited_\(uuid)")
                }
            }

            selectedImages.removeAll()
        }

        // Save user message
        let userMessage = Message(conversationId: conversation.id, role: .user, content: userContent)
        try? databaseService.createMessage(userMessage)
        messages.append(userMessage)
        inputText = ""

        // Build messages for LLM
        var llmMessages = await buildLLMMessages(userQuery: text)

        // Image attached but no recognized edit → show available operations directly
        if attachedImage != nil && editedImagePath == nil {
            let reply = """
            I can't perform that specific edit. Here are the image edits I can do:

            - **Brighten / Darken** — adjust brightness
            - **Contrast / Sharpen** — increase contrast
            - **Sepia / Vintage / Retro** — warm tone filter
            - **Black & White / Monochrome** — grayscale
            - **Vivid / Vibrant / Colorful** — boost colors
            - **Blur / Soften / Smooth** — gaussian blur
            - **Enhance / Improve / Fix** — auto-enhance
            - **Rotate / Turn** — rotate 90°
            - **Remove background / Cut out** — isolate subject

            Try describing your edit using one of these keywords.
            """
            let assistantMessage = Message(
                conversationId: conversation.id,
                role: .assistant,
                content: reply
            )
            try? databaseService.createMessage(assistantMessage)
            messages.append(assistantMessage)
            loadConversations()
            return
        }

        // Add image edit context to system prompt
        if attachedImage != nil, editedImagePath != nil {
            let desc = Self.describeImageEdits(text)
            llmMessages[0]["content"] = (llmMessages[0]["content"] ?? "") +
                "\n\nThe user attached an image and asked: \"\(text)\". These edits were applied to their image: \(desc). Briefly confirm what was done."
        }

        // Handle web search if enabled
        if isWebSearchEnabled {
            if let searchContext = try? await searchService.search(query: text) {
                let searchText = searchContext.map { "- \($0.title): \($0.snippet)" }.joined(separator: "\n")
                llmMessages.insert(
                    ["role": "system", "content": "Web search results for context:\n\(searchText)"],
                    at: 1
                )
            }
            isWebSearchEnabled = false
        }

        // Generate response
        isGenerating = true

        // Prepend edited image so it shows immediately during streaming
        if let editPath = editedImagePath {
            streamingText = "[IMAGE:\(editPath)]\n"
        } else {
            streamingText = ""
        }

        let stream = inferenceService.generate(messages: llmMessages)

        for await token in stream {
            streamingText += token
        }

        // Save assistant message
        let assistantMessage = Message(
            conversationId: conversation.id,
            role: .assistant,
            content: streamingText
        )
        try? databaseService.createMessage(assistantMessage)
        messages.append(assistantMessage)

        isGenerating = false
        tokensPerSecond = inferenceService.tokensPerSecond
        streamingText = ""
        loadConversations()
    }

    func stopGeneration() {
        inferenceService.cancelGeneration()
        if !streamingText.isEmpty, let conversation = currentConversation {
            let partialMessage = Message(
                conversationId: conversation.id,
                role: .assistant,
                content: streamingText
            )
            try? databaseService.createMessage(partialMessage)
            messages.append(partialMessage)
        }
        isGenerating = false
        streamingText = ""
    }

    func regenerateLastResponse() async {
        guard let lastAssistant = messages.last(where: { $0.role == .assistant }) else { return }
        try? databaseService.deleteMessage(id: lastAssistant.id)
        messages.removeAll { $0.id == lastAssistant.id }

        if let lastUserText = messages.last(where: { $0.role == .user })?.content {
            let llmMessages = await buildLLMMessages(userQuery: lastUserText)

            isGenerating = true
            streamingText = ""

            let stream = inferenceService.generate(messages: llmMessages)
            for await token in stream {
                streamingText += token
            }

            if let conversation = currentConversation {
                let msg = Message(conversationId: conversation.id, role: .assistant, content: streamingText)
                try? databaseService.createMessage(msg)
                messages.append(msg)
            }

            isGenerating = false
            streamingText = ""
        }
    }

    // MARK: - Edit & Resend

    func editAndResend(messageId: String, newContent: String) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        // Remove the edited message and all subsequent messages
        let toRemove = Array(messages[index...])
        for msg in toRemove {
            try? databaseService.deleteMessage(id: msg.id)
        }
        messages.removeSubrange(index...)

        // Send as new message
        inputText = newContent
        await sendMessage()
    }

    // MARK: - Search

    func searchMessages() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        searchResults = (try? databaseService.searchMessages(query: searchQuery)) ?? []
    }

    // MARK: - Web Search

    private func performWebSearch(query: String, in conversation: Conversation) async {
        let userMessage = Message(conversationId: conversation.id, role: .user, content: "/search \(query)")
        try? databaseService.createMessage(userMessage)
        messages.append(userMessage)

        isGenerating = true

        if let results = try? await searchService.search(query: query) {
            let searchContext = results.map { "- \($0.title): \($0.snippet) (\($0.url))" }.joined(separator: "\n")

            let llmMessages: [[String: String]] = [
                ["role": "system", "content": "You are SafeThink, a helpful AI assistant. Answer based on these web search results:\n\(searchContext)"],
                ["role": "user", "content": query]
            ]

            streamingText = ""
            let stream = inferenceService.generate(messages: llmMessages)
            for await token in stream {
                streamingText += token
            }

            let msg = Message(conversationId: conversation.id, role: .assistant, content: "[Web-enhanced]\n\n\(streamingText)")
            try? databaseService.createMessage(msg)
            messages.append(msg)
        }

        isGenerating = false
        streamingText = ""
    }

    // MARK: - Template

    func applyTemplate(_ template: PromptTemplate) {
        inputText = template.prompt
        showTemplates = false
    }

    // MARK: - Image Editing

    private var chatImagesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_images", isDirectory: true)
    }

    private func saveImage(_ image: UIImage, name: String) -> String? {
        let dir = chatImagesDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(name).jpg"
        let fullURL = dir.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        try? data.write(to: fullURL)
        return "chat_images/\(filename)"
    }

    static func loadChatImage(relativePath: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private enum ImageEditOp {
        case brightness(Double)
        case contrast(Double)
        case sepia
        case monochrome
        case vivid
        case blur(Double)
        case autoEnhance
        case rotate(CGFloat)
        case removeBackground
    }

    private static func parseImageEditOperations(_ text: String) -> [(description: String, op: ImageEditOp)] {
        let lowered = text.lowercased()
        var ops: [(description: String, op: ImageEditOp)] = []

        if lowered.contains("bright") || lowered.contains("lighten") || lowered.contains("lighter") {
            ops.append(("Increased brightness", .brightness(0.2)))
        }
        if lowered.contains("dark") || lowered.contains("dim") || lowered.contains("darker") {
            ops.append(("Decreased brightness", .brightness(-0.2)))
        }
        if lowered.contains("contrast") || lowered.contains("sharpen") || lowered.contains("sharp") {
            ops.append(("Increased contrast", .contrast(1.5)))
        }
        if lowered.contains("sepia") || lowered.contains("vintage") || lowered.contains("retro") {
            ops.append(("Applied sepia tone", .sepia))
        }
        if lowered.contains("warm") || lowered.contains("warmer") {
            ops.append(("Applied warm tone", .sepia))
        }
        if lowered.contains("b&w") || lowered.contains("black and white") || lowered.contains("monochrome") ||
            lowered.contains("grayscale") || lowered.contains("greyscale") {
            ops.append(("Converted to black & white", .monochrome))
        }
        if lowered.contains("vivid") || lowered.contains("vibrant") || lowered.contains("saturate") || lowered.contains("colorful") {
            ops.append(("Enhanced colors", .vivid))
        }
        if lowered.contains("blur") || lowered.contains("smooth") || lowered.contains("soften") {
            ops.append(("Applied blur", .blur(10)))
        }
        if lowered.contains("enhance") || lowered.contains("improve") || lowered.contains("fix") {
            ops.append(("Auto-enhanced", .autoEnhance))
        }
        if lowered.contains("rotate") || lowered.contains("turn") || lowered.contains("sideways") {
            ops.append(("Rotated 90°", .rotate(90)))
        }
        if lowered.contains("background") || lowered.contains("cut out") || lowered.contains("isolate") {
            ops.append(("Removed background", .removeBackground))
        }

        return ops
    }

    private static func describeImageEdits(_ text: String) -> String {
        parseImageEditOperations(text).map(\.description).joined(separator: ", ")
    }

    private func applyImageEdits(_ image: UIImage, operations: [(description: String, op: ImageEditOp)]) async -> UIImage {
        var result = image
        for (_, op) in operations {
            switch op {
            case .brightness(let val):
                result = imageService.adjustBrightnessContrast(result, brightness: val) ?? result
            case .contrast(let val):
                result = imageService.adjustBrightnessContrast(result, contrast: val) ?? result
            case .sepia:
                result = imageService.applySepia(result) ?? result
            case .monochrome:
                result = imageService.applyMonochrome(result) ?? result
            case .vivid:
                result = imageService.applyVivid(result) ?? result
            case .blur(let radius):
                result = imageService.applyBlur(result, radius: radius) ?? result
            case .autoEnhance:
                result = imageService.autoEnhance(result) ?? result
            case .rotate(let degrees):
                result = imageService.rotate(result, degrees: degrees)
            case .removeBackground:
                result = (try? await imageService.removeBackground(result)) ?? result
            }
        }
        return result
    }

    // MARK: - Helpers

    private func buildLLMMessages(userQuery: String) async -> [[String: String]] {
        var llmMessages: [[String: String]] = []

        // System prompt with memory context
        let memoryContext = await memoryService.buildMemoryContext(for: userQuery)
        var systemPrompt = "You are SafeThink, a helpful, accurate, and privacy-focused AI assistant running entirely on the user's device. Be concise and helpful."
        if !memoryContext.isEmpty {
            systemPrompt += "\n\n\(memoryContext)"
        }
        llmMessages.append(["role": "system", "content": systemPrompt])

        // Recent conversation history (keep within context window)
        let recentMessages = messages.suffix(20) // Keep last 20 messages for context
        for msg in recentMessages {
            llmMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Current user message (if not already in history)
        if messages.last?.content != userQuery {
            llmMessages.append(["role": "user", "content": userQuery])
        }

        return llmMessages
    }

    private func syncCurrentConversation(with updated: Conversation) {
        guard currentConversation?.id == updated.id else { return }
        currentConversation = updated
    }

    // MARK: - Grouped Conversations

    var pinnedConversations: [Conversation] {
        conversations.filter { $0.isPinned && !$0.isArchived }
    }

    var todayConversations: [Conversation] {
        conversations.filter { !$0.isPinned && !$0.isArchived && Calendar.current.isDateInToday($0.updatedAt) }
    }

    var yesterdayConversations: [Conversation] {
        conversations.filter { !$0.isPinned && !$0.isArchived && Calendar.current.isDateInYesterday($0.updatedAt) }
    }

    var thisWeekConversations: [Conversation] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return conversations.filter {
            !$0.isPinned && !$0.isArchived &&
            !calendar.isDateInToday($0.updatedAt) &&
            !calendar.isDateInYesterday($0.updatedAt) &&
            $0.updatedAt > weekAgo
        }
    }

    var olderConversations: [Conversation] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return conversations.filter {
            !$0.isPinned && !$0.isArchived && $0.updatedAt <= weekAgo
        }
    }
}
