//
//  ActionItem.swift
//  MessageAI
//
//  Created by Claude Code on 10/24/25.
//  Action item from thread summary
//

import Foundation

/// Action item extracted from conversation summary
///
/// Represents a task identified in the conversation with assignee and due date.
struct ActionItem: Codable {
    /// Description of what needs to be done
    let task: String

    /// Person responsible (nil if not mentioned)
    let assignee: String?

    /// When it's due (natural language like "Friday EOD", "by tomorrow", or nil)
    let dueDate: String?

    /// ID of the source message where this action item was mentioned
    let sourceMessageId: String
}
