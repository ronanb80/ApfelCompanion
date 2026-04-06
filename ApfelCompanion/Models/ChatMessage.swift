import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    var renderedContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let parsed = try? AttributedString(markdown: content, options: options) {
            return parsed
        }

        return AttributedString(content)
    }
}

struct ChatSession: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var draft: String
    var isGenerating: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        draft: String = "",
        isGenerating: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.draft = draft
        self.isGenerating = isGenerating
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        refreshDerivedState()
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "New Chat" : trimmedTitle
    }

    var previewText: String {
        let previewSource = messages.last?.content ?? draft
        let trimmedPreview = previewSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPreview.isEmpty ? "No messages yet" : trimmedPreview
    }

    mutating func refreshDerivedState() {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            title = Self.makeTitle(from: firstUserMessage.content)
        } else {
            title = "New Chat"
        }

        if let latestMessage = messages.last {
            updatedAt = latestMessage.timestamp
        }
    }

    private static func makeTitle(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New Chat" }

        let collapsed = trimmed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return String(collapsed.prefix(32))
    }
}
