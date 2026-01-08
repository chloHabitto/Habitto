# Habitto Logging Standards

**Last Updated:** January 2025  
**Status:** Migration in progress

## Overview

Habitto has a centralized logging utility (`HabittoLogger`) that should be used for all logging. Currently, most code uses `print()` or raw `os.Logger`, which creates inconsistency.

## Current State

| Pattern | Files | Target |
|---------|-------|--------|
| `print()` | ~155 | Migrate to HabittoLogger |
| `os.Logger` | ~58 | OK, but prefer HabittoLogger |
| `HabittoLogger` | 1 | Should be standard |

## Logging Guidelines

### Use HabittoLogger for:
- All new code
- Firestore operations → `HabittoLogger.logFirestoreWrite()`
- XP awards → `HabittoLogger.logXPAward()`
- Streak updates → `HabittoLogger.logStreakUpdate()`
- Errors → `HabittoLogger.logError()`
- Debug info → `HabittoLogger.logDebug()`

### Emoji Standards

| Emoji | Meaning | Example |
|-------|---------|---------|
| ✅ | Success/Complete | `✅ Data saved successfully` |
| ❌ | Error/Failure | `❌ Failed to load habits` |
| ⚠️ | Warning | `⚠️ Cache miss, loading from disk` |
| 🔍 | Investigation/Query | `🔍 Searching for habit...` |
| 🔄 | Sync/Retry/Update | `🔄 Syncing to cloud...` |
| 📝 | Info/Note | `📝 Creating new record` |
| 🎯 | Operation start | `🎯 Starting migration...` |
| 🚨 | Critical/Alert | `🚨 Database corruption detected` |
| 💰 | XP/Rewards | `💰 Awarded 50 XP` |
| 🔥 | Streak | `🔥 Streak updated to 5` |

### Production Logging Rules

1. **Guard verbose logs** with `#if DEBUG`:
```swift
   #if DEBUG
   print("🔍 Detailed debug info: \(data)")
   #endif
```

2. **Never log sensitive data** in production:
   - No user IDs in full
   - No email addresses
   - No authentication tokens

3. **Use appropriate log levels**:
   - `debug` - Development only
   - `info` - Normal operations
   - `warning` - Unexpected but handled
   - `error` - Failures needing attention

## Migration Priority

### High Priority (has production impact):
- [ ] `SubscriptionManager.swift` - 330+ print() statements
- [ ] `HabitStore.swift` - mixed patterns
- [ ] `SwiftDataStorage.swift` - mixed patterns

### Medium Priority:
- [ ] `HabittoApp.swift` - mixed patterns
- [ ] `CrashlyticsService.swift` - uses print()
- [ ] `AuthenticationManager.swift`

### Low Priority:
- [ ] Other files using print()

## How to Migrate a File

1. Import: No import needed (same module)
2. Replace `print("✅ ...")` with `HabittoLogger.logDebug("...", metadata: [...])`
3. Replace error logging with `HabittoLogger.logError("...", error: error)`
4. Add `#if DEBUG` guards for verbose logs
5. Test in both DEBUG and RELEASE builds

## Example Migration

Before:
```swift
print("✅ Subscription purchased: \(productID)")
print("❌ Purchase failed: \(error)")
```

After:
```swift
HabittoLogger.logDebug("Subscription purchased", metadata: ["productID": productID])
HabittoLogger.logError("Purchase failed", error: error)
```
