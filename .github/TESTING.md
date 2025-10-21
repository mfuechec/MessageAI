# Testing Guide

## Quick Start

**We use TIERED TESTING - run the right tests at the right time:**

```bash
# During development (5-20s)
./scripts/test-story.sh NewConversationViewModelTests

# Before story complete (20-40s)
./scripts/test-epic.sh 2

# Before commit (1-2min)
./scripts/quick-test.sh
```

**📚 See [Testing Strategy](../docs/architecture/testing-strategy.md) for complete guide.**

---

## Why This Script?

### Before (Traditional Approach)
- ❌ Spawns 2-4 simulator clones
- ❌ 60-90 seconds per test run
- ❌ High CPU/RAM usage
- ❌ Simulators constantly restarting

### After (quick-test.sh)
- ✅ Single simulator, stays running
- ✅ 5-10 seconds per test run
- ✅ Low resource usage
- ✅ Predictable, consistent results

---

## Common Commands

```bash
# During story development (FASTEST - 10s)
./scripts/test-story.sh NewConversationViewModelTests

# Before marking story complete (30s)
./scripts/test-epic.sh 2

# Before committing (90s)
./scripts/quick-test.sh

# With integration tests (needs emulator, 3min)
./scripts/quick-test.sh --with-integration
```

---

## For More Details

See [`docs/architecture/testing-best-practices.md`](../docs/architecture/testing-best-practices.md) for:
- Complete testing workflow
- Mock repository patterns
- Debugging tips
- CI/CD integration
- Common pitfalls to avoid

---

## Rules for Test Creation & Execution

**Test Creation Rules:**
1. ✅ **ONE test class per feature/ViewModel** for story-level testing
2. ✅ **Name tests clearly**: `NewConversationViewModelTests` (matches ViewModel name)
3. ✅ **Organize by layer**: Domain/Data/Presentation directories
4. ✅ **Use mocks for dependencies** (see [Mock Repository Pattern](../docs/architecture/testing-best-practices.md))
5. ✅ **Write tests FIRST** (TDD approach)

**Test Execution Rules:**
1. ✅ **USE TIERED TESTING**: story → epic → full (appropriate to context)
2. ✅ **NEVER** use direct `xcodebuild test` without scripts
3. ✅ **KEEP** simulator running between test runs
4. ✅ **TEST** before every commit (full suite with `quick-test.sh`)

These rules are enforced in:
- Dev agent configuration (`.bmad-core/agents/dev.md`)
- Testing strategy guide (`docs/architecture/testing-strategy.md`)
- Testing best practices guide (`docs/architecture/testing-best-practices.md`)

---

## Troubleshooting

**Tests won't run?**
```bash
# Boot simulator manually
open -a Simulator
./scripts/quick-test.sh -q
```

**Simulator stuck?**
```bash
# Restart simulator
xcrun simctl shutdown all
./scripts/quick-test.sh  # Will boot fresh
```

**Getting errors?**
```bash
# Clean build
./scripts/build.sh --action clean
./scripts/quick-test.sh  # Fresh build + test
```

---

**Questions?** Open an issue or check the comprehensive guide in `docs/architecture/testing-best-practices.md`.

