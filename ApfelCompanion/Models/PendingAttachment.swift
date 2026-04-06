import Foundation

struct PendingAttachment: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let content: String
}
