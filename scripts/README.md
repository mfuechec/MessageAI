# MessageAI Scripts

Utility scripts for development and testing.

## Seed Test Data Script

Creates test users, conversations, and messages in Firebase for manual testing.

### Setup (One-Time)

1. **Install dependencies:**
   ```bash
   cd scripts
   npm install
   ```

2. **Download Firebase Admin SDK Key:**
   
   For DEV database:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select `messageai-dev-1f2ec` project
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `firebase-admin-key-dev.json` in project root (one level up from scripts/)
   
   For PROD database (optional):
   - Select `messageai-prod-4d3a8` project
   - Repeat above steps
   - Save as `firebase-admin-key-prod.json`

3. **Add keys to .gitignore** (already done if following standard setup):
   ```
   firebase-admin-key-*.json
   ```

### Usage

**Seed DEV database (default):**
```bash
npm run seed
```

**Seed PROD database (use carefully!):**
```bash
npm run seed:prod
```

### What Gets Created

- **3 Test Users:**
  - `test1@messageai.dev` / `password123` (Alice TestUser)
  - `test2@messageai.dev` / `password123` (Bob TestUser)
  - `test3@messageai.dev` / `password123` (Charlie TestUser)

- **3 Conversations:**
  - 1-on-1: Alice ↔ Bob (5 messages)
  - 1-on-1: Alice ↔ Charlie (3 messages)
  - Group: Alice, Bob, Charlie (4 messages)

- **All with proper schema:**
  - All required Conversation entity fields
  - All required Message entity fields
  - All required User entity fields
  - Server timestamps for accurate testing

### Testing Real-Time Sync

1. Run seed script: `npm run seed`
2. Open Xcode → Run app (first simulator)
3. Sign in as `test1@messageai.dev`
4. Open second simulator
5. Sign in as `test2@messageai.dev`
6. Send messages between users
7. Watch real-time updates!

### Troubleshooting

**Error: Cannot find module 'firebase-admin'**
- Run `npm install` in scripts/ directory

**Error: Failed to load service account key**
- Download the key from Firebase Console (see Setup step 2)
- Ensure filename matches: `firebase-admin-key-dev.json`
- Place in project root (not in scripts/ folder)

**Script runs but no data appears in app**
- Verify you're looking at correct Firebase project in console
- Check app is running in DEBUG mode (uses DEV database)
- Look for console logs in Xcode showing conversation count

## Other Scripts

- `build.sh` - Build the iOS app with configurable options
- `quick-test.sh` - Run unit tests quickly with single simulator
- `ci-test.sh` - Run full test suite for CI/CD
- `start-emulator.sh` - Start Firebase Emulator for integration tests
- `run-integration-tests.sh` - Run integration tests against emulator

