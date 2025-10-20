import Foundation

/// Represents a single edit to a message (for edit history tracking)
struct MessageEdit: Codable, Equatable {
    let text: String
    let editedAt: Date
}

