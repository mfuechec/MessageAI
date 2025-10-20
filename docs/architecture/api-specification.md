# API Specification

**Note:** MessageAI uses Firebase backend services, which do not expose traditional REST or GraphQL APIs. Instead, the iOS app communicates with Firebase through official SDKs:

**Firebase SDK Communication:**
- **Firestore SDK**: Direct database queries and real-time listeners (no REST endpoints)
- **Firebase Auth SDK**: Authentication via native SDK methods
- **Firebase Storage SDK**: File uploads/downloads via SDK
- **Cloud Functions**: HTTPS callable functions invoked via SDK

**Cloud Functions as BFF (Backend-for-Frontend):**

MessageAI implements Cloud Functions as a thin API layer for AI features only. These are callable HTTPS functions invoked from iOS:

```typescript
// Cloud Function signatures (TypeScript/Node.js)

exports.summarizeThread = functions.https.onCall(async (data, context) => {
  // Input: { conversationId: string, messageIds?: string[] }
  // Output: { summary: string, keyPoints: string[], timestamp: Date }
});

exports.extractActionItems = functions.https.onCall(async (data, context) => {
  // Input: { conversationId: string, messageIds?: string[] }
  // Output: { actionItems: ActionItem[], timestamp: Date }
});

exports.detectPriorityMessages = functions.https.onCall(async (data, context) => {
  // Input: { messageId: string }
  // Output: { isPriority: boolean, reason?: string, confidence: number }
});

exports.suggestMeetingTimes = functions.https.onCall(async (data, context) => {
  // Input: { conversationId: string, participants: string[] }
  // Output: { suggestions: TimeSlot[], rationale: string }
});

exports.searchConversations = functions.https.onCall(async (data, context) => {
  // Input: { query: string, conversationIds?: string[] }
  // Output: { results: SearchResult[], query: string }
});
```

**iOS Client Invocation:**

```swift
// Example: Calling Cloud Function from iOS
let functions = Functions.functions()
let summarize = functions.httpsCallable("summarizeThread")

let data: [String: Any] = [
    "conversationId": conversationId,
    "messageIds": messageIds
]

do {
    let result = try await summarize.call(data)
    let summary = result.data as? [String: Any]
    // Process summary
} catch {
    // Handle error
}
```

**Authentication:** All Cloud Functions verify Firebase Auth tokens automatically via `context.auth`.

**Rate Limiting:** Implemented at Cloud Function level (100 AI requests per user per day).

---
