//
//  AIActionItem.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/23/25.
//  Story 3.1: Cloud Functions Infrastructure for AI Services
//

import Foundation

/// Action item extracted from conversation by AI
///
/// Represents a task identified in a conversation with assignee information.
struct AIActionItem {
    /// Description of the task
    let task: String

    /// Name of the person assigned (or "Unassigned")
    let assignee: String

    /// User ID of the assignee (nil if unassigned)
    let assigneeId: String?

    /// Optional deadline if mentioned
    let deadline: String?

    /// ID of the message where this action item was mentioned
    let sourceMessageId: String

    /// Priority level (low, medium, high)
    let priority: String
}
