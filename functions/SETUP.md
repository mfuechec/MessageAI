# OpenAI API Key Setup Guide (Story 3.5)

This guide will help you configure the OpenAI API key for MessageAI's AI-powered features.

## Quick Setup (5 minutes)

### Step 1: Get an OpenAI API Key

1. Visit [OpenAI Platform](https://platform.openai.com/)
2. Sign up or log in to your account
3. Navigate to **API Keys** section
4. Click **"Create new secret key"**
5. Give it a name (e.g., "MessageAI Dev")
6. Copy the key immediately (starts with `sk-proj-...`)
   - ⚠️ **Important**: You can only view the key once. Save it securely!

### Step 2: Configure for Local Development

Create a `.runtimeconfig.json` file in the `functions/` directory:

```bash
# From project root
cd functions
cat > .runtimeconfig.json <<EOF
{
  "openai": {
    "api_key": "sk-proj-YOUR-API-KEY-HERE"
  }
}
EOF
```

Replace `YOUR-API-KEY-HERE` with your actual OpenAI API key.

**Security Note:** This file is already in `.gitignore` and will never be committed to git.

### Step 3: Verify Configuration

Test that the configuration works:

```bash
# Build functions
npm run build

# Start Firebase emulator
npm run serve

# In another terminal, test the function
curl -X POST http://localhost:5001/messageai-dev-1f2ec/us-central1/summarizeThread \
  -H "Content-Type: application/json" \
  -d '{"data":{"conversationId":"test123"}}'
```

If you see an error about authentication, that's expected - it means the function is working!

## Production Deployment

### Step 1: Set API Key in Firebase

```bash
# Dev environment
firebase functions:config:set openai.api_key="sk-proj-YOUR-KEY" --project=messageai-dev-1f2ec

# Verify it was set
firebase functions:config:get --project=messageai-dev-1f2ec
```

### Step 2: Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions --project=messageai-dev-1f2ec

# Or deploy just summarizeThread
firebase deploy --only functions:summarizeThread --project=messageai-dev-1f2ec
```

### Step 3: Test in Production

Use the iOS app to test:

1. Open MessageAI in iOS Simulator
2. Log in and navigate to any conversation
3. Tap the sparkle (✨) button
4. Select "Summarize Thread"
5. Wait 5-10 seconds for the real AI summary

## Cost Management

### OpenAI Pricing (as of 2025)

- **GPT-4 Turbo**: $0.01 per 1K input tokens, $0.03 per 1K output tokens
- **Average summary cost**: ~$0.01 per conversation (100 messages)
- **With cache (70% hit rate)**: ~$0.003 per request

### Built-in Cost Controls

MessageAI includes automatic cost protection:

1. **Rate Limiting**: 100 AI requests per user per day
2. **Caching**: 24-hour cache reduces repeated calls by 70%+
3. **Message Limits**: Only processes last 100 messages per conversation

### Monitor Usage

View usage in OpenAI dashboard:
- Visit [OpenAI Usage Dashboard](https://platform.openai.com/usage)
- Check daily/monthly costs
- Set usage limits to prevent overspending

**Recommended Limit**: $50/month for development, $200/month for small production

## Troubleshooting

### "OpenAI API key not configured"

**Problem**: Function returns error about missing API key

**Solution**:
```bash
# Check if key is set
firebase functions:config:get --project=messageai-dev-1f2ec

# If empty, set it
firebase functions:config:set openai.api_key="sk-proj-..." --project=messageai-dev-1f2ec

# Redeploy functions
firebase deploy --only functions --project=messageai-dev-1f2ec
```

### "Rate limit exceeded" (OpenAI Error)

**Problem**: OpenAI returns 429 error

**Solution**:
1. Check OpenAI dashboard for current tier limits
2. Upgrade OpenAI account tier if needed
3. Wait a few minutes and try again
4. Consider implementing additional caching

### "Daily limit exceeded" (MessageAI Error)

**Problem**: User hit 100 requests/day limit

**Solution**:
- Wait until tomorrow (limit resets at midnight UTC)
- Or increase limit in `functions/src/utils/rateLimiting.ts`:
  ```typescript
  const DEFAULT_DAILY_LIMIT = 200; // Increase from 100
  ```

### Local Emulator Not Working

**Problem**: Emulator can't find API key

**Solution**:
```bash
# Verify .runtimeconfig.json exists
cat functions/.runtimeconfig.json

# If missing, create it (see Step 2 above)

# Restart emulator
./scripts/stop-emulator.sh
./scripts/start-emulator.sh
```

## Security Best Practices

### DO ✅

- Store API keys in Firebase config (production)
- Store API keys in `.runtimeconfig.json` (local dev)
- Add `.runtimeconfig.json` to `.gitignore`
- Set spending limits in OpenAI dashboard
- Rotate keys periodically (every 90 days)

### DON'T ❌

- Never commit API keys to git
- Never hardcode keys in source code
- Never share keys in Slack/Discord
- Never use production keys for development
- Never skip rate limiting

## Alternative: Using Environment Variables

For local development, you can also use environment variables:

```bash
# Add to your ~/.zshrc or ~/.bashrc
export OPENAI_API_KEY="sk-proj-..."

# Functions will automatically detect this
```

This is useful if you work on multiple Firebase projects and don't want separate config files.

## Next Steps

Once you have the API key configured:

1. **Test locally**: Use emulator to verify summaries work
2. **Deploy to dev**: Test with real iOS app
3. **Monitor costs**: Check OpenAI dashboard daily for first week
4. **Optimize**: Adjust cache duration or rate limits based on usage

## Support

- **OpenAI Docs**: https://platform.openai.com/docs
- **Firebase Docs**: https://firebase.google.com/docs/functions/config-env
- **MessageAI Issues**: Report issues in project GitHub repo

---

**Last Updated**: Story 3.5 implementation (October 2025)
