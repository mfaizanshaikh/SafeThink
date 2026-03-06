import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showConversationList = false
    @State private var showAttachmentMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message, onRegenerate: {
                                Task { await viewModel.regenerateLastResponse() }
                            })
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
                onMic: {},
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
        .onAppear {
            viewModel.loadConversations()
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
