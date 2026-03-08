import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    let isGenerating: Bool
    var hasAttachment: Bool = false
    let onSend: () -> Void
    let onStop: () -> Void
    let onAttachment: () -> Void
    let onMic: () -> Void
    let onTemplate: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attachment button
            Button(action: onAttachment) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }

            // Template button
            Button(action: onTemplate) {
                Image(systemName: "text.badge.star")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Text field
            TextField("Message SafeThink...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Mic button
            Button(action: onMic) {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Send / Stop button
            if isGenerating {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasAttachment ? Color.gray : Color.accentColor)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasAttachment)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    InputBarView(
        text: .constant("Hello"),
        isGenerating: false,
        onSend: {},
        onStop: {},
        onAttachment: {},
        onMic: {},
        onTemplate: {}
    )
}
