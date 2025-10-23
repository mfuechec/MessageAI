//
//  AISearchResult.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/23/25.
//  Story 3.1: Cloud Functions Infrastructure for AI Services
//

import Foundation

/// Search result from AI-enhanced semantic search
///
/// Represents a message that matched a search query with relevance scoring.
struct AISearchResult {
    /// ID of the message that matched
    let messageId: String

    /// ID of the conversation containing the message
    let conversationId: String

    /// Text snippet showing the match context
    let snippet: String

    /// Relevance score (0.0 - 1.0)
    let relevanceScore: Double

    /// When the message was sent
    let timestamp: Date?

    /// Name of the sender
    let senderName: String
}
