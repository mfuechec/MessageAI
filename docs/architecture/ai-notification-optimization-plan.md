# AI Notification System Optimization Plan

**Epic 6 - Performance & Intelligence Improvements**

**Version:** 1.0
**Date:** 2025-01-24
**Status:** Ready for Implementation

---

## Executive Summary

This document outlines critical bug fixes and performance optimizations for the AI notification system (Epic 6). Current system latency is 5-10 seconds per analysis with a **completely broken feedback loop**. The proposed improvements will:

- ✅ **Fix 3 critical bugs** preventing the feedback loop from working
- ⚡ **Reduce latency from 5-10s to <500ms** (10-20x faster)
- 💰 **Reduce costs by 90%** through smarter caching and model selection
- 🧠 **Improve decision quality** with better context and working personalization
- 🚀 **Enable real-time analysis** on every message (not just backgrounded)

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Critical Bug Fixes (P0)](#critical-bug-fixes-p0)
3. [Performance Optimizations](#performance-optimizations)
4. [Implementation Phases](#implementation-phases)
5. [Technical Specifications](#technical-specifications)
6. [Testing Requirements](#testing-requirements)
7. [Rollout Strategy](#rollout-strategy)

---

## Current State Analysis

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Current Flow                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  App Backgrounds                                            │
│       │                                                      │
│       ├─→ analyzeForNotification (Cloud Function)           │
│       │   ├─ Fetch messages (15 min window)      ~1s        │
│       │   ├─ Load user context (7 days)          ~2s        │
│       │   ├─ Index messages for RAG               ~1.5s     │
│       │   ├─ Semantic search                      ~0.5s     │
│       │   ├─ Call GPT-4-turbo                     ~3s       │
│       │   └─ Send FCM notification                ~0.2s     │
│       │   TOTAL: ~8 seconds                                 │
│       │                                                      │
│       └─→ User receives notification (maybe)                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Performance Metrics (Current)

| Metric | Current Value | Target |
|--------|---------------|--------|
| **Average latency** | 5-10 seconds | <500ms |
| **P95 latency** | 15+ seconds | <1s |
| **Cost per analysis** | $0.015-0.020 | $0.001-0.002 |
| **Cache hit rate** | ~30% | >80% |
| **Firestore reads** | 50-100 per analysis | <10 |
| **LLM calls skippable** | 0% | 70% |

### Infrastructure

- ✅ Cloud Functions (Node.js 18)
- ✅ Firestore
- ✅ OpenAI API (GPT-4-turbo + text-embedding-ada-002)
- ✅ Firebase Cloud Messaging
- ❌ No Cloud Scheduler configured
- ❌ No pre-computed context

---

## Critical Bug Fixes (P0)

**PRIORITY: MUST FIX BEFORE ANY OPTIMIZATIONS**

The feedback loop is completely non-functional due to 3 critical bugs:

### Bug #1: iOS App Missing Required Parameter

**File:** `MessageAI/Data/Repositories/FirebaseNotificationHistoryRepository.swift:102-108`

**Current Code:**
```swift
func submitFeedback(
    userId: String,
    conversationId: String,
    messageId: String,
    feedback: String
) async throws {
    let data: [String: Any] = [
        "conversationId": conversationId,
        "messageId": messageId,
        "feedback": feedback
        // ❌ Missing "decision" parameter!
    ]

    _ = try await functions.httpsCallable("submitNotificationFeedback").call(data)
}
```

**Problem:**
Cloud Function (`functions/src/submitNotificationFeedback.ts:55-60`) validates:
```typescript
if (!data.decision || typeof data.decision !== "object") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "decision must be a valid NotificationDecision object"
    );
}
```

**Impact:** 100% of feedback submissions fail immediately

**Fix:**

```swift
// Update protocol signature
protocol NotificationHistoryRepositoryProtocol {
    func submitFeedback(
        userId: String,
        conversationId: String,
        messageId: String,
        feedback: String,
        decision: NotificationDecision  // ← Add parameter
    ) async throws
}

// Update implementation
func submitFeedback(
    userId: String,
    conversationId: String,
    messageId: String,
    feedback: String,
    decision: NotificationDecision  // ← Add parameter
) async throws {
    let data: [String: Any] = [
        "conversationId": conversationId,
        "messageId": messageId,
        "feedback": feedback,
        "decision": [  // ← Add decision object
            "shouldNotify": decision.shouldNotify,
            "reason": decision.reason,
            "notificationText": decision.notificationText ?? "",
            "priority": decision.priority.rawValue
        ]
    ]

    _ = try await functions.httpsCallable("submitNotificationFeedback").call(data)
}
```

**Update callers:**
```swift
// NotificationHistoryViewModel.swift:51
try await repository.submitFeedback(
    userId: userId,
    conversationId: entry.conversationId,
    messageId: entry.messageId,
    feedback: feedback,
    decision: entry.decision  // ← Add this
)
```

---

### Bug #2: Document ID Mismatch

**Files:**
- `functions/src/updateUserNotificationProfile.ts:217` (WRITE)
- `functions/src/analyzeForNotification.ts:245` (READ)

**Problem:**
Write path:
```typescript
await db.collection("users")
    .doc(userId)
    .collection("ai_notification_profile")
    .doc("default")  // ← Writes to "default"
    .set(profileData, { merge: true });
```

Read path:
```typescript
const profileDoc = await db.collection("users")
    .doc(userId)
    .collection("ai_notification_profile")
    .doc("profile")  // ← Reads from "profile"
    .get();
```

**Impact:** Learned preferences NEVER loaded, AI always uses defaults

**Fix (Option A - Recommended):**

Change write to match read:
```typescript
// updateUserNotificationProfile.ts:217
await db.collection("users")
    .doc(userId)
    .collection("ai_notification_profile")
    .doc("profile")  // ← Change from "default" to "profile"
    .set(profileData, { merge: true });
```

**Fix (Option B - Alternative):**

Change read to match write:
```typescript
// analyzeForNotification.ts:245
const profileDoc = await db.collection("users")
    .doc(userId)
    .collection("ai_notification_profile")
    .doc("default")  // ← Change from "profile" to "default"
    .get();
```

**Recommendation:** Use Option A (change write to "profile") since "profile" is more descriptive than "default"

---

### Bug #3: No Scheduled Trigger

**File:** `functions/src/updateUserNotificationProfile.ts:18-23`

**Problem:**
Function is `.https.onCall()` but comment says "Runs weekly via Cloud Scheduler"

```typescript
/**
 * Runs weekly via Cloud Scheduler (Monday 00:00 UTC)  // ← LIE
 */
export const updateUserNotificationProfile = functions
    .runWith({ timeoutSeconds: 540, memory: "1GB" })
    .https.onCall(async (data, context) => {  // ← Manual call only
        // ...
    });
```

No scheduler configured in `firebase.json`

**Impact:** Profile updates NEVER run automatically

**Fix:**

Split into two functions:

```typescript
// functions/src/updateUserNotificationProfile.ts

/**
 * Scheduled function: Runs weekly to update all user profiles
 * Cloud Scheduler: Every Monday at 00:00 UTC
 */
export const updateUserNotificationProfileScheduled = functions
    .runWith({
        timeoutSeconds: 540,
        memory: "1GB",
    })
    .pubsub.schedule('0 0 * * 1')  // Cron: Every Monday at midnight
    .timeZone('UTC')
    .onRun(async (context) => {
        console.log('[Scheduled] Starting weekly profile update');

        const userIds = await getAllUsersWithFeedback();
        console.log(`[Scheduled] Updating ${userIds.length} users with feedback`);

        if (userIds.length === 0) {
            console.log('[Scheduled] No users to update');
            return null;
        }

        const db = admin.firestore();
        let usersUpdated = 0;

        for (const userId of userIds) {
            try {
                await updateSingleUserProfile(userId, db);
                usersUpdated++;
            } catch (error) {
                console.error(`[Scheduled] Error updating user ${userId}:`, error);
            }
        }

        console.log(`[Scheduled] Updated ${usersUpdated}/${userIds.length} user profiles`);
        return null;
    });

/**
 * Manual function: Allows users to trigger profile update immediately
 * Callable from iOS app
 */
export const updateUserNotificationProfileManual = functions
    .runWith({
        timeoutSeconds: 60,
        memory: "512MB",
    })
    .https.onCall(async (data, context) => {
        // Authentication
        if (!context?.auth) {
            throw new functions.https.HttpsError(
                "unauthenticated",
                "User must be authenticated"
            );
        }

        const userId = context.auth.uid;
        console.log(`[Manual] Profile update requested by user ${userId}`);

        const db = admin.firestore();

        try {
            await updateSingleUserProfile(userId, db);
            console.log(`[Manual] Profile updated for user ${userId}`);

            return {
                success: true,
                message: "Profile updated successfully"
            };
        } catch (error: any) {
            console.error(`[Manual] Error updating profile:`, error);
            throw new functions.https.HttpsError(
                "internal",
                `Failed to update profile: ${error.message}`
            );
        }
    });

// Keep existing helper functions unchanged:
// - getAllUsersWithFeedback()
// - updateSingleUserProfile()
// - extractKeywords()
```

**Update `functions/src/index.ts`:**
```typescript
export {updateUserNotificationProfileScheduled, updateUserNotificationProfileManual} from "./updateUserNotificationProfile";
// Remove old: export {updateUserNotificationProfile} from "./updateUserNotificationProfile";
```

**Deploy:**
```bash
firebase deploy --only functions:updateUserNotificationProfileScheduled
firebase deploy --only functions:updateUserNotificationProfileManual
```

---

## Performance Optimizations

### Optimization #1: Switch to GPT-4o-mini (QUICK WIN)

**Impact:** 10x faster, 15x cheaper, 85-90% accuracy (vs 95% for GPT-4-turbo)

**File:** `functions/src/services/openai-service.ts:133`

**Current:**
```typescript
const response = await client.chat.completions.create({
    model: "gpt-4-turbo",  // ← Slow & expensive
    messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt }
    ],
    temperature: 0.3,
    response_format: {type: "json_object"},
});
```

**Optimized:**
```typescript
const response = await client.chat.completions.create({
    model: "gpt-4o-mini",  // ← 10x faster, 15x cheaper
    messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt }
    ],
    temperature: 0.3,
    response_format: {type: "json_object"},
});
```

**Performance:**
- Latency: 2-5s → 200-500ms
- Cost: $2.50/1M tokens → $0.15/1M tokens
- Accuracy: 95% → 85-90% (feedback loop will compensate)

**Rationale:**
Your prompt is well-structured with clear rules. GPT-4o-mini excels at this type of classification task. The 5-10% accuracy drop is acceptable given the working feedback loop will personalize over time.

---

### Optimization #2: Fast Heuristic Pre-Filter (70% LLM Skip Rate)

**Impact:** 70% of messages skip LLM entirely, <50ms decision time

**New file:** `functions/src/helpers/fast-heuristic-filter.ts`

```typescript
/**
 * Fast Heuristic Filter for Notification Analysis
 *
 * Implements rule-based filtering to skip LLM for obvious cases
 * - DEFINITELY_NOTIFY: Direct mentions, urgent keywords, direct questions
 * - DEFINITELY_SKIP: Social chat, emoji-only, common acknowledgments
 * - NEED_LLM: Ambiguous cases requiring AI judgment
 */

export type HeuristicDecision = "DEFINITELY_NOTIFY" | "DEFINITELY_SKIP" | "NEED_LLM";

export interface FastDecisionResult {
    decision: HeuristicDecision;
    reason: string;
    priority?: "high" | "medium" | "low";
}

/**
 * Apply fast heuristics to determine if message needs LLM analysis
 *
 * @param message - Message object with text and metadata
 * @param user - User object with displayName and preferences
 * @returns FastDecisionResult
 */
export function applyFastHeuristics(
    message: { text: string; senderId: string; senderName: string },
    user: { id: string; displayName: string; preferredKeywords?: string[] }
): FastDecisionResult {
    const text = message.text.trim();
    const lowerText = text.toLowerCase();

    // ========================================
    // DEFINITELY_NOTIFY (Tier 1 - Obvious)
    // ========================================

    // 1. Direct @mentions
    if (lowerText.includes(`@${user.displayName.toLowerCase()}`)) {
        return {
            decision: "DEFINITELY_NOTIFY",
            reason: "Direct @mention",
            priority: "high"
        };
    }

    // 2. User's name in message (case-insensitive)
    const namePattern = new RegExp(`\\b${user.displayName}\\b`, 'i');
    if (namePattern.test(text)) {
        return {
            decision: "DEFINITELY_NOTIFY",
            reason: "User mentioned by name",
            priority: "high"
        };
    }

    // 3. High-urgency keywords
    const urgentKeywords = /\b(urgent|asap|emergency|critical|blocker|production|p0|priority\s*0)\b/i;
    if (urgentKeywords.test(text)) {
        return {
            decision: "DEFINITELY_NOTIFY",
            reason: "Urgent keyword detected",
            priority: "high"
        };
    }

    // 4. Direct questions to user (looking at previous context would be ideal)
    const directQuestions = /\b(can you|could you|would you|will you|please)\b/i;
    if (directQuestions.test(text) && text.includes('?')) {
        return {
            decision: "DEFINITELY_NOTIFY",
            reason: "Direct question detected",
            priority: "medium"
        };
    }

    // 5. Task assignment patterns
    const taskPatterns = /\b(assigned to|your task|you should|you need to|action item for you)\b/i;
    if (taskPatterns.test(text)) {
        return {
            decision: "DEFINITELY_NOTIFY",
            reason: "Task assignment detected",
            priority: "high"
        };
    }

    // 6. User's custom priority keywords
    if (user.preferredKeywords && user.preferredKeywords.length > 0) {
        const userKeywordPattern = new RegExp(
            `\\b(${user.preferredKeywords.join('|')})\\b`,
            'i'
        );
        if (userKeywordPattern.test(text)) {
            return {
                decision: "DEFINITELY_NOTIFY",
                reason: "User's priority keyword found",
                priority: "medium"
            };
        }
    }

    // ========================================
    // DEFINITELY_SKIP (Tier 1 - Noise)
    // ========================================

    // 1. Empty or very short messages (likely acknowledgments)
    if (text.length < 5) {
        return {
            decision: "DEFINITELY_SKIP",
            reason: "Message too short",
            priority: "low"
        };
    }

    // 2. Common acknowledgments/reactions
    const acknowledgments = /^(ok|okay|k|kk|thanks|thank you|ty|thx|lol|haha|ha|👍|😄|😊|🙏|❤️|nice|cool|sure|yep|yup|nope|got it|sounds good|np|no problem)$/i;
    if (acknowledgments.test(text)) {
        return {
            decision: "DEFINITELY_SKIP",
            reason: "Common acknowledgment/reaction",
            priority: "low"
        };
    }

    // 3. Emoji-only messages
    const emojiPattern = /^[\p{Emoji}\s]+$/u;
    if (emojiPattern.test(text)) {
        return {
            decision: "DEFINITELY_SKIP",
            reason: "Emoji-only message",
            priority: "low"
        };
    }

    // 4. Bot/automated messages
    if (message.senderName.toLowerCase().includes('bot') ||
        message.senderName.toLowerCase().includes('notification')) {
        return {
            decision: "DEFINITELY_SKIP",
            reason: "Automated message",
            priority: "low"
        };
    }

    // 5. Out-of-office or away messages
    const autoReplies = /\b(out of office|away from|on vacation|afk|brb|be right back)\b/i;
    if (autoReplies.test(text)) {
        return {
            decision: "DEFINITELY_SKIP",
            reason: "Auto-reply message",
            priority: "low"
        };
    }

    // ========================================
    // NEED_LLM (Tier 2 - Ambiguous)
    // ========================================

    // Everything else requires AI judgment
    return {
        decision: "NEED_LLM",
        reason: "Message requires contextual analysis",
    };
}
```

**Integration into `analyzeForNotification.ts`:**

```typescript
// Add import
import {applyFastHeuristics} from "./helpers/fast-heuristic-filter";

// Insert BEFORE step 4 (LOAD USER CONTEXT)
// ========================================
// NEW: STEP 3.5 - FAST HEURISTIC FILTER
// ========================================
const firstUnreadMessage = {
    text: unreadMessages[0].data().text || "",
    senderId: unreadMessages[0].data().senderId,
    senderName: "Unknown", // Will fetch if needed
};

// Fetch user displayName for heuristics
let userDisplayName = "Unknown";
try {
    const userDoc = await db.collection("users").doc(userId).get();
    userDisplayName = userDoc.data()?.displayName || "Unknown";
} catch (error) {
    console.error("Error fetching user displayName:", error);
}

// Apply fast heuristics
const heuristicResult = applyFastHeuristics(
    firstUnreadMessage,
    {
        id: userId,
        displayName: userDisplayName,
        preferredKeywords: [] // Will load from preferences if available
    }
);

console.log(`[analyzeForNotification] Heuristic decision: ${heuristicResult.decision}`);

if (heuristicResult.decision === "DEFINITELY_NOTIFY") {
    console.log(`[analyzeForNotification] ⚡ FAST PATH: Notify (${heuristicResult.reason})`);

    // Fetch sender name for notification
    let senderName = "Someone";
    try {
        const senderDoc = await db.collection("users").doc(firstUnreadMessage.senderId).get();
        senderName = senderDoc.data()?.displayName || "Someone";
    } catch (error) {
        console.error("Error fetching sender name:", error);
    }

    const fastDecision: NotificationDecision = {
        shouldNotify: true,
        reason: heuristicResult.reason,
        notificationText: `${senderName}: ${firstUnreadMessage.text.substring(0, 80)}`,
        priority: heuristicResult.priority || "high",
    };

    // Log decision
    await logNotificationDecision(userId, conversationId, fastDecision, unreadMessages);

    // Send notification
    if (fastDecision.shouldNotify) {
        try {
            await sendFCMNotification(userId, conversationId, fastDecision, unreadMessages, db);
        } catch (error) {
            console.error("Error sending FCM notification:", error);
        }
    }

    return fastDecision;
}

if (heuristicResult.decision === "DEFINITELY_SKIP") {
    console.log(`[analyzeForNotification] ⚡ FAST PATH: Skip (${heuristicResult.reason})`);

    const fastDecision: NotificationDecision = {
        shouldNotify: false,
        reason: heuristicResult.reason,
        notificationText: "",
        priority: "low",
    };

    // Log decision
    await logNotificationDecision(userId, conversationId, fastDecision, unreadMessages);

    return fastDecision;
}

// If NEED_LLM, continue with existing RAG + GPT-4 flow...
console.log(`[analyzeForNotification] 🤖 LLM PATH: Requires AI analysis`);
```

**Expected Impact:**
- 40% DEFINITELY_NOTIFY (direct mentions, questions, urgency) → <100ms
- 30% DEFINITELY_SKIP (acknowledgments, emoji, short) → <100ms
- 30% NEED_LLM (contextual) → 500ms (with GPT-4o-mini)
- **Average latency: ~300ms** (down from 5-10s)

---

### Optimization #3: Denormalize Sender Names (Eliminate N+1 Queries)

**Impact:** Saves 1-2 seconds on Firestore reads

**Current Problem:**
`analyzeForNotification.ts:207-227` fetches sender name for EVERY message:

```typescript
const messagesForLLM = await Promise.all(
    unreadMessages.map(async (doc) => {
        const msgData = doc.data();

        // ❌ N+1 query problem (1 read per message)
        let senderName = "Unknown";
        try {
            const senderDoc = await db.collection("users").doc(msgData.senderId).get();
            senderName = senderDoc.data()?.displayName || "Unknown";
        } catch (error) {
            console.error(`Error fetching sender ${msgData.senderId}:`, error);
        }

        return {
            text: msgData.text || "",
            senderId: msgData.senderId,
            senderName,  // ← Expensive
            timestamp: msgData.timestamp.toDate(),
        };
    })
);
```

**Solution:** Store sender name when message is created

**Update iOS app:**

```swift
// MessageAI/Data/Repositories/FirebaseMessageRepository.swift
// In sendMessage() function:

func sendMessage(_ message: Message) async throws {
    // Fetch current user's display name
    let currentUserDoc = try await db.collection("users").document(message.senderId).getDocument()
    let senderDisplayName = currentUserDoc.data()?["displayName"] as? String ?? "Unknown"

    let messageData: [String: Any] = [
        "conversationId": message.conversationId,
        "senderId": message.senderId,
        "senderName": senderDisplayName,  // ← ADD THIS
        "text": message.text,
        "timestamp": FieldValue.serverTimestamp(),
        "status": message.status.rawValue,
        "isEdited": message.isEdited,
        "isDeleted": message.isDeleted,
        "readBy": message.readBy
    ]

    try await db.collection("messages").document(message.id).setData(messageData)
}
```

**Update Cloud Function:**

```typescript
// functions/src/analyzeForNotification.ts:207-227
const messagesForLLM = unreadMessages.map((doc) => {
    const msgData = doc.data();

    return {
        text: msgData.text || "",
        senderId: msgData.senderId,
        senderName: msgData.senderName || "Unknown",  // ← Read from message
        timestamp: msgData.timestamp.toDate(),
    };
});
// No more await Promise.all() - instant!
```

**Performance:**
- Before: 30 messages × 50ms = 1,500ms
- After: 0ms (data already in message)

**Migration:**
Existing messages without `senderName` will fall back to "Unknown" (acceptable for old data)

---

### Optimization #4: Pre-compute Embeddings Asynchronously

**Impact:** Saves 1-2 seconds on RAG indexing

**Current Problem:**
`analyzeForNotification.ts:179-185` generates embeddings on-demand:

```typescript
try {
    const indexingResult = await indexRecentMessages(conversationId, 30);  // ← SLOW
    console.log(`Indexed ${indexingResult.embeddedCount} messages`);
} catch (error) {
    console.error("Error indexing messages:", error);
}
```

**Solution:** Generate embeddings when message is created

**New Cloud Function:**

```typescript
// functions/src/embedMessageOnCreate.ts

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {generateEmbedding} from "./services/openai-service";

/**
 * Cloud Function: Embed Message On Create
 *
 * Firestore Trigger: Generates semantic embedding when new message created
 * Runs asynchronously - doesn't block message sending
 */
export const embedMessageOnCreate = functions
    .runWith({
        timeoutSeconds: 30,
        memory: "256MB",
    })
    .firestore.document('messages/{messageId}')
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const messageText = messageData.text || "";

        // Skip empty messages
        if (messageText.trim().length === 0) {
            console.log(`[embedMessageOnCreate] Skipping empty message ${snap.id}`);
            return null;
        }

        // Skip if already has embedding
        if (messageData.embedding) {
            console.log(`[embedMessageOnCreate] Message ${snap.id} already has embedding`);
            return null;
        }

        try {
            console.log(`[embedMessageOnCreate] Generating embedding for message ${snap.id}`);

            const embedding = await generateEmbedding(messageText);

            await snap.ref.update({
                embedding: embedding,
                embeddedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`[embedMessageOnCreate] ✅ Embedded message ${snap.id}`);

        } catch (error) {
            console.error(`[embedMessageOnCreate] ❌ Error embedding message ${snap.id}:`, error);
            // Don't throw - message is already saved, embedding is optional
        }

        return null;
    });
```

**Update `functions/src/index.ts`:**
```typescript
export {embedMessageOnCreate} from "./embedMessageOnCreate";
```

**Update RAG helper:**

```typescript
// functions/src/helpers/indexConversationForRAG.ts

export async function indexRecentMessages(
    conversationId: string,
    limit: number = 30
): Promise<{ embeddedCount: number }> {
    const db = admin.firestore();

    const messagesSnapshot = await db.collection("messages")
        .where("conversationId", "==", conversationId)
        .orderBy("timestamp", "desc")
        .limit(limit)
        .get();

    let embeddedCount = 0;
    const batchUpdates: Promise<void>[] = [];

    for (const doc of messagesSnapshot.docs) {
        const messageData = doc.data();

        // ✅ Check if already embedded
        if (messageData.embedding) {
            embeddedCount++;
            continue;  // Skip - already done by onCreate trigger
        }

        // ❌ Fallback: Embed on-demand (for old messages only)
        const text = messageData.text || "";
        if (text.trim().length === 0) continue;

        batchUpdates.push(
            generateEmbedding(text).then(embedding => {
                return doc.ref.update({
                    embedding: embedding,
                    embeddedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            })
        );
        embeddedCount++;
    }

    // Wait for any fallback embeddings
    if (batchUpdates.length > 0) {
        console.log(`[indexRecentMessages] Embedding ${batchUpdates.length} old messages`);
        await Promise.all(batchUpdates);
    }

    return { embeddedCount };
}
```

**Performance:**
- New messages: 0ms (already embedded via onCreate trigger)
- Old messages: Fallback on-demand (same as current)
- Average: 0ms after migration period

---

### Optimization #5: Smart Conversation Context Cache

**Impact:** 80%+ cache hit rate (vs current 30%)

**Current Problem:**
Cache key is based on exact unread message set:

```typescript
// analyzeForNotification.ts:386-397
const unreadMessageIds = unreadMessages.map(doc => doc.id).sort();
const cacheKey = generateNotificationCacheKey(conversationId, unreadMessageIds);

// Cache key: notification_conv123_hash(msgA,msgB,msgC)
// New message D arrives → completely new cache key → MISS
```

**Solution:** Cache conversation understanding, not decision

**New file:** `functions/src/helpers/conversation-context-cache.ts`

```typescript
/**
 * Conversation Context Cache
 *
 * Caches semantic understanding of conversation instead of exact message set
 * Allows incremental updates when new messages arrive
 */

import * as admin from "firebase-admin";

export interface ConversationContext {
    conversationId: string;
    recentTopics: string[];  // Extracted via LLM/keywords
    participantActivity: {
        userId: string;
        lastActive: Date;
        messageCount: number;
        isFrequentParticipant: boolean;
    }[];
    semanticIndex: number[][];  // Pre-computed embeddings
    lastMessageTimestamp: Date;
    lastAnalyzedMessageId: string;
    cachedAt: Date;
    expiresAt: Date;
}

/**
 * Get cached conversation context
 * Returns null if cache miss or expired
 */
export async function getCachedConversationContext(
    conversationId: string
): Promise<ConversationContext | null> {
    const db = admin.firestore();

    const cacheDoc = await db.collection("conversation_context_cache")
        .doc(conversationId)
        .get();

    if (!cacheDoc.exists) {
        return null;
    }

    const data = cacheDoc.data();
    if (!data) return null;

    // Check expiration (30 minutes)
    const expiresAt = data.expiresAt.toDate();
    if (expiresAt < new Date()) {
        console.log(`[ConversationCache] Expired: ${conversationId}`);
        await cacheDoc.ref.delete();
        return null;
    }

    return {
        conversationId: data.conversationId,
        recentTopics: data.recentTopics || [],
        participantActivity: data.participantActivity || [],
        semanticIndex: data.semanticIndex || [],
        lastMessageTimestamp: data.lastMessageTimestamp.toDate(),
        lastAnalyzedMessageId: data.lastAnalyzedMessageId,
        cachedAt: data.cachedAt.toDate(),
        expiresAt: expiresAt,
    };
}

/**
 * Store conversation context in cache
 */
export async function storeConversationContext(
    context: Omit<ConversationContext, 'cachedAt' | 'expiresAt'>
): Promise<void> {
    const db = admin.firestore();

    const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 minutes

    await db.collection("conversation_context_cache")
        .doc(context.conversationId)
        .set({
            ...context,
            cachedAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: expiresAt,
        });

    console.log(`[ConversationCache] Stored: ${context.conversationId}`);
}

/**
 * Invalidate cache when conversation changes significantly
 * (e.g., new participant joins, topic shift detected)
 */
export async function invalidateConversationCache(
    conversationId: string
): Promise<void> {
    const db = admin.firestore();

    await db.collection("conversation_context_cache")
        .doc(conversationId)
        .delete();

    console.log(`[ConversationCache] Invalidated: ${conversationId}`);
}
```

**Integration:**

```typescript
// analyzeForNotification.ts

// BEFORE expensive context loading:
const cachedContext = await getCachedConversationContext(conversationId);

if (cachedContext) {
    // Check if new messages since last analysis
    const newestMessageTimestamp = unreadMessages[0].data().timestamp.toDate();

    if (newestMessageTimestamp <= cachedContext.lastMessageTimestamp) {
        console.log(`[analyzeForNotification] Using cached context (no new messages)`);
        // Use cached context for analysis
    } else {
        console.log(`[analyzeForNotification] Incremental update: ${unreadMessages.length} new messages`);
        // Analyze only new messages, merge with cached context
    }
} else {
    console.log(`[analyzeForNotification] Cache miss, full analysis`);
    // Full context load (current behavior)
}
```

**Performance:**
- Cache hit (no new messages): <50ms
- Cache hit (incremental): <500ms (only analyze new messages)
- Cache miss: Same as current
- Expected hit rate: 80%+

---

### Optimization #6: Switch to Firestore Trigger (Real-Time Analysis)

**Impact:** Enables analysis on EVERY message, not just when app backgrounds

**Current Architecture:**
```
App backgrounds → iOS calls analyzeForNotification
```

**Limitation:** Only analyzes when app goes to background

**New Architecture:**
```
New message written to Firestore → Firestore trigger → analyzeForNotification
```

**Benefits:**
- Analyze every message in real-time
- No client-side call needed
- Works even if app crashes/is killed
- Better for group chats (multiple users analyzed in parallel)

**Implementation:**

```typescript
// functions/src/analyzeForNotificationTrigger.ts

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
// Import all helpers from existing analyzeForNotification.ts

/**
 * Firestore Trigger: Analyze For Notification
 *
 * Triggered when new message created
 * Analyzes for ALL conversation participants who are backgrounded
 */
export const analyzeForNotificationTrigger = functions
    .runWith({
        timeoutSeconds: 60,
        memory: "1GB",
    })
    .firestore.document('messages/{messageId}')
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const conversationId = messageData.conversationId;
        const senderId = messageData.senderId;

        console.log(`[analyzeForNotificationTrigger] New message in ${conversationId} from ${senderId}`);

        const db = admin.firestore();

        // Get conversation participants
        const conversationDoc = await db.collection("conversations").doc(conversationId).get();
        if (!conversationDoc.exists) {
            console.error(`Conversation ${conversationId} not found`);
            return null;
        }

        const conversationData = conversationDoc.data();
        const participantIds = conversationData?.participantIds || [];

        // Filter to participants who should be analyzed
        const participantsToAnalyze = participantIds.filter((userId: string) => {
            // Don't notify sender
            if (userId === senderId) return false;

            // TODO: Check if user is actively viewing this conversation
            // (Skip analysis if user has app open and viewing this convo)

            return true;
        });

        console.log(`[analyzeForNotificationTrigger] Analyzing for ${participantsToAnalyze.length} participants`);

        // Analyze for each participant in parallel
        const analysisPromises = participantsToAnalyze.map(async (userId: string) => {
            try {
                // Run existing analysis logic (refactored into helper)
                const decision = await runNotificationAnalysis(userId, conversationId, db);

                console.log(`[analyzeForNotificationTrigger] User ${userId}: ${decision.shouldNotify}`);

            } catch (error) {
                console.error(`[analyzeForNotificationTrigger] Error analyzing for user ${userId}:`, error);
            }
        });

        await Promise.all(analysisPromises);

        console.log(`[analyzeForNotificationTrigger] Completed analysis for ${participantsToAnalyze.length} users`);
        return null;
    });

/**
 * Refactored analysis logic (extracted from original analyzeForNotification)
 * Can be called by both trigger and manual callable function
 */
async function runNotificationAnalysis(
    userId: string,
    conversationId: string,
    db: admin.firestore.Firestore
): Promise<NotificationDecision> {
    // ... existing logic from analyzeForNotification.ts
    // (steps 2-13, excluding auth which is handled by trigger)
}
```

**Backward Compatibility:**

Keep existing `.https.onCall()` function for manual calls from iOS app (useful for testing), but mark as deprecated:

```typescript
// functions/src/analyzeForNotification.ts

/**
 * @deprecated Use Firestore trigger instead (analyzeForNotificationTrigger)
 * Kept for manual testing and backward compatibility
 */
export const analyzeForNotification = functions
    .runWith({ timeoutSeconds: 60, memory: "1GB" })
    .https.onCall(async (data, context) => {
        // ... existing implementation
    });
```

**Migration:**
1. Deploy both functions
2. Test trigger version in dev environment
3. Monitor logs for errors
4. Once stable, remove callable function (or keep for testing)

---

## Implementation Phases

### Phase 0: Critical Bug Fixes (P0) - **2-3 hours**

**MUST complete before any optimizations**

- [ ] Fix Bug #1: Add `decision` parameter to iOS feedback submission
- [ ] Fix Bug #2: Change document ID from "default" to "profile"
- [ ] Fix Bug #3: Add scheduled trigger for profile updates
- [ ] Deploy functions
- [ ] Test feedback loop end-to-end
- [ ] Verify profile updates run weekly

**Success Criteria:**
- ✅ Users can submit feedback without errors
- ✅ Feedback stored in `notification_feedback` collection
- ✅ Profiles auto-update every Monday 00:00 UTC
- ✅ Learned preferences appear in `users/{userId}/ai_notification_profile/profile`
- ✅ Analysis loads and uses learned preferences

---

### Phase 1: Quick Wins (P1) - **1-2 days**

**Goal:** 5-10s → <1s latency with minimal code changes

- [ ] **Opt #1:** Switch to GPT-4o-mini (1 line change)
  - Update `openai-service.ts:133`
  - Test accuracy with sample messages
  - Monitor feedback for quality regressions

- [ ] **Opt #2:** Add fast heuristic pre-filter
  - Create `fast-heuristic-filter.ts`
  - Integrate into `analyzeForNotification.ts`
  - Test with 100 sample messages
  - Measure LLM skip rate (target: 70%)

- [ ] **Opt #3:** Denormalize sender names
  - Update iOS `sendMessage()` to include `senderName`
  - Update Cloud Function to read from message
  - Deploy and test

**Success Criteria:**
- ✅ Average latency < 1 second
- ✅ 70%+ of messages skip LLM
- ✅ Cost reduced by 80%+
- ✅ Accuracy remains >85%

---

### Phase 2: Architectural Improvements (P2) - **3-5 days**

**Goal:** Enable real-time analysis on every message

- [ ] **Opt #4:** Pre-compute embeddings
  - Create `embedMessageOnCreate` trigger
  - Update RAG helpers to check for existing embeddings
  - Deploy and monitor
  - Wait 1 week for all messages to have embeddings

- [ ] **Opt #5:** Smart conversation context cache
  - Create `conversation-context-cache.ts`
  - Implement cache get/set/invalidate
  - Integrate into analysis flow
  - Monitor cache hit rate (target: 80%)

- [ ] **Opt #6:** Switch to Firestore trigger
  - Create `analyzeForNotificationTrigger.ts`
  - Refactor shared logic into helpers
  - Test with multiple participants
  - Monitor for race conditions

**Success Criteria:**
- ✅ Average latency < 500ms
- ✅ Embeddings pre-computed for 95%+ messages
- ✅ Cache hit rate > 80%
- ✅ Real-time analysis on every message

---

### Phase 3: Intelligence Enhancements (P3) - **2-3 days**

**Goal:** Improve decision quality with better context

- [ ] Expand context window (15min → 24 hours)
- [ ] Add conversation topic modeling
- [ ] Build user participation graph
- [ ] Implement smarter quiet hours (learn from user behavior)
- [ ] Add notification grouping (combine multiple messages)

**Success Criteria:**
- ✅ Accuracy > 90% (measured via feedback)
- ✅ User satisfaction score > 4.5/5
- ✅ False positive rate < 5%

---

## Technical Specifications

### Firestore Schema Changes

**New Collections:**

```
conversation_context_cache/{conversationId}
  - conversationId: string
  - recentTopics: string[]
  - participantActivity: array
  - semanticIndex: array (embeddings)
  - lastMessageTimestamp: timestamp
  - lastAnalyzedMessageId: string
  - cachedAt: timestamp
  - expiresAt: timestamp
  - TTL: 30 minutes
```

**Modified Collections:**

```
messages/{messageId}
  - ... existing fields ...
  + senderName: string (ADDED)
  + embedding: number[] (ADDED - 1536 dimensions)
  + embeddedAt: timestamp (ADDED)
```

**No Breaking Changes:**
- Existing messages without `senderName` will display "Unknown" (acceptable)
- Existing messages without `embedding` will generate on-demand (fallback)

---

### Cloud Functions Deployment

**New Functions:**

```bash
# Scheduled profile update (runs weekly)
firebase deploy --only functions:updateUserNotificationProfileScheduled

# Manual profile update (callable from app)
firebase deploy --only functions:updateUserNotificationProfileManual

# Auto-embed messages (Firestore trigger)
firebase deploy --only functions:embedMessageOnCreate

# Real-time notification analysis (Firestore trigger)
firebase deploy --only functions:analyzeForNotificationTrigger
```

**Deprecated Functions:**

```bash
# Keep for backward compatibility, but mark deprecated
# functions:updateUserNotificationProfile (replaced by Scheduled + Manual)
# functions:analyzeForNotification (replaced by Trigger)
```

**Cost Estimate:**

Current (per 1000 analyses):
- Cloud Functions: $0.40
- Firestore reads: 100 × $0.36/M = $0.036
- OpenAI (GPT-4-turbo): $15.00
- **Total: ~$15.50**

Optimized (per 1000 analyses):
- Cloud Functions: $0.40 (same)
- Firestore reads: 10 × $0.36/M = $0.0036
- OpenAI (GPT-4o-mini): $1.00 (70% skip + cheaper model)
- **Total: ~$1.40** (90% reduction)

---

## Testing Requirements

### Phase 0: Bug Fix Testing

**Manual Testing:**
1. Submit feedback via iOS app (thumbs up/down)
2. Verify feedback appears in `notification_feedback` collection
3. Manually trigger `updateUserNotificationProfileManual`
4. Verify profile created in `users/{userId}/ai_notification_profile/profile`
5. Send test message, verify analysis loads profile

**Automated Testing:**
```swift
// MessageAITests/Integration/FeedbackLoopIntegrationTests.swift

func testFeedbackSubmission() async throws {
    // Given: User has notification decision
    let decision = NotificationDecision(...)

    // When: User submits feedback
    try await repository.submitFeedback(
        userId: testUserId,
        conversationId: testConvId,
        messageId: testMsgId,
        feedback: "helpful",
        decision: decision  // ← Must include decision
    )

    // Then: Feedback stored in Firestore
    let feedbackDoc = try await db.collection("notification_feedback")
        .document("\(testUserId)_\(testConvId)_\(testMsgId)")
        .getDocument()

    XCTAssertTrue(feedbackDoc.exists)
    XCTAssertEqual(feedbackDoc.data()?["feedback"] as? String, "helpful")
}
```

---

### Phase 1: Performance Testing

**Latency Benchmarks:**

```typescript
// functions/test/performance.test.ts

describe('analyzeForNotification Performance', () => {
    it('should complete in <1s for direct mentions', async () => {
        const start = Date.now();

        const result = await analyzeForNotification({
            conversationId: 'test',
            userId: 'user123',
            message: { text: '@john urgent bug', senderId: 'user456' }
        });

        const elapsed = Date.now() - start;

        expect(result.shouldNotify).toBe(true);
        expect(elapsed).toBeLessThan(1000);  // <1s
        expect(result.reason).toContain('Direct mention');  // Used heuristics
    });

    it('should skip LLM for acknowledgments', async () => {
        const result = await analyzeForNotification({
            conversationId: 'test',
            userId: 'user123',
            message: { text: 'thanks!', senderId: 'user456' }
        });

        expect(result.shouldNotify).toBe(false);
        expect(result.reason).toContain('acknowledgment');  // Used heuristics, not LLM
    });
});
```

**LLM Skip Rate:**

Track in Cloud Function logs:
```typescript
// Add counters
let heuristicDecisions = 0;
let llmDecisions = 0;

// Log at end
console.log(`[Metrics] Heuristic: ${heuristicDecisions}, LLM: ${llmDecisions}, Skip rate: ${(heuristicDecisions / (heuristicDecisions + llmDecisions) * 100).toFixed(1)}%`);
```

Target: >70% skip rate

---

### Phase 2: Trigger Testing

**Race Condition Testing:**

```typescript
// Test: Multiple messages arrive simultaneously
// Ensure each triggers separate analysis without conflicts

describe('analyzeForNotificationTrigger', () => {
    it('should handle concurrent messages', async () => {
        // Send 10 messages simultaneously
        const promises = Array.from({length: 10}, (_, i) =>
            db.collection('messages').add({
                conversationId: 'test',
                text: `Message ${i}`,
                senderId: 'user123',
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            })
        );

        await Promise.all(promises);

        // Wait for triggers to complete
        await sleep(5000);

        // Verify all triggered analysis
        const decisions = await db.collection('notification_decisions')
            .where('conversationId', '==', 'test')
            .get();

        expect(decisions.size).toBe(10);  // All processed
    });
});
```

---

## Rollout Strategy

### Stage 1: Dev Environment (Week 1)

- Deploy to `messageai-dev-1f2ec`
- Test with internal team (5-10 users)
- Monitor logs for errors
- Measure performance metrics
- Collect feedback

**Success Criteria:**
- Zero errors in logs
- Latency < 1s for 95% of requests
- Feedback loop working end-to-end

---

### Stage 2: Beta Users (Week 2)

- Deploy to production with feature flag
- Enable for 10% of users
- A/B test: new system vs old system
- Monitor metrics:
  - Latency (target: <500ms)
  - Accuracy (target: >85%)
  - User satisfaction (target: >4/5)
  - Cost per analysis (target: <$0.002)

**Rollback Plan:**
- If accuracy drops below 80%, revert to GPT-4-turbo
- If errors spike, disable Firestore trigger, use callable function
- If costs spike, reduce analysis frequency

---

### Stage 3: Full Rollout (Week 3-4)

- Increase to 50% of users
- Monitor for 1 week
- If stable, increase to 100%
- Deprecate old callable function
- Document new architecture

---

## Monitoring & Metrics

### Key Performance Indicators

**Performance Metrics:**
```javascript
// Cloud Functions logs
{
    "metric": "notification_analysis",
    "latency_ms": 450,
    "decision_path": "heuristic" | "llm",
    "cache_hit": true,
    "llm_skip": true,
    "cost_estimate": 0.001
}
```

**Business Metrics:**
```javascript
// Firestore analytics
{
    "notification_accuracy": 0.87,  // % helpful feedback
    "false_positive_rate": 0.08,    // % not_helpful when notified
    "false_negative_rate": 0.12,    // % helpful when suppressed (harder to measure)
    "user_satisfaction": 4.3         // 1-5 scale
}
```

**Dashboards:**

Create in Firebase Console:
1. **Performance Dashboard**
   - Average latency (line chart)
   - P50/P90/P95 latency (histogram)
   - LLM skip rate (gauge)
   - Cache hit rate (gauge)

2. **Quality Dashboard**
   - Accuracy by user (scatter plot)
   - False positive rate (line chart)
   - User feedback distribution (pie chart)
   - Profile learning progress (bar chart)

3. **Cost Dashboard**
   - Total OpenAI cost per day
   - Cost per analysis (trend)
   - Firestore reads per day
   - Cloud Functions invocations

---

## Risk Mitigation

### Risk #1: GPT-4o-mini Accuracy Drop

**Mitigation:**
- Monitor feedback closely during rollout
- Set accuracy threshold: if <80%, revert to GPT-4-turbo
- Feedback loop will compensate over time (personalization)
- Heuristics handle most obvious cases (no AI needed)

---

### Risk #2: Firestore Trigger Overload

**Scenario:** High-volume group chat (100+ messages/min)

**Mitigation:**
- Rate limiting: Max 10 analyses per user per hour (already implemented)
- Batch messages: If 5+ messages in 30s, analyze as single batch
- Circuit breaker: Disable trigger if error rate >10%

**Implementation:**
```typescript
// Add to analyzeForNotificationTrigger
const recentAnalyses = await db.collection('notification_decisions')
    .where('userId', '==', userId)
    .where('timestamp', '>', oneHourAgo)
    .get();

if (recentAnalyses.size >= 10) {
    console.log(`[analyzeForNotificationTrigger] Rate limit exceeded for user ${userId}`);
    return null;  // Skip analysis
}
```

---

### Risk #3: Cache Invalidation Issues

**Scenario:** Stale cache causes wrong decisions

**Mitigation:**
- Short TTL (30 minutes)
- Invalidate on significant events:
  - New participant joins conversation
  - User changes preferences
  - Manual feedback submitted
- Include cache version in key (allow forced refresh)

---

## Appendix: Code Files Modified

### Cloud Functions

**Modified:**
- `functions/src/analyzeForNotification.ts` (add heuristics, optimize queries)
- `functions/src/services/openai-service.ts` (switch model)
- `functions/src/updateUserNotificationProfile.ts` (split into Scheduled + Manual)
- `functions/src/index.ts` (export new functions)
- `functions/src/helpers/user-context.ts` (optimize queries)

**New:**
- `functions/src/helpers/fast-heuristic-filter.ts`
- `functions/src/helpers/conversation-context-cache.ts`
- `functions/src/embedMessageOnCreate.ts`
- `functions/src/analyzeForNotificationTrigger.ts`

---

### iOS App

**Modified:**
- `MessageAI/Data/Repositories/FirebaseNotificationHistoryRepository.swift` (add decision param)
- `MessageAI/Data/Repositories/FirebaseMessageRepository.swift` (denormalize senderName)
- `MessageAI/Presentation/ViewModels/NotificationHistoryViewModel.swift` (pass decision to repo)
- `MessageAI/Domain/Repositories/NotificationHistoryRepositoryProtocol.swift` (update signature)

**No New Files**

---

### Firestore

**New Collections:**
- `conversation_context_cache/{conversationId}`

**Modified Collections:**
- `messages/{messageId}` (add senderName, embedding fields)
- `users/{userId}/ai_notification_profile/profile` (fix document ID)

**New Indexes:**
```json
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "notification_feedback",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## Next Steps

1. **Review this document** with team
2. **Prioritize phases** (recommend: Phase 0 → Phase 1 → Phase 2)
3. **Assign implementation** to engineers
4. **Set timeline** (recommended: 2-3 weeks total)
5. **Create tracking tickets** in project management tool
6. **Schedule daily standups** during implementation

---

## Questions & Clarifications

**Q: Why not use GPT-4o instead of GPT-4o-mini?**
A: GPT-4o is 3x more expensive than GPT-4o-mini with only marginal accuracy improvement for this classification task. The feedback loop will compensate.

**Q: Will Firestore triggers increase costs?**
A: Triggers are free (billed as Cloud Functions). The analysis itself costs the same whether triggered or callable.

**Q: What happens to old messages without embeddings?**
A: Fallback to on-demand embedding (same as current). Over time, all messages will have embeddings via onCreate trigger.

**Q: Can we skip Phase 2 and go straight to Phase 3?**
A: Not recommended. Phase 1 provides 10x improvement with minimal risk. Phase 2 enables real-time analysis (required for scaling). Phase 3 is nice-to-have intelligence improvements.

---

**Document Status:** ✅ Ready for Implementation
**Last Updated:** 2025-01-24
**Author:** Winston (Architect Agent)
**Version:** 1.0
