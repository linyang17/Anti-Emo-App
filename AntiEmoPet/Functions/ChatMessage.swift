import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case pet
    }

    let id = UUID()
    let role: Role
    let content: String
    let createdAt: Date

    init(role: Role, content: String, createdAt: Date = .now) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
