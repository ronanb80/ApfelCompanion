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
                    let url = baseURL.appendingPathComponent("v1/chat/completions")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    var apiMessages: [[String: String]] = []
                    if let systemPrompt = options.systemPrompt,
                       !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        apiMessages.append(["role": "system", "content": systemPrompt])
                    }
                    apiMessages += messages.map {
                        ["role": $0.role.rawValue, "content": $0.content]
                    }

                    var body: [String: Any] = [
                        "model": "apple-foundationmodel",
                        "messages": apiMessages,
                        "stream": true
                    ]
                    if let temperature = options.temperature {
                        body["temperature"] = temperature
                    }
                    if let maxTokens = options.maxTokens {
                        body["max_tokens"] = maxTokens
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        throw ChatError.serverError(code)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload == "[DONE]" { break }

                        guard let jsonData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData)
                                  as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String
                        else {
                            continue
                        }

                        continuation.yield(content)
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
