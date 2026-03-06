import SwiftUI
import MarkdownUI

struct MessageBubbleView: View {
    let message: Message
    var isStreaming: Bool = false
    var onRegenerate: (() -> Void)?

    @State private var showActions = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Content
                if message.role == .assistant {
                    Markdown(message.content)
                        .markdownTheme(.gitHub)
                        .textSelection(.enabled)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                }

                // Streaming cursor
                if isStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .opacity(isStreaming ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: isStreaming)
                    }
                }

                // Web-enhanced badge
                if message.content.hasPrefix("[Web-enhanced]") {
                    Label("Web-enhanced", systemImage: "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                // Token stats
                if let tokSec = message.tokensPerSec, tokSec > 0 {
                    Text("\(tokSec, specifier: "%.1f") tok/s")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(message.role == .user ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                if message.role == .assistant, let onRegenerate {
                    Button {
                        onRegenerate()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

#Preview {
    VStack {
        MessageBubbleView(message: Message(conversationId: "1", role: .user, content: "Hello!"))
        MessageBubbleView(message: Message(conversationId: "1", role: .assistant, content: "Hi! How can I help you?"))
    }
    .padding()
}
