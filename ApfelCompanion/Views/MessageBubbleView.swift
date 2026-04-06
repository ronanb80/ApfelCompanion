import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    var isGenerating: Bool = false
    var onCopy: (() -> Void)?
    var onRegenerate: (() -> Void)?
    var onEditAndResend: (() -> Void)?
    @State private var showsCopyConfirmation = false
    @State private var copyFeedbackTask: Task<Void, Never>?

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
                        Text(message.renderedContent)
                            .textSelection(.enabled)
                            .accessibilityIdentifier(
                                message.role == .user ? "chat.userMessage" : "chat.assistantMessage"
                            )
                    }
                }
                .padding(10)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.1)
                )
                .cornerRadius(12)

                if message.role == .assistant, !message.content.isEmpty {
                    assistantActions
                }
            }
            .contextMenu {
                if let onCopy {
                    Button("Copy", action: onCopy)
                }

                if let onRegenerate {
                    Button("Regenerate", action: onRegenerate)
                        .disabled(isGenerating)
                }

                if let onEditAndResend {
                    Button("Edit & Resend", action: onEditAndResend)
                        .disabled(isGenerating)
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var assistantActions: some View {
        HStack(spacing: 8) {
            if let onCopy {
                Button(action: {
                    onCopy()
                    showCopyFeedback()
                }) {
                    Label(
                        showsCopyConfirmation ? "Copied" : "Copy",
                        systemImage: showsCopyConfirmation ? "checkmark" : "doc.on.doc"
                    )
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .accessibilityLabel("Copy Assistant Message")
                .accessibilityIdentifier("chat.assistantCopy")
                .accessibilityValue(showsCopyConfirmation ? "copied" : "idle")
                .help(showsCopyConfirmation ? "Copied" : "Copy response")
            }
        }
    }

    private func showCopyFeedback() {
        copyFeedbackTask?.cancel()
        showsCopyConfirmation = true

        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showsCopyConfirmation = false
                copyFeedbackTask = nil
            }
        }
    }
}
