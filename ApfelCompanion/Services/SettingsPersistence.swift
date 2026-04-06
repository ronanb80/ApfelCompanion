import Foundation

protocol SettingsPersistenceProtocol {
    func loadSettings() throws -> AppSettings?
    func saveSettings(_ settings: AppSettings) throws
}

final class FileSettingsPersistence: SettingsPersistenceProtocol {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager

        let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        self.fileURL = fileURL ?? appSupportURL
            .appendingPathComponent("ApfelCompanion", isDirectory: true)
            .appendingPathComponent("settings.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()
    }

    func loadSettings() throws -> AppSettings? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSettings.self, from: data)
    }

    func saveSettings(_ settings: AppSettings) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
