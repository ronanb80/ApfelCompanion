import Foundation

@Observable
class ChatViewModel {
    var chats: [ChatSession]
    var selectedChatID: ChatSession.ID

    private let apfelService: ApfelService
    private let chatClient: any ChatClientProtocol
    private var currentTask: Task<Void, Never>?
    private var generatingChatID: ChatSession.ID?

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

    var isGenerating: Bool {
        selectedChat.isGenerating
    }

    var canDeleteChats: Bool {
        chats.count > 1
    }

    var canClearSelectedChat: Bool {
        !messages.isEmpty || !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canTrashSelectedChat: Bool {
        canDeleteChats || canClearSelectedChat
    }

    init(apfelService: ApfelService, chatClient: (any ChatClientProtocol)? = nil) {
        self.apfelService = apfelService
        self.chatClient = chatClient ?? ChatClient(baseURL: apfelService.baseURL)
        let initialChat = ChatSession()
        self.chats = [initialChat]
        self.selectedChatID = initialChat.id
    }

    func startServer() async {
        await apfelService.start()
    }

    func stopServer() {
        apfelService.stop()
    }

    func createChat() {
        let chat = ChatSession()
        chats.insert(chat, at: 0)
        selectedChatID = chat.id
    }

    func selectChat(id: ChatSession.ID) {
        guard chats.contains(where: { $0.id == id }) else { return }
        selectedChatID = id
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
        let text = selectedChat.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !selectedChat.isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        updateChat(id: chatID) { chat in
            chat.messages.append(userMessage)
            chat.draft = ""
        }

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        updateChat(id: chatID) { chat in
            chat.messages.append(assistantMessage)
            chat.isGenerating = true
            chat.refreshDerivedState()
        }
        generatingChatID = chatID

        let history = Array(chat(for: chatID).messages.dropLast())

        currentTask = Task {
            do {
                let stream = chatClient.sendMessage(messages: history)
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

    private var selectedChatIndex: Int {
        if let index = chats.firstIndex(where: { $0.id == selectedChatID }) {
            return index
        }

        let fallbackChat = ChatSession()
        chats = [fallbackChat]
        selectedChatID = fallbackChat.id
        return 0
    }

    private func chat(for id: ChatSession.ID) -> ChatSession {
        guard let chat = chats.first(where: { $0.id == id }) else {
            fatalError("Missing chat for id \(id)")
        }
        return chat
    }

    private func updateSelectedChat(_ update: (inout ChatSession) -> Void) {
        let index = selectedChatIndex
        update(&chats[index])
        chats[index].updatedAt = Date()
    }

    private func updateChat(id: ChatSession.ID, _ update: (inout ChatSession) -> Void) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        update(&chats[index])
        chats[index].updatedAt = Date()
    }
}
