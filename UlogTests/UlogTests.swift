import Foundation
import Testing
@testable import Ulog

@Suite("Chat View Model")
struct ChatViewModelTests {
    @MainActor
    @Test("Initial state creates one empty chat")
    func initialStateCreatesOneEmptyChat() {
        let viewModel = makeViewModel()

        #expect(viewModel.chats.count == 1)
        #expect(viewModel.selectedChat.displayTitle == "New Chat")
        #expect(viewModel.selectedChat.messages.isEmpty)
        #expect(viewModel.inputText.isEmpty)
    }

    @MainActor
    @Test("Creating a new chat keeps prior conversations isolated")
    func creatingNewChatKeepsPriorConversationsIsolated() async {
        let client = StubChatClient(response: "Stubbed reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.inputText = "First conversation"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        let firstChatID = viewModel.selectedChatID
        viewModel.createChat()

        #expect(viewModel.chats.count == 2)
        #expect(viewModel.selectedChatID != firstChatID)
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.selectedChat.displayTitle == "New Chat")

        viewModel.selectChat(id: firstChatID)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].content == "First conversation")
        #expect(viewModel.messages[1].content == "Stubbed reply")
        #expect(viewModel.selectedChat.displayTitle == "First conversation")
    }

    @MainActor
    @Test("Deleting the selected chat falls back to a remaining chat")
    func deletingSelectedChatFallsBackToRemainingChat() {
        let viewModel = makeViewModel()

        let originalChatID = viewModel.selectedChatID
        viewModel.createChat()
        let newestChatID = viewModel.selectedChatID

        #expect(viewModel.chats.count == 2)

        viewModel.deleteChats(at: IndexSet(integer: 0))

        #expect(viewModel.chats.count == 1)
        #expect(viewModel.selectedChatID == originalChatID)
        #expect(viewModel.selectedChatID != newestChatID)
    }

    @MainActor
    @Test("Trash action is disabled for a single empty chat")
    func trashActionIsDisabledForSingleEmptyChat() {
        let viewModel = makeViewModel()

        #expect(!viewModel.canTrashSelectedChat)
    }

    @MainActor
    @Test("Deleting the last remaining chat is ignored")
    func deletingLastRemainingChatIsIgnored() {
        let viewModel = makeViewModel()
        let originalChatID = viewModel.selectedChatID

        viewModel.deleteChats(at: IndexSet(integer: 0))

        #expect(viewModel.chats.count == 1)
        #expect(viewModel.selectedChatID == originalChatID)
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.selectedChat.displayTitle == "New Chat")
    }

    @MainActor
    @Test("Trash action deletes the selected chat when another chat exists")
    func trashActionDeletesSelectedChatWhenAnotherChatExists() {
        let viewModel = makeViewModel()
        let originalChatID = viewModel.selectedChatID

        viewModel.createChat()
        let newChatID = viewModel.selectedChatID

        #expect(viewModel.canTrashSelectedChat)

        viewModel.trashSelectedChat()

        #expect(viewModel.chats.count == 1)
        #expect(viewModel.selectedChatID == originalChatID)
        #expect(viewModel.selectedChatID != newChatID)
        #expect(!viewModel.canTrashSelectedChat)
    }

    @MainActor
    @Test("Trash action clears the only chat when it has content")
    func trashActionClearsOnlyChatWhenItHasContent() async {
        let client = StubChatClient(response: "Stubbed reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.inputText = "Solo conversation"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        #expect(viewModel.canTrashSelectedChat)
        #expect(viewModel.chats.count == 1)

        viewModel.trashSelectedChat()

        #expect(viewModel.chats.count == 1)
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText.isEmpty)
        #expect(!viewModel.canTrashSelectedChat)
    }

    @MainActor
    private func makeViewModel(chatClient: (any ChatClientProtocol)? = nil) -> ChatViewModel {
        let apfelService = ApfelService()
        apfelService.setStatusForTesting(.ready)
        return ChatViewModel(apfelService: apfelService, chatClient: chatClient)
    }

    @MainActor
    private func waitForMessageCount(in viewModel: ChatViewModel, expectedCount: Int) async {
        for _ in 0..<50 {
            if viewModel.messages.count == expectedCount, !viewModel.isGenerating {
                return
            }

            try? await Task.sleep(for: .milliseconds(20))
        }

        Issue.record("Timed out waiting for \(expectedCount) messages")
    }
}

private final class StubChatClient: ChatClientProtocol {
    private let response: String

    init(response: String) {
        self.response = response
    }

    func sendMessage(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(response)
            continuation.finish()
        }
    }
}
