# Cloud Functions for MessageAI

Firebase Cloud Functions for AI-powered features in MessageAI.

## Overview

This directory contains Node.js/TypeScript Cloud Functions that provide server-side AI processing for:
- **Thread Summarization** - Generate summaries of conversation threads
- **Action Item Extraction** - Extract tasks and assignments from conversations
- **Smart Search** - AI-enhanced semantic search across messages

**Story 3.1 Implementation Note:** These functions currently return placeholder responses. Real AI integration with OpenAI will be implemented in Story 3.5.

## Project Structure

```
functions/
├── src/
│   ├── index.ts                      # Entry point, exports all functions
│   ├── summarizeThread.ts            # Thread summarization function
│   ├── extractActionItems.ts         # Action item extraction function
│   ├── generateSmartSearchResults.ts # Smart search function
│   └── utils/
│       ├── cache.ts                  # Cache lookup/storage helpers
│       └── security.ts               # Participant validation helpers
├── lib/                              # Compiled JavaScript (gitignored)
├── package.json                      # Dependencies and scripts
├── tsconfig.json                     # TypeScript configuration
└── .runtimeconfig.json               # Local env vars (gitignored)
```

## Prerequisites

- Node.js 18+ (required by Firebase Cloud Functions)
- Firebase CLI: `npm install -g firebase-tools`
- Firebase project access (messageai-dev or messageai-prod)

## Installation

```bash
cd functions
npm install
```

## Local Development

### Build TypeScript

```bash
npm run build
```

### Watch mode (auto-rebuild on file changes)

```bash
npm run build:watch
```

### Run with Firebase Emulator

```bash
# Terminal 1: Start emulator
cd functions
npm run serve

# Terminal 2: Test with iOS app pointing to emulator
# Functions.functions().useEmulator(withHost: "localhost", port: 5001)
```

## Environment Variables

### Local Development

Create `functions/.runtimeconfig.json` (gitignored):

```json
{
  "openai": {
    "api_key": "placeholder-for-story-3.1"
  }
}
```

**Note:** Story 3.1 uses placeholder responses. Real API key will be added in Story 3.5.

### Production

Set environment variables in Firebase:

```bash
# Dev environment
firebase functions:config:set openai.api_key="your-api-key" --project=messageai-dev-1f2ec

# Prod environment
firebase functions:config:set openai.api_key="your-api-key" --project=messageai-prod-4d3a8
```

Access in functions:

```typescript
const apiKey = functions.config().openai?.api_key;
```

## Deployment

### Deploy to Dev

```bash
firebase deploy --only functions --project=messageai-dev-1f2ec
```

### Deploy to Prod

```bash
firebase deploy --only functions --project=messageai-prod-4d3a8
```

### Deploy Single Function

```bash
firebase deploy --only functions:summarizeThread --project=messageai-dev-1f2ec
```

## Cloud Functions

### 1. summarizeThread

Generates an AI summary of a conversation thread.

**Input:**
```typescript
{
  conversationId: string,
  messageIds?: string[]  // Optional specific messages (default: last 100)
}
```

**Output:**
```typescript
{
  success: boolean,
  summary: string,
  keyPoints: string[],
  participants: string[],
  dateRange: string,
  cached: boolean,
  timestamp: string
}
```

**Features:**
- Authentication check (Firebase Auth token required)
- Participant verification (user must be in conversation)
- Cache lookup (24-hour expiration)
- Error handling (rate limits, timeouts, validation errors)

### 2. extractActionItems

Extracts action items from a conversation.

**Input:**
```typescript
{
  conversationId: string,
  messageIds?: string[]
}
```

**Output:**
```typescript
{
  success: boolean,
  actionItems: [
    {
      task: string,
      assignee: string,
      assigneeId: string | null,
      deadline: string | null,
      sourceMessageId: string,
      priority: string
    }
  ],
  cached: boolean,
  timestamp: string
}
```

### 3. generateSmartSearchResults

Performs AI-enhanced semantic search.

**Input:**
```typescript
{
  query: string,
  conversationIds?: string[]  // Optional (default: all user's conversations)
}
```

**Output:**
```typescript
{
  success: boolean,
  results: [
    {
      messageId: string,
      conversationId: string,
      snippet: string,
      relevanceScore: number,
      timestamp: Date | null,
      senderName: string
    }
  ],
  cached: boolean,
  timestamp: string
}
```

## Error Codes

Cloud Functions return structured error codes:

- `unauthenticated` - User not logged in
- `permission-denied` - User not participant in conversation
- `invalid-argument` - Missing or invalid input parameters
- `resource-exhausted` - Rate limit exceeded
- `deadline-exceeded` - Function timeout (> 60 seconds)
- `internal` - Generic server error

iOS `CloudFunctionsService` maps these to user-friendly error messages.

## Caching Strategy

All AI functions use Firestore `ai_cache` collection for caching:

**Cache Keys:**
- Summary: `summary_${conversationId}_${latestMessageId}`
- Action Items: `actionItems_${conversationId}_${latestMessageId}`
- Search: `search_${queryHash}_${conversationIdsHash}`

**Expiration:**
- Summaries/Action Items: 24 hours
- Search: 5 minutes

**Cache Invalidation:**
- New message → latestMessageId changes → new cache key → fresh result
- User can manually regenerate (bypasses cache)

## Monitoring & Logs

### View Logs

```bash
# All functions
firebase functions:log --project=messageai-dev-1f2ec

# Specific function
firebase functions:log --only summarizeThread --project=messageai-dev-1f2ec

# Follow logs in real-time
firebase functions:log --project=messageai-dev-1f2ec --follow
```

### Firebase Console

View logs, metrics, and errors:
https://console.firebase.google.com/project/messageai-dev-1f2ec/functions

## Testing

### Unit Tests

```bash
cd functions
npm test
```

*Note: Unit tests not yet implemented in Story 3.1. Planned for Story 3.5 with Jest.*

### Integration Tests

Integration tests run from iOS test suite:

```bash
# Start Firebase Emulator
./scripts/start-emulator.sh

# Run iOS integration tests (from project root)
./scripts/quick-test.sh --test CloudFunctionsIntegrationTests --with-integration
```

## Story 3.1 vs Story 3.5

| Feature | Story 3.1 | Story 3.5 |
|---------|-----------|-----------|
| **Cloud Functions** | ✅ Implemented with placeholders | Real OpenAI integration |
| **Authentication** | ✅ Working | ✅ Working |
| **Caching** | ✅ Working | ✅ Working |
| **AI Responses** | ❌ Placeholder text | ✅ Real AI summaries |
| **Rate Limiting** | ❌ Not implemented | ✅ 100 req/day per user |
| **Cost Tracking** | ❌ Not implemented | ✅ Firebase Analytics |

## Troubleshooting

### "OpenAI API key not configured"

Set the environment variable:
```bash
firebase functions:config:set openai.api_key="placeholder" --project=messageai-dev-1f2ec
```

Or for local development, create `functions/.runtimeconfig.json`.

### "User must be authenticated"

Ensure Firebase Auth token is included in function call:
```swift
// iOS automatically includes auth token when using Firebase SDK
let result = try await Functions.functions().httpsCallable("summarizeThread").call(data)
```

### Deployment Fails

Check Node.js version:
```bash
node --version  # Should be 18.x or higher
```

Rebuild TypeScript:
```bash
cd functions
npm run build
```

### Emulator Issues

Restart emulator:
```bash
./scripts/stop-emulator.sh
./scripts/start-emulator.sh
```

Check emulator UI: http://localhost:4000

## Future Enhancements (Story 3.5+)

- [ ] Real OpenAI GPT-4 Turbo integration
- [ ] Function calling for structured outputs
- [ ] Rate limiting (100 requests/day per user)
- [ ] Cost tracking and analytics
- [ ] User-friendly error messages
- [ ] Graceful fallback when AI unavailable
- [ ] Unit tests with Jest
- [ ] Performance optimization

## References

- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [TypeScript Guide](https://www.typescriptlang.org/docs/)
- [Story 3.1 Documentation](../docs/stories/3.1.cloud-functions-infrastructure-for-ai.md)
- [Story 3.5 Documentation](../docs/stories/3.5.ai-service-selection-and-configuration.md)
