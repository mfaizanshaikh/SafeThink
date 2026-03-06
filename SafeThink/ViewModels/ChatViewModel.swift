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

    private let inferenceService = InferenceService.shared
    private let databaseService = DatabaseService.shared
    private let memoryService = MemoryService.shared
    private let searchService = SearchService.shared
    private let documentService = DocumentService.shared

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
        loadConversations()
    }

    func toggleArchive(_ conversation: Conversation) {
        var updated = conversation
        updated.isArchived.toggle()
        updated.updatedAt = Date()
        try? databaseService.updateConversation(updated)
        loadConversations()
    }

    func renameConversation(_ conversation: Conversation, to title: String) {
        var updated = conversation
        updated.title = title
        updated.updatedAt = Date()
        try? databaseService.updateConversation(updated)
        loadConversations()
    }

    // MARK: - Message Sending

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Create conversation if needed
        if currentConversation == nil {
            createNewConversation()
        }

        guard let conversation = currentConversation else { return }

        // Auto-title from first message
        if messages.isEmpty {
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

        // Save user message
        let userMessage = Message(conversationId: conversation.id, role: .user, content: text)
        try? databaseService.createMessage(userMessage)
        messages.append(userMessage)
        inputText = ""

        // Build messages for LLM
        var llmMessages = await buildLLMMessages(userQuery: text)

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
        streamingText = ""

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
