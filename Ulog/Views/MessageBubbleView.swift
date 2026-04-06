import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    var isGenerating: Bool = false

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(message.role == .user ? "chat.userLabel" : "chat.assistantLabel")

                Group {
                    if message.role == .assistant && message.content.isEmpty && isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityIdentifier("chat.assistantProgress")
                    } else {
                        Text(message.content)
                            .textSelection(.enabled)
                            .accessibilityIdentifier(message.role == .user ? "chat.userMessage" : "chat.assistantMessage")
                    }
                }
                .padding(10)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.1)
                )
                .cornerRadius(12)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
