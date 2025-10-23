# Enable Firebase Emulator for Testing

## Problem
The app is hitting **production** Firebase instead of the **local emulator**, even though the emulator is running.

## Solution
Add the `USE_FIREBASE_EMULATOR` launch argument to your Xcode scheme.

## Steps

### In Xcode:

1. **Click on the scheme selector** (top left, next to the stop button)
   - It should say "MessageAI" with a device name

2. **Click "Edit Scheme..."**

3. **Select "Run" in the left sidebar**

4. **Go to "Arguments" tab**

5. **Under "Arguments Passed On Launch"**, click the **+** button

6. **Add this argument**:
   ```
   USE_FIREBASE_EMULATOR
   ```

7. **Make sure the checkbox is CHECKED** ✅

8. **Click "Close"**

9. **Clean Build Folder** (Product → Clean Build Folder)

10. **Run the app** (Cmd+R)

11. **Check Xcode console** - you should now see:
    ```
    🔥 Using Firebase Emulator
    🔥 Cloud Functions emulator: localhost:5001
    ```

## Verify It's Working

After running the app with the launch argument, try the AI summary again. You should see:

```
🔥 Using Firebase Emulator
🔥 Cloud Functions emulator: localhost:5001
🟡 [SummaryViewModel] Starting loadSummary()
🟢 [FirebaseAIService] summarizeThread() called
🔵 [CloudFunctions] Calling summarizeThread
✅ [CloudFunctions] summarizeThread succeeded
```

## Alternative: Set API Key in Production (Not Recommended for Dev)

If you prefer to test against production instead of emulator:

```bash
firebase functions:config:set openai.api_key="sk-proj-YOUR_KEY" --project=messageai-dev-1f2ec

# Then redeploy
firebase deploy --only functions:summarizeThread --project=messageai-dev-1f2ec
```

**But using emulator is better because:**
- ✅ Faster iteration (no deploy wait)
- ✅ Free (no Firebase/OpenAI costs)
- ✅ Isolated testing (won't affect production data)
- ✅ Can test offline scenarios

## Troubleshooting

### Still seeing "Code 13 INTERNAL" error?

1. **Check console for emulator message**:
   - If you DON'T see "🔥 Using Firebase Emulator", the launch argument isn't set
   - Go back to step 1 and verify the argument is added AND checked

2. **Verify emulator is running**:
   ```bash
   curl http://localhost:4000
   # Should show Firebase Emulator UI HTML
   ```

3. **Check emulator logs**:
   - Open http://localhost:4000 in browser
   - Go to "Logs" tab
   - Look for `summarizeThread` errors

### Emulator not running?

```bash
cd /Users/mfuechec/Desktop/Gauntlet\ Projects/MessageAI
./scripts/start-emulator.sh
```

### Need to restart emulator with new API key?

```bash
./scripts/stop-emulator.sh
./scripts/start-emulator.sh
```

The emulator reads `.runtimeconfig.json` on startup, so if you update your OpenAI key, restart the emulator.
