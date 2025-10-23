# OpenAI API Key Setup Instructions

## Current Status
❌ OpenAI API key is NOT configured (placeholder detected)
✅ Cloud Functions are deployed
✅ iOS app builds successfully

## Setup Steps

### 1. Get OpenAI API Key
- Go to: https://platform.openai.com/api-keys
- Sign up or log in
- Click "Create new secret key"
- Copy the key (starts with `sk-proj-...`)

### 2. Update Local Config (for testing with emulator)

Run this command, replacing `YOUR_ACTUAL_KEY` with your real OpenAI API key:

```bash
cd functions
cat > .runtimeconfig.json <<'EOF'
{
  "openai": {
    "api_key": "sk-proj-YOUR_ACTUAL_KEY_HERE"
  }
}
EOF
```

### 3. (Optional) Deploy to Production Firebase

If you want to test against production (not emulator):

```bash
firebase functions:config:set openai.api_key="sk-proj-YOUR_ACTUAL_KEY_HERE" --project=messageai-dev-1f2ec

# Then redeploy functions
firebase deploy --only functions:summarizeThread --project=messageai-dev-1f2ec
```

## Testing AI Features

### Option A: Test with Firebase Emulator (Recommended)

1. Start the emulator:
   ```bash
   cd /Users/mfuechec/Desktop/Gauntlet\ Projects/MessageAI
   ./scripts/start-emulator.sh
   ```

2. In Xcode, make sure you're using DEBUG configuration (which automatically points to emulator)

3. Build and run the app in simulator

4. Create a conversation and send a few messages

5. Tap the sparkle ✨ button in the chat toolbar

6. Select "Summarize Thread"

7. You should see:
   - "Analyzing conversation..." for 5-10 seconds
   - AI-generated summary with key points

### Option B: Test against Production

1. Deploy functions with API key (Step 3 above)

2. In Xcode, switch to RELEASE configuration

3. Build and run

## Troubleshooting

### Error: "AI service temporarily unavailable"

Check Xcode console logs for:
```
🟡 [SummaryViewModel] Starting loadSummary()
🟢 [FirebaseAIService] summarizeThread() called
🔵 [CloudFunctions] Calling summarizeThread
```

If you see `❌ [CloudFunctions] NSError: Code 13`, check:
1. OpenAI API key is set correctly
2. Functions are deployed
3. You're connected to the internet

### Check Cloud Function Logs

```bash
firebase functions:log --limit 20 --project=messageai-dev-1f2ec
```

Look for errors like:
- "OpenAI API error 401" → Invalid API key
- "OpenAI API error 429" → Rate limit exceeded

## Cost Monitoring

- Each summary costs ~$0.01-0.02
- Free tier: $5 credit from OpenAI
- Monitor usage: https://platform.openai.com/usage

## Smart Cache Invalidation (Story 3.5)

The system now uses smart caching:
- Summaries cached for 24 hours
- Only regenerates if >10 new messages OR >24 hours old
- Shows "(5 new messages since summary)" indicator when using slightly stale cache
- Saves ~70-80% on OpenAI costs
