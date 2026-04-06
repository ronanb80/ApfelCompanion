import Foundation

protocol ChatPersistenceProtocol {
    func loadState() throws -> PersistedChatState?
    func saveState(_ state: PersistedChatState) throws
}

struct PersistedChatState: Codable {
    let version: Int
    var selectedChatID: ChatSession.ID
    var chats: [ChatSession]

    init(version: Int = 1, selectedChatID: ChatSession.ID, chats: [ChatSession]) {
        self.version = version
        self.selectedChatID = selectedChatID
        self.chats = chats
    }
}

final class FileChatPersistence: ChatPersistenceProtocol {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadState() throws -> PersistedChatState? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)

        do {
            return try decoder.decode(PersistedChatState.self, from: data)
        } catch {
            let corruptURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? fileManager.moveItem(at: fileURL, to: uniqueReplacementURL(for: corruptURL))
            throw error
        }
    }

    func saveState(_ state: PersistedChatState) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    private func uniqueReplacementURL(for url: URL) -> URL {
        guard !fileManager.fileExists(atPath: url.path) else {
            let baseName = url.deletingPathExtension().lastPathComponent
            let directory = url.deletingLastPathComponent()
            let uniqueName = "\(baseName)-\(UUID().uuidString).corrupt.json"
            return directory.appendingPathComponent(uniqueName)
        }

        return url
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let currentDirectoryURL = appSupportURL.appendingPathComponent("ApfelCompanion", isDirectory: true)
        let legacyFileURL = appSupportURL
            .appendingPathComponent("Ulog", isDirectory: true)
            .appendingPathComponent("chat-state.json")
        let currentFileURL = currentDirectoryURL.appendingPathComponent("chat-state.json")

        if fileManager.fileExists(atPath: currentFileURL.path) {
            return currentFileURL
        }

        if fileManager.fileExists(atPath: legacyFileURL.path) {
            do {
                try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)
                try fileManager.moveItem(at: legacyFileURL, to: currentFileURL)
                return currentFileURL
            } catch {
                // Keep reading from the legacy location if migration fails.
                return legacyFileURL
            }
        }

        return currentFileURL
    }
}
