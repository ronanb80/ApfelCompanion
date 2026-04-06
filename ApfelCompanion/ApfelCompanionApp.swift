import SwiftUI

@main
struct ApfelCompanionApp: App {
    @State private var viewModel: ChatViewModel

    init() {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            _viewModel = State(initialValue: Self.makeUITestViewModel())
        } else {
            _viewModel = State(initialValue: ChatViewModel(apfelService: ApfelService()))
        }
    }

    var body: some Scene {
        WindowGroup("Apfel Companion") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 600, height: 700)
        .commands {
            CommandMenu("Chats") {
                Button("New Chat") {
                    viewModel.createChat()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Clear All History") {
                    viewModel.clearAllHistory()
                }
                .disabled(!viewModel.canDeleteChats && !viewModel.canClearSelectedChat)
            }
        }

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }

    private static func makeUITestViewModel() -> ChatViewModel {
        let apfelService = ApfelService()
        apfelService.setStatusForTesting(.ready)
        let settingsPersistence: any SettingsPersistenceProtocol

        if let settingsPath = ProcessInfo.processInfo.environment["APFEL_UI_TEST_SETTINGS_PATH"] {
            settingsPersistence = FileSettingsPersistence(fileURL: URL(fileURLWithPath: settingsPath))
        } else {
            settingsPersistence = FileSettingsPersistence()
        }

        return ChatViewModel(
            apfelService: apfelService,
            chatClient: UITestChatClient(),
            persistence: InMemoryChatPersistence(),
            settingsPersistence: settingsPersistence
        )
    }
}

private final class UITestChatClient: ChatClientProtocol {
    func sendMessage(messages: [ChatMessage], options: ChatRequestOptions) -> AsyncThrowingStream<String, Error> {
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

private final class InMemoryChatPersistence: ChatPersistenceProtocol {
    private var state: PersistedChatState?

    func loadState() throws -> PersistedChatState? {
        state
    }

    func saveState(_ state: PersistedChatState) throws {
        self.state = state
    }
}
