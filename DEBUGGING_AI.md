# Debugging AI Features - Story 3.5

## Quick Diagnostic Checklist

When you see "**AI service temporarily unavailable**", check these in order:

### 1. Check Xcode Console Logs 📋

**Run the app and look for these log patterns:**

```
🟡 [SummaryViewModel] Starting loadSummary()
   Conversation ID: <conversation-id>
   Message IDs: 0

🟢 [FirebaseAIService] summarizeThread() called
   Conversation ID: <conversation-id>

🔵 [CloudFunctions] Calling summarizeThread
   Conversation ID: <conversation-id>
   Message IDs: 0 messages
```

**If you see:**

#### ❌ Error Pattern 1: "Function not found"
```
❌ [CloudFunctions] NSError:
   Domain: com.firebase.functions
   Code: 5 (NOT_FOUND)
   Description: NOT_FOUND
```

**Solution**: Cloud Functions not deployed
```bash
cd functions
npm run build
firebase deploy --only functions:summarizeThread --project=messageai-dev-1f2ec
```

---

#### ❌ Error Pattern 2: "Unauthenticated"
```
❌ [CloudFunctions] NSError:
   Domain: com.firebase.functions
   Code: 16 (UNAUTHENTICATED)
```

**Solution**: User not logged in
- Make sure you're logged in to the iOS app
- Check Firebase Auth console: https://console.firebase.google.com/project/messageai-dev-1f2ec/authentication/users

---

#### ❌ Error Pattern 3: "Internal error" or "unavailable"
```
❌ [CloudFunctions] NSError:
   Domain: com.firebase.functions
   Code: 13 (INTERNAL)
   Description: internal
```

**Solution**: Check Cloud Function logs
```bash
# View last 100 lines
firebase functions:log --limit 100 --project=messageai-dev-1f2ec

# Follow logs in real-time
firebase functions:log --follow --project=messageai-dev-1f2ec
```

**Common causes:**
- OpenAI API key not configured
- OpenAI API key invalid
- OpenAI rate limit exceeded
- Function crashed/timeout

---

### 2. Check Cloud Function Deployment Status 🚀

```bash
# List deployed functions
firebase functions:list --project=messageai-dev-1f2ec

# You should see:
# summarizeThread
# extractActionItems
# generateSmartSearchResults
```

**If functions are missing:**
```bash
cd functions
npm install
npm run build
firebase deploy --only functions --project=messageai-dev-1f2ec
```

---

### 3. Check OpenAI API Key Configuration 🔑

#### Local Development (Emulator)

**Check if `.runtimeconfig.json` exists:**
```bash
cat functions/.runtimeconfig.json

# Should output:
# {
#   "openai": {
#     "api_key": "sk-proj-..."
#   }
# }
```

**If missing or has placeholder:**
```bash
cd functions
cat > .runtimeconfig.json <<EOF
{
  "openai": {
    "api_key": "sk-proj-YOUR-REAL-KEY-HERE"
  }
}
EOF
```

Get your key from: https://platform.openai.com/api-keys

---

#### Production (Firebase)

**Check if key is set:**
```bash
firebase functions:config:get --project=messageai-dev-1f2ec

# Should output:
# {
#   "openai": {
#     "api_key": "sk-proj-..."
#   }
# }
```

**If missing or placeholder:**
```bash
firebase functions:config:set openai.api_key="sk-proj-..." --project=messageai-dev-1f2ec

# Then redeploy
firebase deploy --only functions --project=messageai-dev-1f2ec
```

---

### 4. Check Firebase Emulator (if testing locally) 🔧

**If using emulator, make sure it's running:**
```bash
# Check if emulator is running
curl http://localhost:4000

# Should return Firebase Emulator Suite UI
```

**Start emulator if not running:**
```bash
./scripts/start-emulator.sh
```

**Check iOS app is pointing to emulator:**
```swift
// In AppDelegate or FirebaseService.swift, should see:
#if DEBUG
Functions.functions().useEmulator(withHost: "localhost", port: 5001)
#endif
```

---

### 5. Test Cloud Function Directly 🧪

**Test with curl (replace with your auth token):**

```bash
# Get auth token from iOS app logs or Firebase console
AUTH_TOKEN="your-firebase-auth-token"

# Test local emulator
curl -X POST http://localhost:5001/messageai-dev-1f2ec/us-central1/summarizeThread \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "data": {
      "conversationId": "test-conversation-id"
    }
  }'

# Test production
firebase functions:call summarizeThread \
  --data='{"conversationId":"test-conversation-id"}' \
  --project=messageai-dev-1f2ec
```

**Expected response:**
```json
{
  "success": true,
  "summary": "...",
  "keyPoints": ["...", "..."],
  "participants": ["..."],
  "dateRange": "...",
  "cached": false,
  "timestamp": "2025-10-23T..."
}
```

---

## Common Issues & Solutions

### Issue: "No messages found in this conversation"

**Symptoms:**
```
Error: NOT_FOUND - No messages found in this conversation
```

**Cause:** Conversation has no messages or messages are all deleted

**Solution:**
1. Send at least one message in the conversation
2. Try summarizing a different conversation

---

### Issue: "Rate limit exceeded"

**Symptoms:**
```
Error: RESOURCE_EXHAUSTED - Daily AI request limit exceeded (100 requests per day)
```

**Cause:** User hit 100 requests today

**Solution:**
```bash
# Check rate limit document
firebase firestore:read --project=messageai-dev-1f2ec \
  "rate_limits/{userId}_{date}"

# Delete to reset (dev only!)
firebase firestore:delete --project=messageai-dev-1f2ec \
  "rate_limits/{userId}_{date}"
```

Or increase limit in `functions/src/utils/rateLimiting.ts`:
```typescript
const DEFAULT_DAILY_LIMIT = 200; // Increase from 100
```

---

### Issue: "OpenAI API error 429"

**Symptoms:**
```
Error: AI service rate limit exceeded. Please try again in a few minutes.
```

**Cause:** OpenAI API rate limit (not MessageAI rate limit)

**Solution:**
1. Check your OpenAI usage: https://platform.openai.com/usage
2. Wait 60 seconds and try again
3. Upgrade OpenAI tier: https://platform.openai.com/settings/organization/billing/overview

---

### Issue: "OpenAI API error 401"

**Symptoms:**
```
Error: AI service configuration error. Please contact support.
```

**Cause:** Invalid or expired OpenAI API key

**Solution:**
1. Check key is valid: https://platform.openai.com/api-keys
2. Generate new key if needed
3. Update config:
   ```bash
   firebase functions:config:set openai.api_key="sk-proj-NEW-KEY" --project=messageai-dev-1f2ec
   firebase deploy --only functions --project=messageai-dev-1f2ec
   ```

---

## Logging Levels

**With Story 3.5 logging improvements, you'll see:**

### ✅ Successful Flow:
```
🟡 [SummaryViewModel] Starting loadSummary()
🟢 [FirebaseAIService] summarizeThread() called
🔵 [CloudFunctions] Calling summarizeThread
✅ [CloudFunctions] summarizeThread succeeded
📦 [CloudFunctions] Response data: success, summary, keyPoints, participants, dateRange, cached, timestamp
🟢 [FirebaseAIService] Cloud Function response received
✅ [FirebaseAIService] Mapped to ThreadSummary successfully
✅ [SummaryViewModel] Received summary successfully
   Summary length: 287 characters
   Key points: 4
   Cached: false
```

### ❌ Error Flow:
```
🟡 [SummaryViewModel] Starting loadSummary()
🟢 [FirebaseAIService] summarizeThread() called
🔵 [CloudFunctions] Calling summarizeThread
❌ [CloudFunctions] NSError:
   Domain: com.firebase.functions
   Code: 13
   Description: INTERNAL
   UserInfo: {...}
❌ [SummaryViewModel] AIServiceError caught:
   Error: serviceUnavailable
   Description: AI service temporarily unavailable. Please try again later.
```

---

## Quick Fixes Reference

| Error Message | Quick Fix |
|---------------|-----------|
| "Function not found" | `firebase deploy --only functions` |
| "Unauthenticated" | Log in to iOS app |
| "No messages found" | Send messages first |
| "Rate limit exceeded (100/day)" | Wait until tomorrow or increase limit |
| "OpenAI rate limit" | Wait 60 seconds |
| "Invalid API key" | Update key in Firebase config |
| "Service unavailable" | Check Cloud Function logs |

---

## Still Stuck?

**1. Check Firebase Console Logs:**
https://console.firebase.google.com/project/messageai-dev-1f2ec/functions/logs

**2. Enable verbose logging in Cloud Functions:**
```typescript
// In functions/src/summarizeThread.ts, add:
console.log("DEBUG: Full request data:", JSON.stringify(data));
console.log("DEBUG: Messages loaded:", messages.length);
console.log("DEBUG: OpenAI API key configured:", !!openai.apiKey);
```

**3. Test with Firebase Emulator UI:**
- Open http://localhost:4000
- Go to Functions tab
- Manually trigger `summarizeThread` with test data
- View real-time logs

---

## Why NOT LangChain/LangGraph?

**You asked about LangChain - here's why we don't need it:**

### ❌ LangChain is Overkill for This:

```typescript
// With LangChain (unnecessary complexity)
const chain = new LLMChain({
  llm: new OpenAI({ apiKey: "..." }),
  prompt: PromptTemplate.fromTemplate("..."),
  memory: new BufferMemory(),
});
const result = await chain.call({ input: conversationText });
```

```typescript
// Direct OpenAI SDK (what we use - simple & clear)
const completion = await openai.chat.completions.create({
  model: "gpt-4-turbo",
  messages: [{ role: "user", content: conversationText }]
});
```

### ✅ Use LangChain When You Need:
- Multi-step reasoning chains
- Agent-based systems (tools, planning, execution)
- RAG (Retrieval Augmented Generation)
- Complex prompt chaining
- LangSmith debugging/tracing

### ✅ Use Direct OpenAI SDK (Our Approach) When:
- Single API call (like summarization)
- Simple, predictable flow
- Lower dependencies
- Easier debugging
- Full control over prompts

**For MessageAI's thread summarization: Direct OpenAI SDK is the right choice.** 🎯

---

Last Updated: Story 3.5 (October 2025)
