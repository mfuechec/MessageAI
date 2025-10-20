# Development Workflow & Deployment

## Local Development Setup

**Prerequisites:**
```bash
# macOS requirements
- Xcode 15+ (includes Swift 5.9+)
- CocoaPods or Swift Package Manager (SPM preferred)
- Node.js 18+ (for Cloud Functions)
- Firebase CLI: npm install -g firebase-tools
```

**Initial Setup:**

```bash
# 1. Clone repository
git clone <repo-url>
cd MessageAI

# 2. Install Firebase CLI
npm install -g firebase-tools
firebase login

# 3. Initialize Firebase project
cd CloudFunctions
npm install

# 4. Configure Firebase (development environment)
firebase use --add  # Select development project

# 5. Open iOS project
open MessageAI.xcodeproj

# 6. Add GoogleService-Info.plist (download from Firebase Console)
# Place in MessageAI/ directory, add to Xcode project

# 7. Install dependencies via SPM (automatic in Xcode)
# Build project once to resolve dependencies
```

**Running Locally:**

```bash
# Start Firebase Emulators (optional, for Cloud Functions testing)
cd CloudFunctions
firebase emulators:start

# Run iOS app
# In Xcode: Cmd+R or Product > Run
# Select simulator or physical device
```

## Environment Configuration

**Development vs Production:**

```swift
// App/Config.swift
enum Environment {
    case development
    case production
    
    static var current: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    var firebaseConfig: String {
        switch self {
        case .development:
            return "GoogleService-Info-Dev"
        case .production:
            return "GoogleService-Info-Prod"
        }
    }
}
```

**Required Environment Variables (Cloud Functions):**

```bash
# CloudFunctions/.env.development
OPENAI_API_KEY=sk-...
FIREBASE_PROJECT_ID=messageai-dev
RATE_LIMIT_PER_USER=100

# CloudFunctions/.env.production
OPENAI_API_KEY=sk-...
FIREBASE_PROJECT_ID=messageai-prod
RATE_LIMIT_PER_USER=50
```

Set in Firebase:
```bash
firebase functions:config:set openai.api_key="sk-..." --project=messageai-dev
```

## Deployment Strategy

**iOS App Deployment:**

1. **TestFlight (Beta Testing):**
   ```bash
   # 1. Archive build in Xcode
   # Product > Archive
   
   # 2. Distribute to TestFlight
   # Organizer > Distribute App > App Store Connect > Upload
   
   # 3. Wait for processing (~15 minutes)
   
   # 4. Add external testers in App Store Connect
   ```

2. **App Store (Production):**
   - Same process as TestFlight
   - Submit for App Review
   - Expected review time: 24-48 hours

**Cloud Functions Deployment:**

```bash
# Deploy all functions (development)
cd CloudFunctions
firebase deploy --only functions --project=messageai-dev

# Deploy specific function
firebase deploy --only functions:summarizeThread --project=messageai-dev

# Deploy production
firebase deploy --only functions --project=messageai-prod
```

**Firestore Rules & Indexes Deployment:**

```bash
# Deploy security rules
firebase deploy --only firestore:rules --project=messageai-dev

# Deploy composite indexes
firebase deploy --only firestore:indexes --project=messageai-dev

# Deploy all Firebase backend
firebase deploy --except functions --project=messageai-dev
```

## CI/CD Pipeline (Future - Post-MVP)

```yaml
# .github/workflows/ios-ci.yml
name: iOS CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3
      
      - name: Select Xcode 15
        run: sudo xcode-select -s /Applications/Xcode_15.0.app
      
      - name: Build and Test
        run: |
          xcodebuild test \
            -project MessageAI.xcodeproj \
            -scheme MessageAI \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
            -enableCodeCoverage YES
      
      - name: Check Code Coverage
        run: |
          xcov --project MessageAI.xcodeproj \
               --scheme MessageAI \
               --minimum_coverage_percentage 70
```

## Monitoring & Observability

**Firebase Crashlytics:**
```swift
// Automatic crash reporting (configured in AppDelegate)
FirebaseApp.configure()
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
```

**Firebase Analytics:**
```swift
// Track AI feature usage
Analytics.logEvent("ai_summary_generated", parameters: [
    "conversation_id": conversationId,
    "message_count": messageCount
])

// Track message delivery time
Analytics.logEvent("message_delivered", parameters: [
    "delivery_time_ms": deliveryTime,
    "offline_queue": wasOffline
])
```

**Cloud Functions Monitoring:**
- View logs: `firebase functions:log --project=messageai-dev`
- Firebase Console: Functions > Logs tab
- Monitor costs: Firebase Console > Usage tab

## Performance Monitoring

**Key Metrics to Track:**

| Metric | Target | Tool |
|--------|---------|------|
| App Launch Time | < 1 second | Instruments (Time Profiler) |
| Message Send Time | < 2 seconds | Firebase Performance Monitoring |
| AI Summary Generation | < 10 seconds | Cloud Functions logs + Analytics |
| Conversation Load Time | < 1 second | Firebase Performance Monitoring |
| Firestore Read Count | Minimize | Firebase Console Usage |
| Firebase Costs | Stay within free tier (MVP) | Firebase Console Billing |

**Firebase Performance Monitoring:**
```swift
// Track custom traces
let trace = Performance.startTrace(name: "send_message")
// ... perform operation
trace?.stop()
```

---
