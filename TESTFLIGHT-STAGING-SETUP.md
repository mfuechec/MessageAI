# Creating Staging Build Configuration for TestFlight

This guide shows how to create a separate "Staging" build configuration that uses Development Firebase but builds with Release optimizations.

## Step 1: Create Staging Configuration in Xcode

1. Open `MessageAI.xcodeproj` in Xcode
2. Select project (blue icon) → Info tab
3. Under **Configurations**, click **+** → "Duplicate Release Configuration"
4. Rename to **"Staging"**

## Step 2: Update Config.swift

Replace the `Environment.current` computed property:

```swift
static var current: Environment {
    #if STAGING
    return .development  // Use dev Firebase for TestFlight
    #elseif DEBUG
    return .development
    #else
    return .production
    #endif
}
```

## Step 3: Add STAGING Compiler Flag

1. Select MessageAI target → Build Settings
2. Search for "Swift Compiler - Custom Flags"
3. Under "Other Swift Flags", expand **Staging** row
4. Click **+** → Add: `-DSTAGING`

## Step 4: Create Staging Scheme

1. Xcode → Product → Scheme → Manage Schemes
2. Duplicate "MessageAI" scheme → Rename to "MessageAI (Staging)"
3. Edit scheme → Run → Build Configuration → Select **Staging**
4. Edit scheme → Archive → Build Configuration → Select **Staging**

## Step 5: Archive with Staging

Now you can:
- Use "MessageAI (Staging)" scheme for TestFlight builds
- Use "MessageAI" scheme for production App Store builds
- Development environment for both Debug and Staging
- Production environment only for Release

## Benefits

✅ Clear separation of environments
✅ No code changes needed between TestFlight and production
✅ Prevents accidental dev → production confusion
✅ Standard practice for professional iOS apps
