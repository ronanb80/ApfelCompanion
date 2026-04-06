import Foundation

protocol ChatClientProtocol {
    func sendMessage(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}
