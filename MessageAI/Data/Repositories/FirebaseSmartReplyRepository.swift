//
//  FirebaseSmartReplyRepository.swift
//  MessageAI
//
//  Smart Reply Feature - Firebase implementation
//

import Foundation
import FirebaseFirestore

/// Firebase implementation of SmartReplyRepositoryProtocol
///
/// Generates AI-powered smart reply suggestions by calling the Cloud Function
/// and leveraging Firebase's caching system for optimal performance.
class FirebaseSmartReplyRepository: SmartReplyRepositoryProtocol {
    private let cloudFunctionsService: CloudFunctionsService
    private let db = Firestore.firestore()

    init(cloudFunctionsService: CloudFunctionsService = CloudFunctionsService()) {
        self.cloudFunctionsService = cloudFunctionsService
    }

    // MARK: - SmartReplyRepositoryProtocol Implementation

    func generateSmartReplies(
        conversationId: String,
        messageId: String,
        recentMessages: [Message]
    ) async throws -> SmartReply {
        print("🟢 [FirebaseSmartReplyRepository] generateSmartReplies() called")
        print("   Conversation ID: \(conversationId)")
        print("   Message ID: \(messageId)")
        print("   Recent messages count: \(recentMessages.count)")

        // Convert domain Message entities to dictionary format for Cloud Function
        let messagesData = recentMessages.map { message -> [String: Any] in
            return [
                "senderId": message.senderId,
                "text": message.text,
                "timestamp": message.timestamp.timeIntervalSince1970
            ]
        }

        // Call Cloud Function
        let response = try await cloudFunctionsService.callGenerateSmartReplies(
            conversationId: conversationId,
            messageId: messageId,
            recentMessages: messagesData
        )

        print("🟢 [FirebaseSmartReplyRepository] Cloud Function response received")
        print("   Success: \(response.success)")
        print("   Cached: \(response.cached)")
        print("   Suggestions count: \(response.suggestions.count)")

        // Parse timestamp
        let createdAt: Date
        if let date = ISO8601DateFormatter().date(from: response.timestamp) {
            createdAt = date
        } else {
            print("⚠️  [FirebaseSmartReplyRepository] Failed to parse timestamp: \(response.timestamp), using Date()")
            createdAt = Date()
        }

        // Create SmartReply domain entity
        let smartReply = SmartReply(
            conversationId: conversationId,
            triggerMessageId: messageId,
            suggestions: response.suggestions,
            createdAt: createdAt
        )

        print("✅ [FirebaseSmartReplyRepository] SmartReply entity created with \(smartReply.suggestions.count) suggestions")

        return smartReply
    }
}
