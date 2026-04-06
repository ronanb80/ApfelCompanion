import Foundation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false

    private let apfelService: ApfelService
    private let chatClient: any ChatClientProtocol
    private var currentTask: Task<Void, Never>?

    var serverStatus: ApfelService.Status {
        apfelService.status
    }

    init(apfelService: ApfelService, chatClient: (any ChatClientProtocol)? = nil) {
        self.apfelService = apfelService
        self.chatClient = chatClient ?? ChatClient(baseURL: apfelService.baseURL)
    }

    func startServer() async {
        await apfelService.start()
    }

    func stopServer() {
        apfelService.stop()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        isGenerating = true

        // Send only the conversation history (excluding the empty assistant placeholder)
        let history = Array(messages.dropLast())

        currentTask = Task {
            do {
                let stream = chatClient.sendMessage(messages: history)
                for try await token in stream {
                    if let index = messages.indices.last,
                       messages[index].role == .assistant {
                        messages[index].content += token
                    }
                }
            } catch {
                if let index = messages.indices.last,
                   messages[index].role == .assistant,
                   messages[index].content.isEmpty {
                    messages[index].content = "Error: \(error.localizedDescription)"
                }
            }
            isGenerating = false
        }
    }

    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    func clearChat() {
        stopGeneration()
        messages.removeAll()
    }
}
