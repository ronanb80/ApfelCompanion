import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    let isGenerating: Bool
    let isServerReady: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Type a message...", text: $text)
                .textFieldStyle(.plain)
                .accessibilityLabel("Message Input")
                .accessibilityIdentifier("chat.input")
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .disabled(!isServerReady)

            if isGenerating {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityLabel("Stop Generation")
                .accessibilityIdentifier("chat.stop")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(!canSend)
                .accessibilityLabel("Send Message")
                .accessibilityIdentifier("chat.send")
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isServerReady
    }
}
