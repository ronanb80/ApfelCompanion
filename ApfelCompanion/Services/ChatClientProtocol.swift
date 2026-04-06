import Foundation

protocol ChatClientProtocol {
    func sendMessage(messages: [ChatMessage], options: ChatRequestOptions) -> AsyncThrowingStream<String, Error>
}
