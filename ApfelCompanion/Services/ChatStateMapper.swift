import Foundation

enum ChatStateMapper {
    static func makePersistedState(
        selectedChatID: ChatSession.ID,
        chats: [ChatSession]
    ) -> PersistedChatState {
        PersistedChatState(
            selectedChatID: selectedChatID,
            chats: chats.map { chat in
                var persistedChat = chat
                if persistedChat.isGenerating,
                   persistedChat.messages.last?.role == .assistant {
                    persistedChat.messages.removeLast()
                }
                persistedChat.isGenerating = false
                persistedChat.refreshDerivedState()
                return persistedChat
            }
        )
    }

    static func loadInitialState(
        from persistence: any ChatPersistenceProtocol
    ) -> PersistedChatState? {
        do {
            guard let persistedState = try persistence.loadState() else {
                return nil
            }

            let restoredChats = persistedState.chats.map { chat in
                var restoredChat = chat
                restoredChat.isGenerating = false
                restoredChat.refreshDerivedState()
                return restoredChat
            }

            guard !restoredChats.isEmpty else {
                return nil
            }

            let selectedChatID = restoredChats.contains(where: { $0.id == persistedState.selectedChatID })
                ? persistedState.selectedChatID
                : restoredChats[0].id

            return PersistedChatState(
                version: persistedState.version,
                selectedChatID: selectedChatID,
                chats: restoredChats
            )
        } catch {
            return nil
        }
    }
}
