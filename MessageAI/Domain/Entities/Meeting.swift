//
//  Meeting.swift
//  MessageAI
//
//  Created by Claude Code on 10/24/25.
//  Meeting scheduling feature - AI-detected meeting needs and scheduled meetings
//

import Foundation

/// Meeting detected or scheduled from conversation
///
/// Represents either:
/// - A detected need for a meeting (AI-identified topic requiring discussion)
/// - An already scheduled meeting (confirmed time and participants)
struct Meeting: Codable {
    /// Summary of what the meeting is about
    let topic: String

    /// ID of the source message where this meeting was mentioned
    let sourceMessageId: String

    /// Meeting type: "detected" (AI identified need) or "scheduled" (confirmed meeting)
    let type: String

    /// For scheduled meetings: the scheduled time (nil for detected needs)
    let scheduledTime: Date?

    /// Suggested or actual duration in minutes
    let durationMinutes: Int

    /// Urgency level for detected needs (high, medium, low)
    let urgency: String

    /// Participants mentioned (display names)
    let participants: [String]
}
