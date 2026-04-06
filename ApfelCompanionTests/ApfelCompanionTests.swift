import Foundation
import Testing
#if canImport(PDFKit)
import PDFKit
#endif
@testable import ApfelCompanion

@Suite("Chat View Model")
struct ChatViewModelTests {
    @Test("Chat messages parse markdown for rendering")
    func chatMessagesParseMarkdownForRendering() {
        let message = ChatMessage(role: .assistant, content: "**Bold** and *italic*")

        #expect(String(message.renderedContent.characters) == "Bold and italic")
        #expect(message.renderedContent.runs.contains { run in
            run.inlinePresentationIntent == .stronglyEmphasized
        })
        #expect(message.renderedContent.runs.contains { run in
            run.inlinePresentationIntent == .emphasized
        })
    }

    @Test("Chat messages preserve line breaks when rendering markdown")
    func chatMessagesPreserveLineBreaksWhenRenderingMarkdown() {
        let message = ChatMessage(role: .assistant, content: "First line\nSecond line\n\nThird line")

        #expect(String(message.renderedContent.characters) == "First line\nSecond line\n\nThird line")
    }

    @Test("Chat messages fall back to plain text when markdown cannot be parsed")
    func chatMessagesFallbackToPlainTextWhenMarkdownParsingFails() {
        let message = ChatMessage(role: .assistant, content: "[broken](not a valid url")

        #expect(String(message.renderedContent.characters) == "[broken](not a valid url")
    }

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
    @Test("Saved drafts are restored on next launch")
    func savedDraftsAreRestoredOnNextLaunch() {
        let persistence = TestChatPersistence()
        let viewModel = makeViewModel(persistence: persistence)

        viewModel.inputText = "Unsent draft"
        viewModel.saveNowForTesting()

        let restoredViewModel = makeViewModel(persistence: persistence)

        #expect(restoredViewModel.chats.count == 1)
        #expect(restoredViewModel.inputText == "Unsent draft")
    }

    @MainActor
    @Test("In-flight assistant replies are not persisted")
    func inflightAssistantRepliesAreNotPersisted() {
        let persistence = TestChatPersistence()
        let viewModel = makeViewModel(persistence: persistence)

        let chatID = viewModel.selectedChatID
        viewModel.chats[0] = ChatSession(
            id: chatID,
            title: "Test",
            messages: [
                ChatMessage(role: .user, content: "Hello"),
                ChatMessage(role: .assistant, content: "Partial", timestamp: Date())
            ],
            draft: "",
            isGenerating: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        viewModel.saveNowForTesting()

        let restoredViewModel = makeViewModel(persistence: persistence)
        #expect(restoredViewModel.messages.count == 1)
        #expect(restoredViewModel.messages[0].role == .user)
        #expect(restoredViewModel.messages[0].content == "Hello")
        #expect(!restoredViewModel.isGenerating)
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
    @Test("System prompt is forwarded in request options")
    func systemPromptIsForwardedInRequestOptions() async {
        let client = StubChatClient(response: "Reply")
        let settingsPersistence = TestSettingsPersistence()
        settingsPersistence.settings = AppSettings(systemPrompt: "You are helpful")
        let viewModel = makeViewModel(chatClient: client, settingsPersistence: settingsPersistence)

        viewModel.inputText = "Hello"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        #expect(client.lastOptions?.systemPrompt == "You are helpful")
    }

    @MainActor
    @Test("Empty system prompt sends nil in options")
    func emptySystemPromptSendsNilInOptions() async {
        let client = StubChatClient(response: "Reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.inputText = "Hello"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        #expect(client.lastOptions?.systemPrompt == nil)
    }

    @MainActor
    @Test("Temperature and max tokens are forwarded when set")
    func temperatureAndMaxTokensForwarded() async {
        let client = StubChatClient(response: "Reply")
        let settingsPersistence = TestSettingsPersistence()
        settingsPersistence.settings = AppSettings(temperature: 0.7, maxTokens: 1024)
        let viewModel = makeViewModel(chatClient: client, settingsPersistence: settingsPersistence)

        viewModel.inputText = "Hello"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        #expect(client.lastOptions?.temperature == 0.7)
        #expect(client.lastOptions?.maxTokens == 1024)
    }

    @MainActor
    @Test("Initial settings are restored from persistence")
    func initialSettingsAreRestoredFromPersistence() {
        let settingsPersistence = TestSettingsPersistence()
        settingsPersistence.settings = AppSettings(
            systemPrompt: "Be concise",
            temperature: 0.3,
            maxTokens: 512
        )

        let viewModel = makeViewModel(settingsPersistence: settingsPersistence)

        #expect(viewModel.settings.systemPrompt == "Be concise")
        #expect(viewModel.settings.temperature == 0.3)
        #expect(viewModel.settings.maxTokens == 512)
    }

    @MainActor
    @Test("Saving settings writes the latest values")
    func savingSettingsWritesTheLatestValues() throws {
        let settingsPersistence = TestSettingsPersistence()
        let viewModel = makeViewModel(settingsPersistence: settingsPersistence)

        viewModel.settings.systemPrompt = "Use markdown"
        viewModel.settings.temperature = 1.4
        viewModel.settings.maxTokens = 4096
        viewModel.saveSettings()

        let savedSettings = try #require(settingsPersistence.savedSettings)
        #expect(savedSettings.systemPrompt == "Use markdown")
        #expect(savedSettings.temperature == 1.4)
        #expect(savedSettings.maxTokens == 4096)
    }

    @MainActor
    @Test("File attachments are prepended to message content")
    func fileAttachmentsArePrependedToMessageContent() async {
        let client = StubChatClient(response: "Reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.pendingAttachments = [
            PendingAttachment(fileName: "test.txt", content: "file content here")
        ]
        viewModel.inputText = "What does this file do?"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        let userMessage = viewModel.messages[0]
        #expect(userMessage.content.contains("--- File: test.txt ---"))
        #expect(userMessage.content.contains("file content here"))
        #expect(userMessage.content.contains("What does this file do?"))
    }

    @MainActor
    @Test("Attachments are cleared after sending")
    func attachmentsAreClearedAfterSending() async {
        let client = StubChatClient(response: "Reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.pendingAttachments = [
            PendingAttachment(fileName: "test.txt", content: "content")
        ]
        viewModel.inputText = "Hello"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        #expect(viewModel.pendingAttachments.isEmpty)
    }

    @MainActor
    @Test("Adding attachments reads UTF-8 file contents")
    func addingAttachmentsReadsUTF8FileContents() throws {
        let viewModel = makeViewModel()
        let url = try makeTemporaryFile(
            named: "Notes.swift",
            contents: "print(\"hello\")"
        )

        viewModel.addAttachments(urls: [url])

        #expect(viewModel.pendingAttachments.count == 1)
        #expect(viewModel.pendingAttachments[0].fileName == "Notes.swift")
        #expect(viewModel.pendingAttachments[0].content == "print(\"hello\")")
    }

    @MainActor
    @Test("Adding attachments extracts PDF text")
    func addingAttachmentsExtractsPDFText() throws {
        let viewModel = makeViewModel()
        let url = try makeTemporaryPDF(named: "Notes.pdf", text: "Quarterly summary")

        viewModel.addAttachments(urls: [url])

        #expect(viewModel.pendingAttachments.count == 1)
        #expect(viewModel.pendingAttachments[0].fileName == "Notes.pdf")
        #expect(viewModel.pendingAttachments[0].content.contains("Quarterly summary"))
    }

    @MainActor
    @Test("Adding attachments skips files larger than one hundred kilobytes")
    func addingAttachmentsSkipsOversizedFiles() throws {
        let viewModel = makeViewModel()
        let oversizedContents = String(repeating: "A", count: 100 * 1024 + 1)
        let url = try makeTemporaryFile(
            named: "Large.txt",
            contents: oversizedContents
        )

        viewModel.addAttachments(urls: [url])

        #expect(viewModel.pendingAttachments.isEmpty)
    }

    @MainActor
    @Test("Removing attachments deletes only the matching item")
    func removingAttachmentsDeletesOnlyMatchingItem() {
        let viewModel = makeViewModel()
        let firstAttachment = PendingAttachment(fileName: "First.txt", content: "one")
        let secondAttachment = PendingAttachment(fileName: "Second.txt", content: "two")
        viewModel.pendingAttachments = [firstAttachment, secondAttachment]

        viewModel.removeAttachment(id: firstAttachment.id)

        #expect(viewModel.pendingAttachments == [secondAttachment])
    }

    @MainActor
    @Test("Regenerate removes assistant message and re-streams")
    func regenerateRemovesAssistantAndRestreams() async {
        let client = StubChatClient(response: "Original reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.inputText = "Hello"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        let assistantMessageID = viewModel.messages[1].id
        client.nextResponse = "Regenerated reply"

        viewModel.regenerateMessage(id: assistantMessageID)
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[1].content == "Regenerated reply")
    }

    @MainActor
    @Test("Edit and resend puts content back in draft")
    func editAndResendPutsContentBackInDraft() async {
        let client = StubChatClient(response: "Reply")
        let viewModel = makeViewModel(chatClient: client)

        viewModel.inputText = "First message"
        viewModel.sendMessage()
        await waitForMessageCount(in: viewModel, expectedCount: 2)

        let userMessageID = viewModel.messages[0].id
        viewModel.editAndResend(id: userMessageID)

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.inputText == "First message")
    }

    @MainActor
    private func makeViewModel(
        chatClient: (any ChatClientProtocol)? = nil,
        persistence: (any ChatPersistenceProtocol)? = nil,
        settingsPersistence: (any SettingsPersistenceProtocol)? = nil
    ) -> ChatViewModel {
        let apfelService = ApfelService()
        apfelService.setStatusForTesting(.ready)
        return ChatViewModel(
            apfelService: apfelService,
            chatClient: chatClient,
            persistence: persistence ?? TestChatPersistence(),
            settingsPersistence: settingsPersistence ?? TestSettingsPersistence()
        )
    }

    private func makeTemporaryFile(named name: String, contents: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent(name)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func makeTemporaryPDF(named name: String, text: String) throws -> URL {
        #if canImport(PDFKit)
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(name)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = .systemFont(ofSize: 18)

        let page = PDFPage()
        page.setBounds(bounds, for: .mediaBox)
        page.addAnnotation(annotation)

        let document = PDFDocument()
        document.insert(page, at: 0)

        guard document.write(to: fileURL) else {
            throw NSError(domain: "ApfelCompanionTests", code: 1)
        }

        return fileURL
        #else
        throw NSError(domain: "ApfelCompanionTests", code: 2)
        #endif
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
    var nextResponse: String?
    private(set) var lastMessages: [ChatMessage] = []
    private(set) var lastOptions: ChatRequestOptions?

    init(response: String) {
        self.response = response
    }

    func sendMessage(messages: [ChatMessage], options: ChatRequestOptions) -> AsyncThrowingStream<String, Error> {
        lastMessages = messages
        lastOptions = options
        let response = nextResponse ?? self.response
        nextResponse = nil

        return AsyncThrowingStream { continuation in
            continuation.yield(response)
            continuation.finish()
        }
    }
}

private final class TestChatPersistence: ChatPersistenceProtocol {
    private(set) var state: PersistedChatState?

    func loadState() throws -> PersistedChatState? {
        state
    }

    func saveState(_ state: PersistedChatState) throws {
        self.state = state
    }
}

private final class TestSettingsPersistence: SettingsPersistenceProtocol {
    var settings: AppSettings?
    private(set) var savedSettings: AppSettings?

    func loadSettings() throws -> AppSettings? {
        settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        self.settings = settings
        self.savedSettings = settings
    }
}
