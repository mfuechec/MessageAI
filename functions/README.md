# Cloud Functions for MessageAI

Firebase Cloud Functions for AI-powered features in MessageAI.

## Overview

This directory contains Node.js/TypeScript Cloud Functions that provide server-side AI processing for:
- **Thread Summarization** (Story 3.5 ✅) - Generate summaries of conversation threads using OpenAI GPT-4
- **Action Item Extraction** - Extract tasks and assignments from conversations
- **Smart Search** - AI-enhanced semantic search across messages

**Story 3.5 Implementation:** Thread summarization now uses real OpenAI GPT-4 API with rate limiting, caching, and user-friendly error handling.

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

## Environment Variables (Story 3.5)

### Getting an OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Sign up or log in
3. Navigate to API Keys section
4. Click "Create new secret key"
5. Copy the key (starts with `sk-...`)

**Cost Estimate:**
- GPT-4 Turbo: ~$0.01 per summary (150-300 words)
- With 24-hour cache: 70%+ cache hit rate reduces costs
- Rate limit: 100 requests/user/day caps maximum cost

### Local Development

Create `functions/.runtimeconfig.json` (gitignored):

```json
{
  "openai": {
    "api_key": "sk-proj-your-openai-api-key-here"
  }
}
```

**IMPORTANT:** Never commit this file to git (already in .gitignore).

### Production

Set environment variables in Firebase:

```bash
# Dev environment
firebase functions:config:set openai.api_key="sk-proj-..." --project=messageai-dev-1f2ec

# Prod environment
firebase functions:config:set openai.api_key="sk-proj-..." --project=messageai-prod-4d3a8

# Verify configuration
firebase functions:config:get --project=messageai-dev-1f2ec
```

Access in functions:

```typescript
const apiKey = functions.config().openai?.api_key || process.env.OPENAI_API_KEY;
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

**Features (Story 3.5):**
- ✅ Real OpenAI GPT-4 Turbo integration
- ✅ Authentication check (Firebase Auth token required)
- ✅ Participant verification (user must be in conversation)
- ✅ Rate limiting (100 requests/user/day)
- ✅ Cache lookup (24-hour expiration)
- ✅ User-friendly error messages
- ✅ Graceful fallback when AI unavailable

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

## Story 3.1 vs Story 3.5 ✅ COMPLETED

| Feature | Story 3.1 | Story 3.5 |
|---------|-----------|-----------|
| **Cloud Functions** | ✅ Implemented with placeholders | ✅ Real OpenAI GPT-4 Turbo |
| **Authentication** | ✅ Working | ✅ Working |
| **Caching** | ✅ Working (24 hours) | ✅ Working (24 hours) |
| **AI Responses** | ❌ Placeholder text | ✅ Real AI summaries |
| **Rate Limiting** | ❌ Not implemented | ✅ 100 req/day per user |
| **Error Handling** | ✅ Basic | ✅ User-friendly messages |
| **Cost Optimization** | N/A | ✅ Cache + Rate limits |

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

## Completed (Story 3.5) ✅

- [x] Real OpenAI GPT-4 Turbo integration
- [x] JSON-based structured outputs
- [x] Rate limiting (100 requests/day per user)
- [x] User-friendly error messages
- [x] Graceful fallback when AI unavailable

## Future Enhancements (Story 3.6+)

- [ ] Cost tracking dashboard in Firebase Analytics
- [ ] Unit tests with Jest
- [ ] Additional AI models (Claude, Gemini)
- [ ] Performance optimization (parallel requests)
- [ ] Function calling for more structured extraction

## References

- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [TypeScript Guide](https://www.typescriptlang.org/docs/)
- [Story 3.1 Documentation](../docs/stories/3.1.cloud-functions-infrastructure-for-ai.md)
- [Story 3.5 Documentation](../docs/stories/3.5.ai-service-selection-and-configuration.md)
