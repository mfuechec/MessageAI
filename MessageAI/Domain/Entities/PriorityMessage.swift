//
//  PriorityMessage.swift
//  MessageAI
//
//  Created by Claude Code on 10/23/25.
//  Story 3.2: Thread Summarization Feature - Priority Messages Navigation
//

import Foundation

/// Priority message extracted from conversation by AI
///
/// Represents an urgent or important message identified in a conversation
/// with reference to the source message for navigation.
struct PriorityMessage: Codable {
    /// The priority message text
    let text: String

    /// ID of the source message where this priority was mentioned
    let sourceMessageId: String

    /// Priority level (high, medium, low)
    let priority: String
}
