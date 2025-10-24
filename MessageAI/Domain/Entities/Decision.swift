//
//  Decision.swift
//  MessageAI
//
//  Created by Claude Code on 10/24/25.
//  Decision from thread summary
//

import Foundation

/// Decision made during the conversation
///
/// Represents a key decision or agreement identified in the conversation.
struct Decision: Codable {
    /// What was decided
    let decision: String

    /// Why this decision matters or what problem it solves
    let context: String

    /// ID of the source message where this decision was made
    let sourceMessageId: String
}
