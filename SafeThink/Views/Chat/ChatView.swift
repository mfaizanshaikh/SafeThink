import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var voiceService = VoiceService.shared
    @State private var showConversationList = false
    @State private var showAttachmentMenu = false
    @State private var editingMessageId: String?
    @State private var editText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                onRegenerate: {
                                    Task { await viewModel.regenerateLastResponse() }
                                },
                                onEdit: message.role == .user ? {
                                    editingMessageId = message.id
                                    editText = message.content
                                } : nil
                            )
                            .id(message.id)
                        }

                        // Streaming response
                        if viewModel.isGenerating && !viewModel.streamingText.isEmpty {
                            MessageBubbleView(
                                message: Message(
                                    conversationId: "",
                                    role: .assistant,
                                    content: viewModel.streamingText
                                ),
                                isStreaming: true
                            )
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id ?? "streaming", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            // Voice recording indicator
            if voiceService.isRecording {
                HStack(spacing: 8) {
                    WaveformView(audioLevel: voiceService.audioLevel, isRecording: true)
                    Text(voiceService.transcribedText.isEmpty ? "Listening..." : voiceService.transcribedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        voiceService.stopRecording()
                        if !voiceService.transcribedText.isEmpty {
                            viewModel.inputText = voiceService.transcribedText
                        }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
            }

            // Context indicator
            if viewModel.currentConversation != nil {
                HStack {
                    Text(viewModel.contextUsage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.isGenerating {
                        Text("\(viewModel.tokensPerSecond, specifier: "%.1f") tok/s")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Divider()

            // Input bar
            InputBarView(
                text: $viewModel.inputText,
                isGenerating: viewModel.isGenerating,
                onSend: { Task { await viewModel.sendMessage() } },
                onStop: { viewModel.stopGeneration() },
                onAttachment: { showAttachmentMenu = true },
                onMic: { toggleVoiceInput() },
                onTemplate: { viewModel.showTemplates = true }
            )
        }
        .navigationTitle(viewModel.currentConversation?.title ?? "SafeThink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showConversationList = true
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.createNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showConversationList) {
            ConversationListView(viewModel: viewModel, isPresented: $showConversationList)
        }
        .sheet(isPresented: $showAttachmentMenu) {
            AttachmentMenuView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showTemplates) {
            PromptTemplateView(onSelect: { template in
                viewModel.applyTemplate(template)
            })
            .presentationDetents([.medium])
        }
        .alert("Edit Message", isPresented: .init(
            get: { editingMessageId != nil },
            set: { if !$0 { editingMessageId = nil } }
        )) {
            TextField("Edit message", text: $editText)
            Button("Cancel", role: .cancel) { editingMessageId = nil }
            Button("Send") {
                if let id = editingMessageId {
                    Task { await viewModel.editAndResend(messageId: id, newContent: editText) }
                    editingMessageId = nil
                }
            }
        }
        .onAppear {
            viewModel.loadConversations()
        }
    }

    private func toggleVoiceInput() {
        if voiceService.isRecording {
            voiceService.stopRecording()
            if !voiceService.transcribedText.isEmpty {
                viewModel.inputText = voiceService.transcribedText
            }
        } else {
            Task {
                let authorized = await voiceService.requestAuthorization()
                if authorized {
                    try? voiceService.startRecording()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
