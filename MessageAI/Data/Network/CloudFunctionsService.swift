//
//  CloudFunctionsService.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/23/25.
//  Story 3.1: Cloud Functions Infrastructure for AI Services
//

import Foundation
import FirebaseFunctions

/// Service for calling Firebase Cloud Functions
///
/// Low-level network wrapper that handles HTTP calls to Cloud Functions
/// with authentication, error handling, and response parsing.
class CloudFunctionsService {
    private let functions: Functions

    init() {
        self.functions = Functions.functions()
    }

    // MARK: - Testing Utilities (DEBUG ONLY)

    #if DEBUG
    /// Call populateTestMessages Cloud Function
    ///
    /// Creates realistic multi-participant test messages for AI feature testing.
    /// Uses admin privileges to bypass security rules and create messages from other users.
    ///
    /// - Parameter conversationId: The conversation to populate with test messages
    /// - Returns: Response with message count and timestamp
    /// - Throws: AIServiceError on failure
    func callPopulateTestMessages(conversationId: String) async throws -> PopulateTestMessagesResponse {
        let data: [String: Any] = [
            "conversationId": conversationId
        ]

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 [CloudFunctions] Calling populateTestMessages")
        print("   Conversation ID: \(conversationId)")

        do {
            let result = try await functions.httpsCallable("populateTestMessages").call(data)
            print("✅ [CloudFunctions] populateTestMessages succeeded")

            guard let response = result.data as? [String: Any] else {
                print("❌ [CloudFunctions] Invalid response format: \(result.data)")
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            return try parsePopulateTestMessagesResponse(response)
        } catch let error as AIServiceError {
            print("❌ [CloudFunctions] AIServiceError: \(error.localizedDescription)")
            throw error
        } catch let error as NSError {
            print("❌ [CloudFunctions] NSError:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")
            throw mapFirebaseFunctionsError(error)
        }
    }
    #endif

    // MARK: - AI Cloud Functions

    /// Call summarizeThread Cloud Function
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to summarize
    ///   - messageIds: Optional specific message IDs
    /// - Returns: Summary response from Cloud Function
    /// - Throws: AIServiceError on failure
    func callSummarizeThread(
        conversationId: String,
        messageIds: [String]? = nil,
        bypassCache: Bool = false
    ) async throws -> SummaryResponse {
        var data: [String: Any] = [
            "conversationId": conversationId,
            "messageIds": messageIds ?? []
        ]

        if bypassCache {
            data["bypassCache"] = true
        }

        print("🔵 [CloudFunctions] Calling summarizeThread")
        print("   Conversation ID: \(conversationId)")
        print("   Message IDs: \(messageIds?.count ?? 0) messages")
        print("   Bypass cache: \(bypassCache)")

        do {
            let result = try await functions.httpsCallable("summarizeThread").call(data)
            print("✅ [CloudFunctions] summarizeThread succeeded")
            print("📊 [CloudFunctions] Raw result type: \(type(of: result.data))")

            guard let response = result.data as? [String: Any] else {
                print("❌ [CloudFunctions] Invalid response format")
                print("   Expected: [String: Any]")
                print("   Got: \(type(of: result.data))")
                print("   Value: \(result.data)")
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            print("📦 [CloudFunctions] ========== Response Structure ==========")
            print("   Keys: \(response.keys.joined(separator: ", "))")
            print("   success: \(response["success"] ?? "nil")")
            print("   cached: \(response["cached"] ?? "nil")")
            print("   summary length: \((response["summary"] as? String)?.count ?? 0)")
            print("   keyPoints count: \((response["keyPoints"] as? [String])?.count ?? 0)")
            print("   priorityMessages count: \((response["priorityMessages"] as? [[String: Any]])?.count ?? 0)")
            print("   meetings count: \((response["meetings"] as? [[String: Any]])?.count ?? 0)")

            // Debug: Print priority messages if present
            if let priorityMessagesData = response["priorityMessages"] as? [[String: Any]] {
                print("🔍 [CloudFunctions] Raw priorityMessages from Cloud Function:")
                print("   Count: \(priorityMessagesData.count)")
                for (idx, pm) in priorityMessagesData.enumerated() {
                    print("   [\(idx)] \(pm)")
                }
            } else {
                print("⚠️  [CloudFunctions] No priorityMessages in response or wrong type")
                print("   priorityMessages value: \(response["priorityMessages"] ?? "nil")")
            }

            return try parseSummaryResponse(response)
        } catch let error as AIServiceError {
            print("❌ [CloudFunctions] AIServiceError: \(error.localizedDescription)")
            throw error
        } catch let error as NSError {
            print("❌ [CloudFunctions] NSError:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")
            print("   UserInfo: \(error.userInfo)")
            throw mapFirebaseFunctionsError(error)
        }
    }

    /// Call extractActionItems Cloud Function
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to analyze
    ///   - messageIds: Optional specific message IDs
    /// - Returns: Action items response from Cloud Function
    /// - Throws: AIServiceError on failure
    func callExtractActionItems(
        conversationId: String,
        messageIds: [String]? = nil
    ) async throws -> ActionItemsResponse {
        let data: [String: Any] = [
            "conversationId": conversationId,
            "messageIds": messageIds ?? []
        ]

        do {
            let result = try await functions.httpsCallable("extractActionItems").call(data)

            guard let response = result.data as? [String: Any] else {
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            return try parseActionItemsResponse(response)
        } catch let error as AIServiceError {
            throw error
        } catch let error as NSError {
            throw mapFirebaseFunctionsError(error)
        }
    }

    /// Call generateSmartSearchResults Cloud Function
    ///
    /// - Parameters:
    ///   - query: The search query
    ///   - conversationIds: Optional specific conversations to search
    /// - Returns: Search results response from Cloud Function
    /// - Throws: AIServiceError on failure
    func callGenerateSmartSearchResults(
        query: String,
        conversationIds: [String]? = nil
    ) async throws -> SearchResultsResponse {
        let data: [String: Any] = [
            "query": query,
            "conversationIds": conversationIds ?? []
        ]

        do {
            let result = try await functions.httpsCallable("generateSmartSearchResults").call(data)

            guard let response = result.data as? [String: Any] else {
                throw AIServiceError.unknown("Invalid response format from Cloud Function")
            }

            return try parseSearchResultsResponse(response)
        } catch let error as AIServiceError {
            throw error
        } catch let error as NSError {
            throw mapFirebaseFunctionsError(error)
        }
    }

    // MARK: - Response Parsing

    #if DEBUG
    private func parsePopulateTestMessagesResponse(_ data: [String: Any]) throws -> PopulateTestMessagesResponse {
        guard let success = data["success"] as? Bool,
              let messageCount = data["messageCount"] as? Int,
              let conversationId = data["conversationId"] as? String,
              let timestamp = data["timestamp"] as? String else {
            throw AIServiceError.unknown("Missing required fields in populateTestMessages response")
        }

        print("📊 [CloudFunctions] Test messages created:")
        print("   Message count: \(messageCount)")
        print("   Conversation: \(conversationId)")
        print("   Timestamp: \(timestamp)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return PopulateTestMessagesResponse(
            success: success,
            messageCount: messageCount,
            conversationId: conversationId,
            timestamp: timestamp
        )
    }
    #endif

    private func parseSummaryResponse(_ data: [String: Any]) throws -> SummaryResponse {
        print("🔍 [CloudFunctions] ========== Parsing Summary Response ==========")

        guard let success = data["success"] as? Bool else {
            print("❌ [CloudFunctions] Missing 'success' field")
            throw AIServiceError.unknown("Missing required field: success")
        }
        print("✅ [CloudFunctions] success: \(success)")

        guard let summary = data["summary"] as? String else {
            print("❌ [CloudFunctions] Missing 'summary' field")
            print("   Available keys: \(data.keys.joined(separator: ", "))")
            throw AIServiceError.unknown("Missing required field: summary")
        }
        print("✅ [CloudFunctions] summary: \(summary.prefix(50))... (\(summary.count) chars)")

        guard let cached = data["cached"] as? Bool else {
            print("❌ [CloudFunctions] Missing 'cached' field")
            throw AIServiceError.unknown("Missing required field: cached")
        }
        print("✅ [CloudFunctions] cached: \(cached)")

        guard let timestamp = data["timestamp"] as? String else {
            print("❌ [CloudFunctions] Missing 'timestamp' field")
            throw AIServiceError.unknown("Missing required field: timestamp")
        }
        print("✅ [CloudFunctions] timestamp: \(timestamp)")

        let keyPoints = data["keyPoints"] as? [String]
        let participants = data["participants"] as? [String]
        let dateRange = data["dateRange"] as? String
        let messagesSinceCache = data["messagesSinceCache"] as? Int ?? 0
        let lastMessageId = data["lastMessageId"] as? String
        let messageCount = data["messageCount"] as? Int

        // Parse priority messages
        var priorityMessages: [PriorityMessageDTO]? = nil
        if let priorityMessagesData = data["priorityMessages"] as? [[String: Any]] {
            print("🔍 [CloudFunctions] Parsing \(priorityMessagesData.count) priority messages")

            priorityMessages = priorityMessagesData.compactMap { pmData in
                print("   Parsing priority message: \(pmData)")

                guard let text = pmData["text"] as? String else {
                    print("   ❌ Missing 'text' field")
                    return nil
                }

                guard let sourceMessageId = pmData["sourceMessageId"] as? String else {
                    print("   ❌ Missing 'sourceMessageId' field")
                    return nil
                }

                guard let priority = pmData["priority"] as? String else {
                    print("   ❌ Missing 'priority' field")
                    return nil
                }

                let dto = PriorityMessageDTO(
                    text: text,
                    sourceMessageId: sourceMessageId,
                    priority: priority
                )
                print("   ✅ Created DTO: text=\(text.prefix(30))..., sourceMessageId=\(sourceMessageId), priority=\(priority)")
                return dto
            }

            print("✅ [CloudFunctions] Successfully parsed \(priorityMessages?.count ?? 0) priority message DTOs")
        } else {
            print("⚠️  [CloudFunctions] priorityMessages not found or wrong type in response")
        }

        // Parse meetings
        var meetings: [MeetingDTO]? = nil
        if let meetingsData = data["meetings"] as? [[String: Any]] {
            print("🔍 [CloudFunctions] Parsing \(meetingsData.count) meetings")

            meetings = meetingsData.compactMap { meetingData in
                print("   Parsing meeting: \(meetingData)")

                guard let topic = meetingData["topic"] as? String else {
                    print("   ❌ Missing 'topic' field")
                    return nil
                }

                guard let sourceMessageId = meetingData["sourceMessageId"] as? String else {
                    print("   ❌ Missing 'sourceMessageId' field")
                    return nil
                }

                guard let type = meetingData["type"] as? String else {
                    print("   ❌ Missing 'type' field")
                    return nil
                }

                guard let durationMinutes = meetingData["durationMinutes"] as? Int else {
                    print("   ❌ Missing 'durationMinutes' field")
                    return nil
                }

                guard let urgency = meetingData["urgency"] as? String else {
                    print("   ❌ Missing 'urgency' field")
                    return nil
                }

                guard let participants = meetingData["participants"] as? [String] else {
                    print("   ❌ Missing 'participants' field")
                    return nil
                }

                let scheduledTime = meetingData["scheduledTime"] as? String

                let dto = MeetingDTO(
                    topic: topic,
                    sourceMessageId: sourceMessageId,
                    type: type,
                    scheduledTime: scheduledTime,
                    durationMinutes: durationMinutes,
                    urgency: urgency,
                    participants: participants
                )
                print("   ✅ Created DTO: topic=\(topic), type=\(type), urgency=\(urgency)")
                return dto
            }

            print("✅ [CloudFunctions] Successfully parsed \(meetings?.count ?? 0) meeting DTOs")
        } else {
            print("⚠️  [CloudFunctions] meetings not found or wrong type in response")
        }

        // Parse action items
        var actionItems: [SummaryActionItemDTO]?
        if let actionItemsData = data["actionItems"] as? [[String: Any]] {
            print("🔍 [CloudFunctions] Parsing \(actionItemsData.count) action items")
            actionItems = actionItemsData.compactMap { itemData in
                guard let task = itemData["task"] as? String,
                      let sourceMessageId = itemData["sourceMessageId"] as? String else {
                    print("   ⚠️ Skipping action item - missing required fields")
                    return nil
                }

                let assignee = itemData["assignee"] as? String
                let dueDate = itemData["dueDate"] as? String

                let dto = SummaryActionItemDTO(
                    task: task,
                    assignee: assignee,
                    dueDate: dueDate,
                    sourceMessageId: sourceMessageId
                )
                print("   ✅ Created DTO: task=\(task)")
                return dto
            }

            print("✅ [CloudFunctions] Successfully parsed \(actionItems?.count ?? 0) action item DTOs")
        } else {
            print("⚠️  [CloudFunctions] actionItems not found or wrong type in response")
        }

        // Parse decisions
        var decisions: [DecisionDTO]?
        if let decisionsData = data["decisions"] as? [[String: Any]] {
            print("🔍 [CloudFunctions] Parsing \(decisionsData.count) decisions")
            decisions = decisionsData.compactMap { decisionData in
                guard let decision = decisionData["decision"] as? String,
                      let context = decisionData["context"] as? String,
                      let sourceMessageId = decisionData["sourceMessageId"] as? String else {
                    print("   ⚠️ Skipping decision - missing required fields")
                    return nil
                }

                let dto = DecisionDTO(
                    decision: decision,
                    context: context,
                    sourceMessageId: sourceMessageId
                )
                print("   ✅ Created DTO: decision=\(decision)")
                return dto
            }

            print("✅ [CloudFunctions] Successfully parsed \(decisions?.count ?? 0) decision DTOs")
        } else {
            print("⚠️  [CloudFunctions] decisions not found or wrong type in response")
        }

        let response = SummaryResponse(
            success: success,
            summary: summary,
            keyPoints: keyPoints,
            priorityMessages: priorityMessages,
            meetings: meetings,
            actionItems: actionItems,
            decisions: decisions,
            participants: participants,
            dateRange: dateRange,
            cached: cached,
            messagesSinceCache: messagesSinceCache,
            timestamp: timestamp,
            lastMessageId: lastMessageId,
            messageCount: messageCount
        )

        print("📦 [CloudFunctions] Final SummaryResponse created with \(response.priorityMessages?.count ?? 0) priority messages and \(response.meetings?.count ?? 0) meetings")

        return response
    }

    private func parseActionItemsResponse(_ data: [String: Any]) throws -> ActionItemsResponse {
        guard let success = data["success"] as? Bool,
              let cached = data["cached"] as? Bool,
              let timestamp = data["timestamp"] as? String,
              let actionItemsData = data["actionItems"] as? [[String: Any]] else {
            throw AIServiceError.unknown("Missing required fields in action items response")
        }

        let actionItems = try actionItemsData.map { itemData -> ActionItemDTO in
            guard let task = itemData["task"] as? String,
                  let assignee = itemData["assignee"] as? String,
                  let sourceMessageId = itemData["sourceMessageId"] as? String,
                  let priority = itemData["priority"] as? String else {
                throw AIServiceError.unknown("Invalid action item format")
            }

            let assigneeId = itemData["assigneeId"] as? String
            let deadline = itemData["deadline"] as? String

            return ActionItemDTO(
                task: task,
                assignee: assignee,
                assigneeId: assigneeId,
                deadline: deadline,
                sourceMessageId: sourceMessageId,
                priority: priority
            )
        }

        return ActionItemsResponse(
            success: success,
            actionItems: actionItems,
            cached: cached,
            timestamp: timestamp
        )
    }

    private func parseSearchResultsResponse(_ data: [String: Any]) throws -> SearchResultsResponse {
        guard let success = data["success"] as? Bool,
              let cached = data["cached"] as? Bool,
              let timestamp = data["timestamp"] as? String,
              let resultsData = data["results"] as? [[String: Any]] else {
            throw AIServiceError.unknown("Missing required fields in search results response")
        }

        let results = try resultsData.map { resultData -> SearchResultDTO in
            guard let messageId = resultData["messageId"] as? String,
                  let conversationId = resultData["conversationId"] as? String,
                  let snippet = resultData["snippet"] as? String,
                  let relevanceScore = resultData["relevanceScore"] as? Double,
                  let senderName = resultData["senderName"] as? String else {
                throw AIServiceError.unknown("Invalid search result format")
            }

            // timestamp is optional
            var timestamp: Date?
            if let timestampData = resultData["timestamp"] {
                // Handle Firestore Timestamp
                if let seconds = (timestampData as? [String: Any])?["_seconds"] as? Double {
                    timestamp = Date(timeIntervalSince1970: seconds)
                }
            }

            return SearchResultDTO(
                messageId: messageId,
                conversationId: conversationId,
                snippet: snippet,
                relevanceScore: relevanceScore,
                timestamp: timestamp,
                senderName: senderName
            )
        }

        return SearchResultsResponse(
            success: success,
            results: results,
            cached: cached,
            timestamp: timestamp
        )
    }

    // MARK: - Error Mapping

    private func mapFirebaseFunctionsError(_ error: NSError) -> AIServiceError {
        if let code = FunctionsErrorCode(rawValue: error.code) {
            switch code {
            case .unauthenticated:
                return .unauthenticated
            case .permissionDenied:
                return .unauthenticated
            case .resourceExhausted:
                return .rateLimitExceeded
            case .deadlineExceeded:
                return .timeout
            case .unavailable, .internal:
                return .serviceUnavailable
            case .invalidArgument:
                return .invalidInput(error.localizedDescription)
            default:
                return .unknown(error.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Response DTOs

struct SummaryResponse {
    let success: Bool
    let summary: String
    let keyPoints: [String]?
    let priorityMessages: [PriorityMessageDTO]?
    let meetings: [MeetingDTO]?
    let actionItems: [SummaryActionItemDTO]?
    let decisions: [DecisionDTO]?
    let participants: [String]?
    let dateRange: String?
    let cached: Bool
    let messagesSinceCache: Int
    let timestamp: String
    let lastMessageId: String?
    let messageCount: Int?
}

struct PriorityMessageDTO {
    let text: String
    let sourceMessageId: String  // Matches domain entity and ActionItemDTO
    let priority: String
}

struct MeetingDTO {
    let topic: String
    let sourceMessageId: String
    let type: String
    let scheduledTime: String?
    let durationMinutes: Int
    let urgency: String
    let participants: [String]
}

/// Action item from thread summary (simpler than ActionItemDTO for separate endpoint)
struct SummaryActionItemDTO {
    let task: String
    let assignee: String?
    let dueDate: String?
    let sourceMessageId: String
}

/// Decision from thread summary
struct DecisionDTO {
    let decision: String
    let context: String
    let sourceMessageId: String
}

struct ActionItemsResponse {
    let success: Bool
    let actionItems: [ActionItemDTO]
    let cached: Bool
    let timestamp: String
}

struct ActionItemDTO {
    let task: String
    let assignee: String
    let assigneeId: String?
    let deadline: String?
    let sourceMessageId: String
    let priority: String
}

struct SearchResultsResponse {
    let success: Bool
    let results: [SearchResultDTO]
    let cached: Bool
    let timestamp: String
}

struct SearchResultDTO {
    let messageId: String
    let conversationId: String
    let snippet: String
    let relevanceScore: Double
    let timestamp: Date?
    let senderName: String
}

#if DEBUG
struct PopulateTestMessagesResponse {
    let success: Bool
    let messageCount: Int
    let conversationId: String
    let timestamp: String
}
#endif
