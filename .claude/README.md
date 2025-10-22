# Claude Code Configuration

This directory contains Claude Code configuration for enforcing Clean Architecture and coding standards in the MessageAI project.

## 📁 What's Here

### `settings.json`
Project-wide configuration tracked in git:
- **Tool permissions**: What Claude can read/write/execute
- **Environment variables**: Project context for all sessions
- **Hooks**: Automated validation scripts

### `settings.local.json` (gitignored)
Personal preferences not committed to git. Create this file to override settings for your local environment.

### `hooks/validate-swift.sh`
Pre-write/edit validation script that runs automatically before Swift code changes.

**What it checks:**
1. ✅ **SwiftLint** - Comprehensive style and quality checks
2. ✅ **Clean Architecture boundaries** - Blocks Firebase in Domain layer
3. ✅ **Repository abstraction** - Enforces protocol usage
4. ✅ **Layer organization** - Files must be in correct directories
5. ✅ **Modern Swift patterns** - Warns about completion handlers vs async/await

**Exit codes:**
- `0` = Pass (operation allowed)
- `1` = Warning (operation allowed with message)
- `2` = Block (operation prevented with error)

## 🎯 How It Works

When Claude Code writes or edits Swift files:

1. **Permission check** - `settings.json` verifies Claude has access to the file
2. **Hook validation** - `validate-swift.sh` runs automatically
3. **SwiftLint check** - Runs first, warns if style issues found
4. **Architecture check** - Blocks if Clean Architecture rules violated
5. **Write/Edit** - Only proceeds if all checks pass or warnings only

## 🚫 What Gets Blocked

The hooks will **prevent** these operations:

```swift
// ❌ BLOCKED: Firebase in Domain layer
// File: MessageAI/Domain/Entities/Message.swift
import FirebaseFirestore  // Hook blocks this

// ❌ BLOCKED: Direct Firestore in Presentation
// File: MessageAI/Presentation/ViewModels/ChatViewModel.swift
let db = Firestore.firestore()  // Hook blocks this

// ❌ BLOCKED: Repository in wrong layer
// File: MessageAI/Presentation/Repositories/MessageRepositoryProtocol.swift
protocol MessageRepositoryProtocol { }  // Must be in Domain/Repositories/
```

## ⚠️ What Gets Warned

The hooks will **allow but warn** about these:

```swift
// ⚠️ WARNING: Missing @MainActor
class ChatViewModel: ObservableObject {  // Should have @MainActor
    @Published var messages: [Message] = []
}

// ⚠️ WARNING: Use async/await
func sendMessage(completion: @escaping (Result<Void, Error>) -> Void) {
    // Modern Swift uses async throws instead
}

// ⚠️ WARNING: High force unwrap count
let user = currentUser!  // Discouraged in production code
```

## 📝 SwiftLint Integration

SwiftLint 0.61.0 is integrated via `.swiftlint.yml` in project root.

**Configured rules:**
- Line length: 120 chars
- Function length: 50 lines
- Cyclomatic complexity: 10
- Force unwrapping: Error
- Force cast: Error
- Custom rules for Firebase/UIKit in Domain layer

**Run manually:**
```bash
# Lint entire project
swiftlint

# Lint specific file
swiftlint lint MessageAI/Domain/Entities/User.swift

# Auto-fix violations
swiftlint --fix
```

## 🔧 Customization

### Personal Settings Override

Create `.claude/settings.local.json` (gitignored) to override settings:

```json
{
  "environmentVariables": {
    "MY_CUSTOM_VAR": "value"
  }
}
```

### Disable Hooks Temporarily

Set environment variable before running Claude Code:
```bash
export CLAUDE_SKIP_HOOKS=1
```

### Modify Hook Behavior

Edit `hooks/validate-swift.sh` to:
- Add new validation rules
- Change severity (warning vs error)
- Disable specific checks

## 📚 Related Files

- **Project root**:
  - `CLAUDE.md` - Main guidance document with all coding standards
  - `.swiftlint.yml` - SwiftLint configuration
  - `.gitignore` - Tracks shared settings, ignores personal preferences

## 🔄 CI/CD Integration

To enforce these rules in CI/CD:

```yaml
# Example GitHub Actions workflow
- name: Run SwiftLint
  run: swiftlint lint --strict

- name: Run Architecture Validation
  run: |
    for file in $(find MessageAI -name "*.swift"); do
      ./.claude/hooks/validate-swift.sh "$file" "$(cat $file)"
    done
```

## 🐛 Troubleshooting

**Hook not running?**
- Check file is executable: `chmod +x .claude/hooks/validate-swift.sh`
- Verify hook is configured in `.claude/settings.json`

**SwiftLint not found?**
```bash
brew install swiftlint
```

**Hook blocking valid code?**
- Review error message for fix instructions
- Temporarily disable hook if needed
- Report issue if hook logic is incorrect

**Permission denied errors?**
- Check `toolPermissions` in `.claude/settings.json`
- Verify file path matches allow/deny patterns

## 📖 Documentation

Full coding standards available in:
- `CLAUDE.md` (project root)
- `.cursor/rules/` (original Cursor rules)
- `docs/architecture/` (detailed architecture docs)

## 🤝 Contributing

When modifying configuration:
1. Update `settings.json` for team-wide changes
2. Test hooks thoroughly before committing
3. Document changes in this README
4. Update `CLAUDE.md` if standards change
