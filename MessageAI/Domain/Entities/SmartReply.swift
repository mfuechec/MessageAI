import Foundation

/// Domain entity representing AI-generated smart reply suggestions
struct SmartReply: Codable, Equatable, Identifiable {
    let id: String
    let conversationId: String
    let triggerMessageId: String  // Message that prompted these suggestions
    let suggestions: [String]      // Array of suggested responses
    let createdAt: Date
    let schemaVersion: Int

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        triggerMessageId: String,
        suggestions: [String],
        createdAt: Date = Date(),
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.conversationId = conversationId
        self.triggerMessageId = triggerMessageId
        self.suggestions = suggestions
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
    }
}
