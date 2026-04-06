import Foundation

struct AppSettings: Codable, Equatable {
    var systemPrompt: String = ""
    var temperature: Double?
    var maxTokens: Int?

    static let `default` = AppSettings()
}

struct ChatRequestOptions {
    var systemPrompt: String?
    var temperature: Double?
    var maxTokens: Int?
}
