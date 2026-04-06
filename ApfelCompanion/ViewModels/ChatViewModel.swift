#if canImport(AppKit)
import AppKit
#endif
import Foundation

@MainActor
@Observable
class ChatViewModel {
    var chats: [ChatSession]
    var selectedChatID: ChatSession.ID
    var settings: AppSettings
    var pendingAttachments: [PendingAttachment] = []

    @ObservationIgnored private let apfelService: ApfelService
    @ObservationIgnored private let chatClient: any ChatClientProtocol
    @ObservationIgnored private let persistence: any ChatPersistenceProtocol
    @ObservationIgnored private let settingsPersistence: any SettingsPersistenceProtocol
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var saveTask: Task<Void, Never>?
    @ObservationIgnored private var generatingChatID: ChatSession.ID?
    #if canImport(AppKit)
    @ObservationIgnored private nonisolated(unsafe) var terminationObserver: NSObjectProtocol?
    #endif

    var serverStatus: ApfelService.Status {
        apfelService.status
    }

    var selectedChat: ChatSession {
        get {
            chats[selectedChatIndex]
        }
        set {
            chats[selectedChatIndex] = newValue
        }
    }

    var messages: [ChatMessage] {
        selectedChat.messages
    }

    var inputText: String {
        get { selectedChat.draft }
        set {
            updateSelectedChat { chat in
                chat.draft = newValue
            }
        }
    }

    var isGenerating: Bool { selectedChat.isGenerating }

    var canDeleteChats: Bool { chats.count > 1 }

    var canClearSelectedChat: Bool {
        !messages.isEmpty || !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canTrashSelectedChat: Bool { canDeleteChats || canClearSelectedChat }

    init(
        apfelService: ApfelService,
        chatClient: (any ChatClientProtocol)? = nil,
        persistence: (any ChatPersistenceProtocol)? = nil,
        settingsPersistence: (any SettingsPersistenceProtocol)? = nil
    ) {
        self.apfelService = apfelService
        self.chatClient = chatClient ?? ChatClient(baseURL: apfelService.baseURL)
        self.persistence = persistence ?? FileChatPersistence()
        self.settingsPersistence = settingsPersistence ?? FileSettingsPersistence()
        self.settings = (try? self.settingsPersistence.loadSettings()) ?? .default

        if let restoredState = ChatStateMapper.loadInitialState(from: self.persistence) {
            self.chats = restoredState.chats
            self.selectedChatID = restoredState.selectedChatID
        } else {
            let initialChat = ChatSession()
            self.chats = [initialChat]
            self.selectedChatID = initialChat.id
        }

        #if os(macOS)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveNow()
            }
        }
        #endif
    }

    deinit {
        saveTask?.cancel()
        #if os(macOS)
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        #endif
    }

    func startServer() async {
        await apfelService.start()
    }

    func stopServer() {
        apfelService.stop()
    }

    func saveSettings() {
        try? settingsPersistence.saveSettings(settings)
    }

    func addAttachments(urls: [URL]) {
        for url in urls {
            guard let content = AttachmentContentReader.readFileContent(url: url) else { continue }
            pendingAttachments.append(
                PendingAttachment(fileName: url.lastPathComponent, content: content)
            )
        }
    }

    func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func createChat() {
        let chat = ChatSession()
        chats.insert(chat, at: 0)
        selectedChatID = chat.id
        scheduleSave()
    }

    func selectChat(id: ChatSession.ID) {
        guard chats.contains(where: { $0.id == id }) else { return }
        selectedChatID = id
        scheduleSave()
    }

    func deleteChats(at offsets: IndexSet) {
        guard canDeleteChats else { return }

        let safeOffsets = IndexSet(offsets.filter { chats.indices.contains($0) })
        guard !safeOffsets.isEmpty else { return }

        let removedIDs = safeOffsets.map { chats[$0].id }
        let deletedSelectedChat = removedIDs.contains(selectedChatID)
        let deletedGeneratingChat = generatingChatID.map { removedIDs.contains($0) } ?? false

        if deletedGeneratingChat {
            stopGeneration()
        }

        chats = chats.enumerated().compactMap { index, chat in
            safeOffsets.contains(index) ? nil : chat
        }

        if deletedSelectedChat {
            selectedChatID = chats[0].id
        }

        scheduleSave()
    }

    func deleteSelectedChat() {
        guard let selectedIndex = chats.firstIndex(where: { $0.id == selectedChatID }) else { return }
        deleteChats(at: IndexSet(integer: selectedIndex))
    }

    func trashSelectedChat() {
        if canDeleteChats {
            deleteSelectedChat()
        } else {
            clearChat()
        }
    }

    func sendMessage() {
        let chatID = selectedChatID
        let rawText = selectedChat.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty, !selectedChat.isGenerating else { return }

        // Build content with file attachments prepended
        var contentParts: [String] = []
        for attachment in pendingAttachments {
            contentParts.append(
                "--- File: \(attachment.fileName) ---\n\(attachment.content)\n--- End of \(attachment.fileName) ---"
            )
        }
        contentParts.append(rawText)
        let text = contentParts.joined(separator: "\n\n")
        pendingAttachments.removeAll()

        let userMessage = ChatMessage(role: .user, content: text)
        updateChat(id: chatID) { chat in
            chat.messages.append(userMessage)
            chat.draft = ""
        }

        appendPlaceholderAndStream(chatID: chatID)
    }

    func copyMessage(id: UUID) {
        guard let message = selectedChat.messages.first(where: { $0.id == id }) else { return }
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #endif
    }

    func regenerateMessage(id: UUID) {
        let chatID = selectedChatID
        guard !selectedChat.isGenerating else { return }

        guard let messageIndex = selectedChat.messages.firstIndex(where: { $0.id == id }),
              selectedChat.messages[messageIndex].role == .assistant else { return }

        updateChat(id: chatID) { chat in
            chat.messages.remove(at: messageIndex)
        }

        appendPlaceholderAndStream(chatID: chatID)
    }

    func editAndResend(id: UUID) {
        let chatID = selectedChatID

        if generatingChatID == chatID {
            stopGeneration()
        }

        guard let messageIndex = selectedChat.messages.firstIndex(where: { $0.id == id }),
              selectedChat.messages[messageIndex].role == .user else { return }

        let messageContent = selectedChat.messages[messageIndex].content

        updateChat(id: chatID) { chat in
            chat.messages.removeSubrange(messageIndex...)
            chat.draft = messageContent
            chat.refreshDerivedState()
        }
    }

    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil

        if let generatingChatID {
            updateChat(id: generatingChatID) { chat in
                chat.isGenerating = false
                chat.refreshDerivedState()
            }
            self.generatingChatID = nil
        }
    }

    func clearChat() {
        let chatID = selectedChatID
        if generatingChatID == chatID {
            stopGeneration()
        }

        updateChat(id: chatID) { chat in
            chat.messages.removeAll()
            chat.draft = ""
            chat.isGenerating = false
            chat.refreshDerivedState()
        }
    }

    func clearAllHistory() {
        stopGeneration()

        let emptyChat = ChatSession()
        chats = [emptyChat]
        selectedChatID = emptyChat.id
        scheduleSave()
    }

    func saveNowForTesting() { saveNow() }
}

private extension ChatViewModel {
    func appendPlaceholderAndStream(chatID: ChatSession.ID) {
        let placeholder = ChatMessage(role: .assistant, content: "")
        updateChat(id: chatID) { chat in
            chat.messages.append(placeholder)
            chat.isGenerating = true
            chat.refreshDerivedState()
        }
        generatingChatID = chatID

        let history = Array(chat(for: chatID).messages.dropLast())
        streamResponse(chatID: chatID, history: history)
    }

    func streamResponse(chatID: ChatSession.ID, history: [ChatMessage]) {
        currentTask = Task {
            do {
                let options = ChatRequestOptions(
                    systemPrompt: settings.systemPrompt.isEmpty ? nil : settings.systemPrompt,
                    temperature: settings.temperature,
                    maxTokens: settings.maxTokens
                )
                let stream = chatClient.sendMessage(messages: history, options: options)
                for try await token in stream {
                    updateChat(id: chatID) { chat in
                        if let index = chat.messages.indices.last,
                           chat.messages[index].role == .assistant {
                            chat.messages[index].content += token
                            chat.refreshDerivedState()
                        }
                    }
                }
            } catch {
                updateChat(id: chatID) { chat in
                    if let index = chat.messages.indices.last,
                       chat.messages[index].role == .assistant,
                       chat.messages[index].content.isEmpty {
                        chat.messages[index].content = "Error: \(error.localizedDescription)"
                        chat.refreshDerivedState()
                    }
                }
            }
            updateChat(id: chatID) { chat in
                chat.isGenerating = false
                chat.refreshDerivedState()
            }
            if generatingChatID == chatID {
                generatingChatID = nil
            }
            currentTask = nil
        }
    }
}

private extension ChatViewModel {
    var selectedChatIndex: Int {
        if let index = chats.firstIndex(where: { $0.id == selectedChatID }) {
            return index
        }

        let fallbackChat = ChatSession()
        chats = [fallbackChat]
        selectedChatID = fallbackChat.id
        return 0
    }

    func chat(for id: ChatSession.ID) -> ChatSession {
        guard let chat = chats.first(where: { $0.id == id }) else {
            fatalError("Missing chat for id \(id)")
        }
        return chat
    }

    func updateSelectedChat(_ update: (inout ChatSession) -> Void) {
        let index = selectedChatIndex
        update(&chats[index])
        chats[index].updatedAt = Date()
        scheduleSave()
    }

    func updateChat(id: ChatSession.ID, _ update: (inout ChatSession) -> Void) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        update(&chats[index])
        chats[index].updatedAt = Date()
        scheduleSave()
    }
}

private extension ChatViewModel {
    func scheduleSave() {
        let snapshot = makePersistedState()

        saveTask?.cancel()
        saveTask = Task { [persistence] in
            try? await Task.sleep(for: .milliseconds(350))
            try? persistence.saveState(snapshot)
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        try? persistence.saveState(makePersistedState())
    }

    func makePersistedState() -> PersistedChatState {
        ChatStateMapper.makePersistedState(
            selectedChatID: selectedChatID,
            chats: chats
        )
    }
}
