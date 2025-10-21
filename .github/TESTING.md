# Testing Guide

## Quick Start

Run tests the fast way:

```bash
./scripts/quick-test.sh --quick
```

**That's it!** This is 10x faster than traditional testing.

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
# Daily development (fast!)
./scripts/quick-test.sh -q

# First time or after code changes
./scripts/quick-test.sh

# Run specific test suite
./scripts/quick-test.sh -q --test ConversationsListViewModelTests

# See all options
./scripts/quick-test.sh --help
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

## Rules for Future Development

1. ✅ **ALWAYS** use `quick-test.sh` for terminal testing
2. ✅ **NEVER** use direct `xcodebuild test` without parallel testing flags
3. ✅ **KEEP** simulator running between test runs
4. ✅ **TEST** before every commit

These rules are enforced in:
- Dev agent configuration (`.bmad-core/agents/dev.md`)
- README.md testing section
- Testing best practices guide

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

