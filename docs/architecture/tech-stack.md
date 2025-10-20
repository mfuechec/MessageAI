# Tech Stack

This is the DEFINITIVE technology selection for the entire project. All development must use these exact technologies and versions.

## Technology Stack Table

| Category | Technology | Version | Purpose | Rationale |
|----------|-----------|---------|---------|-----------|
| **iOS Language** | Swift | 5.9+ | Primary development language | Modern, type-safe, native iOS language. Protocol-oriented design fits Clean Architecture. Strong concurrency support (async/await). |
| **iOS Framework** | SwiftUI | iOS 15+ | Declarative UI framework | Native Apple framework with live preview, automatic dark mode, built-in accessibility. Natural MVVM fit with `@Published` bindings. |
| **Chat UI Library** | MessageKit | 4.2.0 | Professional chat UI components | Provides production-quality message bubbles, input bar, typing indicators, image messages. Saves 20-30% development time vs custom UI. |
| **Image Loading** | Kingfisher | 7.10.0 | Async image loading and caching | Battle-tested library for profile pictures and message attachments. Memory-efficient caching and placeholder support. |
| **State Management** | Combine + @Published | Native (iOS 15+) | Reactive state management | Native Apple framework. ViewModels use `@Published` for SwiftUI bindings. Observable pattern for real-time updates. |
| **Backend Platform** | Firebase | Latest (10.x) | Complete BaaS solution | Serverless backend with auth, real-time database, cloud functions, push notifications, and file storage in one ecosystem. |
| **Database** | Cloud Firestore | Firestore SDK | NoSQL real-time database | Real-time listeners with < 500ms latency for message delivery. Built-in offline persistence with query-level caching. Flexible document model for complex queries. |
| **Authentication** | Firebase Auth | Firebase SDK | User authentication | Email/password authentication with automatic token refresh. Seamless integration with Firestore security rules. |
| **Cloud Functions** | Firebase Cloud Functions | Node.js 18 | Serverless compute for AI | Protects API keys from client. Executes AI calls server-side. Automatic scaling and pay-per-execution pricing. |
| **Push Notifications** | Firebase Cloud Messaging | Firebase SDK + APNs | Push notification delivery | FCM handles device token management. Integrates with APNs for iOS delivery. Cloud Functions trigger notifications. |
| **File Storage** | Firebase Storage | Firebase SDK | Image attachment storage | Secure file uploads with size limits. Security rules restrict access. CDN-backed for fast delivery. |
| **AI Provider** | OpenAI GPT-4 | gpt-4-turbo | LLM for AI features | Function calling support for structured outputs. Strong performance on summarization and extraction tasks. (Alternative: Anthropic Claude 3) |
| **iOS Testing** | XCTest | Native (Xcode) | Unit and integration testing | Native Apple testing framework. Fast unit tests with mocked repositories. UI testing for critical flows. |
| **Cloud Functions Testing** | Jest | 29.x | Node.js unit testing | Industry standard for Node.js testing. Mock Firebase and AI APIs for isolated tests. |
| **E2E Testing** | XCTest UI Testing | Native (Xcode) | End-to-end user flows | Native iOS UI automation. Test critical flows: login, message send, AI features. |
| **Dependency Manager** | Swift Package Manager | Native (Xcode) | iOS dependency management | Native Apple tool. No additional build tools needed. Manages Firebase SDK, MessageKit, Kingfisher. |
| **Version Control** | Git | 2.x | Source control | Industry standard. Atomic commits for Cloud Functions + iOS app changes. |
| **CI/CD** | Manual + Xcode Cloud (Future) | N/A | Build and deployment | MVP: Manual TestFlight uploads. Future: Xcode Cloud for automated builds and tests. |
| **Monitoring** | Firebase Crashlytics | Firebase SDK | Crash reporting | Real-time crash reports with stack traces. User-impact metrics. Free tier sufficient for MVP. |
| **Analytics** | Firebase Analytics | Firebase SDK | Usage tracking | Track AI feature usage, message volume, user engagement. Helps optimize costs and features. |
| **Logging** | OSLog | Native (iOS) | iOS app logging | Native Apple logging framework. Unified logging system with log levels. Production logs excluded via build flags. |
| **API Security** | iOS Keychain | Native (iOS) | Secure credential storage | Store Firebase config and API keys securely. Never hardcode credentials in source. |

**Key Technology Decisions:**

1. **Swift 5.9+ over Objective-C**: Modern language with async/await concurrency, protocol-oriented design, and strong type safety. Essential for Clean Architecture implementation.

2. **SwiftUI over UIKit**: Declarative paradigm matches MVVM pattern naturally. Live previews accelerate UI development. Automatic dark mode and accessibility support.

3. **MessageKit**: Massive time-saver for chat UI. Production-quality components eliminate need to build message bubbles, input bars, typing indicators from scratch.

4. **Combine over third-party reactive frameworks (RxSwift)**: Native Apple framework with zero external dependencies. Sufficient for this app's reactive needs.

5. **Firestore over Realtime Database**: Real-time listeners provide < 500ms message delivery (well within < 2s requirement). Superior querying, structured collections, and query-level offline caching. Realtime Database's slightly lower latency (50-200ms vs 100-500ms) is imperceptible to users and doesn't justify sacrificing powerful queries and offline capabilities.

6. **OpenAI GPT-4 over Claude (Primary choice)**: Function calling provides structured outputs for action items and decisions. Alternative is Claude 3 if API access issues.

7. **Native testing over third-party frameworks**: XCTest provides everything needed. Quick/Nimble would add dependencies without significant value.

8. **Swift Package Manager over CocoaPods/Carthage**: Native tool integrated into Xcode. Modern, declarative dependency management.

9. **Manual CI/CD for MVP**: Automated pipelines would consume setup time. Manual TestFlight uploads acceptable for 7-day sprint. Xcode Cloud migration post-MVP.

10. **Firebase Crashlytics over Sentry**: Already using Firebase ecosystem. One less external service to integrate. Free tier covers MVP needs.

---
