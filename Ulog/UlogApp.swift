import SwiftUI

@main
struct UlogApp: App {
    @State private var apfelService = ApfelService()

    var body: some Scene {
        WindowGroup("Ulog") {
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                ContentView(viewModel: Self.makeUITestViewModel())
            } else {
                ContentView(apfelService: apfelService)
            }
        }
        .defaultSize(width: 600, height: 700)
    }

    private static func makeUITestViewModel() -> ChatViewModel {
        let apfelService = ApfelService()
        apfelService.setStatusForTesting(.ready)

        return ChatViewModel(
            apfelService: apfelService,
            chatClient: UITestChatClient()
        )
    }
}

private final class UITestChatClient: ChatClientProtocol {
    func sendMessage(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let response = Self.response(for: messages.last?.content ?? "")

        return AsyncThrowingStream { continuation in
            let task = Task {
                for token in response {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    continuation.yield(token)
                    try? await Task.sleep(for: .milliseconds(120))
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func response(for input: String) -> [String] {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmedInput.isEmpty ? "Ready for input." : "Stub reply to: \(trimmedInput)"
        return text.map(String.init)
    }
}
