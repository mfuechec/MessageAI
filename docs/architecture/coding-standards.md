# Coding Standards

Critical rules for AI-assisted development. These standards are enforced through code reviews and will be referenced in `.cursor/rules/` files for dev agents.

## Swift Coding Standards

**Naming Conventions:**

- **Types** (classes, structs, enums, protocols): `PascalCase`
  - ✅ `MessageRepository`, `ChatViewModel`, `User`
  - ❌ `messageRepository`, `chatVM`

- **Functions and Variables**: `camelCase`
  - ✅ `sendMessage()`, `isOnline`, `conversationId`
  - ❌ `SendMessage()`, `IsOnline`

- **Constants**: `camelCase` (not SCREAMING_CASE)
  - ✅ `let maxParticipants = 10`
  - ❌ `let MAX_PARTICIPANTS = 10`

- **Protocols**: Suffix with `Protocol` when describing capability
  - ✅ `MessageRepositoryProtocol`, `AIServiceProtocol`
  - ❌ `IMessageRepository`, `MessageRepositoryInterface`

**Critical Rules:**

1. **Repository Abstraction is Mandatory**
   - ✅ ViewModels depend on `MessageRepositoryProtocol`
   - ❌ ViewModels directly import `FirebaseFirestore`
   - **Why:** Enables testing with mocks, maintains Clean Architecture

2. **No Firebase SDK in Domain Layer**
   - ✅ Domain uses pure Swift types (`Date`, `String`, `UUID`)
   - ❌ Domain imports `FirebaseFirestore` or uses `Timestamp`
   - **Why:** Domain must be framework-independent for testability

3. **Async/Await for Asynchronous Operations**
   - ✅ `async throws` functions, `await` keyword
   - ❌ Completion handler closures for new code
   - **Why:** Modern Swift concurrency is safer and more readable

4. **@MainActor for ViewModels**
   - ✅ `@MainActor class ChatViewModel: ObservableObject`
   - ❌ Manual `DispatchQueue.main.async` in ViewModels
   - **Why:** Ensures UI updates on main thread, prevents data races

5. **Optimistic UI Updates for Messaging**
   - ✅ Append message to array immediately, then save to Firebase
   - ❌ Wait for Firebase confirmation before showing message
   - **Why:** Responsive UX, handles offline gracefully

6. **Error Handling: Never Silent Failures**
   - ✅ `catch` block sets `@Published var errorMessage: String?`
   - ❌ Empty `catch {}` blocks
   - **Why:** Users need feedback when operations fail

7. **Dependency Injection via Initializer**
   - ✅ `init(messageRepository: MessageRepositoryProtocol)`
   - ❌ `let repo = FirebaseMessageRepository()` inside ViewModel
   - **Why:** Enables testing with mock dependencies

8. **Guard for Early Returns**
   - ✅ `guard let user = currentUser else { return }`
   - ❌ Nested `if let` pyramids
   - **Why:** Readability, reduces nesting

9. **SwiftLint Rules Enforced**
   - Line length: 120 characters max
   - Function length: 50 lines max (extract into helpers)
   - Cyclomatic complexity: Max 10
   - Force unwrapping (`!`) forbidden except test code

10. **Comments Only for "Why", Not "What"**
    - ✅ `// Optimistic UI: Show message immediately for responsive UX`
    - ❌ `// Set message text to the text parameter`
    - **Why:** Code should be self-documenting; comments explain intent

## Firestore Coding Standards

1. **Use Server Timestamps**
   - ✅ `"timestamp": FieldValue.serverTimestamp()`
   - ❌ `"timestamp": Date()` (client time)
   - **Why:** Prevents clock skew issues across devices

2. **Batch Writes for Multiple Operations**
   - ✅ Use `WriteBatch` for related updates
   - ❌ Sequential individual writes
   - **Why:** Atomic operations, better performance

3. **Query Limits to Prevent Excessive Reads**
   - ✅ `.limit(to: 50)` for message queries
   - ❌ Load entire conversation history at once
   - **Why:** Cost optimization, performance

4. **Security Rules Match Swiftcode Logic**
   - Firestore rules must mirror access control in Swift code
   - Test security rules with Firebase Emulator
   - **Why:** Defense in depth, never trust client

## Cloud Functions Coding Standards

1. **Validate Inputs Immediately**
   - Check `context.auth` exists
   - Validate all input parameters
   - Return structured error responses

2. **Idempotent Operations**
   - Functions should be safe to retry
   - Use transaction IDs to detect duplicates

3. **Timeouts and Error Handling**
   - Set timeout: 60 seconds max for AI functions
   - Catch all errors, never let functions crash
   - Log errors to Cloud Logging

4. **Cache Aggressively**
   - Check `ai_cache` collection before calling LLM
   - Set 24-hour expiration for cached results
   - **Why:** Cost optimization (LLM calls expensive)

---
