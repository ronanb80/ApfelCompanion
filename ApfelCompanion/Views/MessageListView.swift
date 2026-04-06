import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let isGenerating: Bool
    var onCopy: ((UUID) -> Void)?
    var onRegenerate: ((UUID) -> Void)?
    var onEditAndResend: ((UUID) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            isGenerating: isGenerating && message.id == messages.last?.id,
                            onCopy: { onCopy?(message.id) },
                            onRegenerate: message.role == .assistant
                                ? { onRegenerate?(message.id) }
                                : nil,
                            onEditAndResend: message.role == .user
                                ? { onEditAndResend?(message.id) }
                                : nil
                        )
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.last?.content) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}
