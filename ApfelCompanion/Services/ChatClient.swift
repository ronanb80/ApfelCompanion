import Foundation

class ChatClient: ChatClientProtocol {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Sends messages to the apfel server and returns a stream of response tokens.
    func sendMessage(messages: [ChatMessage], options: ChatRequestOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(messages: messages, options: options)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        throw ChatError.serverError(code)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let content = content(from: line) {
                            continuation.yield(content)
                        } else if isDoneLine(line) {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeRequest(messages: [ChatMessage], options: ChatRequestOptions) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(messages: messages, options: options)
        )
        return request
    }

    private func requestBody(messages: [ChatMessage], options: ChatRequestOptions) -> [String: Any] {
        var body: [String: Any] = [
            "model": "apple-foundationmodel",
            "messages": apiMessages(from: messages, systemPrompt: options.systemPrompt),
            "stream": true
        ]

        if let temperature = options.temperature {
            body["temperature"] = temperature
        }
        if let maxTokens = options.maxTokens {
            body["max_tokens"] = maxTokens
        }

        return body
    }

    private func apiMessages(from messages: [ChatMessage], systemPrompt: String?) -> [[String: String]] {
        var apiMessages = messages.map {
            ["role": $0.role.rawValue, "content": $0.content]
        }

        if let systemPrompt, !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apiMessages.insert(["role": "system", "content": systemPrompt], at: 0)
        }

        return apiMessages
    }

    private func isDoneLine(_ line: String) -> Bool {
        payload(from: line) == "[DONE]"
    }

    private func content(from line: String) -> String? {
        guard let payload = payload(from: line),
              payload != "[DONE]",
              let jsonData = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }

        return content
    }

    private func payload(from line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        return String(line.dropFirst(6))
    }

    enum ChatError: LocalizedError {
        case serverError(Int)

        var errorDescription: String? {
            switch self {
            case .serverError(let code):
                return "Server returned status code \(code)"
            }
        }
    }
}
