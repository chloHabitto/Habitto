# Error Handling Improvements Needed

**Last Updated:** January 2025  
**Status:** Documented for future work

## Overview

This document tracks places where errors are caught but not properly surfaced to users or telemetry. These are candidates for future improvement.

## Critical Issues

### 1. HabitRepository.saveHabits() - Line ~871

**Current behavior:** Save failures logged but not thrown
```swift
} catch {
  debugLog("❌ HabitRepository: Failed to save habits: \(error)")
}
```

**Risk:** Data loss without user awareness

**Future fix:** 
- Add Crashlytics error tracking
- Consider showing toast notification on save failure
- Re-throw error for UI to handle

---

### 2. HabitRepository.loadHabits() - Line ~795

**Current behavior:** Load failures return stale cached data
```swift
} catch {
  debugLog("❌ HabitRepository: Failed to load habits: \(error)")
  // Keep existing habits if loading fails
}
```

**Risk:** User sees outdated data without knowing

**Future fix:**
- Track in Crashlytics
- Show "offline mode" indicator if load fails

---

### 3. DataRepairUtility - Multiple lines

**Current behavior:** Uses `try?` for save operations
```swift
try? await habitStore.saveHabits(repairedHabits)
```

**Risk:** Repair operation completes but data not saved

**Future fix:**
- Use `do/catch` and log to Crashlytics
- Return success/failure from repair methods

---

### 4. DualWriteStorage.syncFromFirestore() - Line ~200

**Current behavior:** Returns empty array on sync failure
```swift
} catch {
  print("⚠️ SYNC_DOWN: Failed to sync from Firestore: \(error)")
  // Returns empty array
}
```

**Risk:** Cloud data silently unavailable

**Future fix:**
- Track sync failures in Crashlytics
- Show sync status indicator in UI

---

## Why Not Fix Now?

1. Changing error propagation could break existing UI flows
2. Some silent failures are intentional (offline graceful degradation)
3. Proper fixes require UI changes (error toasts, sync indicators)
4. Need to audit which errors are truly "swallowed" vs "handled silently"

## Recommended Approach

1. **Phase 1 (Now):** Add Crashlytics tracking for all swallowed errors
2. **Phase 2 (Future):** Add UI indicators for sync/save status
3. **Phase 3 (Future):** Refactor to use Result types where appropriate

## Tracking Checklist

- [x] Add Crashlytics to HabitRepository.saveHabits catch block
- [x] Add Crashlytics to HabitRepository.loadHabits catch block
- [ ] Add Crashlytics to DataRepairUtility save operations
- [ ] Add Crashlytics to DualWriteStorage sync failures
- [ ] Design sync status UI indicator
- [ ] Design save failure notification