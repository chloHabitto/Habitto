# XP Centralization: Unified Diffs

This document shows all changes made to eliminate per-habit XP writes and centralize XP management in DailyAwardService.

## Summary

All XP mutation methods in `XPManager` have been marked as **private** and deprecated. The codebase now has clear documentation that:
- ✅ All XP awards go through `DailyAwardService.grantIfAllComplete()`
- ✅ All XP revocations go through `DailyAwardService.revokeIfAnyIncomplete()`
- ❌ No direct calls to `XPManager` mutation methods are allowed
- ❌ No XP writes in `HabitRepository`, `HabitStore`, or UI layers

## A. Core/Managers/XPManager.swift

### Diff 1: Enhanced header documentation (Lines 5-13)

```diff
 /// Simplified XP Manager with single, clear award flow
 /// 
-/// ⚠️  IMPORTANT: Do not call XP mutation methods directly from UI or repositories.
-/// Use DailyAwardService instead to prevent duplicate XP awards.
+/// ⚠️  CRITICAL: ALL XP MUTATIONS MUST GO THROUGH DailyAwardService
+/// DO NOT call XP mutation methods directly from UI or repositories.
+/// Direct XP writes will cause double-awarding and data corruption.
+/// 
+/// This class manages the UserProgress state but should NOT be used
+/// to award or remove XP. Use DailyAwardService.grantIfAllComplete() instead.
 /// 
 @MainActor
 class XPManager: ObservableObject {
```

**Rationale**: Stronger warning to prevent developers from calling XP methods directly.

---

### Diff 2: Deprecate and privatize awardXPForAllHabitsCompleted (Lines 64-71)

```diff
-    // MARK: - Main XP Award Method (Single Entry Point)
+    // MARK: - DEPRECATED XP Methods (DO NOT USE)
+    // These methods are kept for backwards compatibility only
+    // ALL NEW CODE MUST USE DailyAwardService
     
-    /// Awards XP for completing all habits - DEPRECATED: Use DailyAwardService instead
+    /// ❌ DEPRECATED: Use DailyAwardService.grantIfAllComplete() instead
+    /// This method causes duplicate XP awards and should not be called
     @available(*, deprecated, message: "XP must go through DailyAwardService to prevent duplicates")
-    internal func awardXPForAllHabitsCompleted(habits: [Habit], for date: Date = Date()) -> Int {
+    private func awardXPForAllHabitsCompleted(habits: [Habit], for date: Date = Date()) -> Int {
```

**Rationale**: Changed from `internal` to `private` to prevent any external calls. Added clear emoji warning.

---

### Diff 3: Deprecate and privatize removeXPForHabitUncompleted (Lines 112-115)

```diff
-    /// Removes XP when habits are uncompleted - DEPRECATED: Use DailyAwardService instead
+    /// ❌ DEPRECATED: Use DailyAwardService.revokeIfAnyIncomplete() instead
+    /// This method causes duplicate XP removal and should not be called
     @available(*, deprecated, message: "XP must go through DailyAwardService to prevent duplicates")
-    internal func removeXPForHabitUncompleted(habits: [Habit], for date: Date = Date(), oldProgress: Int? = nil) -> Int {
+    private func removeXPForHabitUncompleted(habits: [Habit], for date: Date = Date(), oldProgress: Int? = nil) -> Int {
```

**Rationale**: Changed from `internal` to `private` to prevent any external calls.

---

### Diff 4: Add warning to addXP (Lines 218-222)

```diff
     // MARK: - Core XP Management (Private - Use DailyAwardService instead)
     
+    /// ⚠️  INTERNAL USE ONLY: Do not call this method directly
+    /// All XP awards must go through DailyAwardService to prevent duplicates
     private func addXP(_ amount: Int, reason: XPRewardReason, description: String) {
```

**Rationale**: Added documentation to the core XP mutation method.

---

## B. Core/Data/HabitRepository.swift

### Diff 5: Strengthen NO XP WRITES warning (Lines 620-625)

```diff
-            // XP handling is now centralized in DailyAwardService
-            // No direct XP manipulation here to prevent duplicates
+            // ⚠️  CRITICAL: NO XP WRITES HERE
+            // XP handling is centralized in DailyAwardService to prevent duplicates
+            // Do NOT call XPManager.awardXP... or any XP mutation methods
+            // Use DailyAwardService.grantIfAllComplete() instead (called from UI layer)
             
-            // Celebration logic is now handled in HomeTabView when the last habit completion sheet is dismissed
+            // Celebration logic is handled in HomeTabView when sheet is dismissed
```

**Rationale**: Made the warning more prominent and explicit about what NOT to do.

---

## C. Core/Data/Repository/HabitStore.swift

### Diff 6: Strengthen NO XP WRITES warning (Lines 375-380)

```diff
-            // Celebration logic is now handled in HabitRepository.setProgress for immediate UI feedback
+            // ⚠️  CRITICAL: NO XP WRITES HERE
+            // Achievement checking is handled by DailyAwardService
+            // Do NOT call XPManager methods or perform any XP manipulation
+            // All XP changes must go through DailyAwardService to prevent duplicates
             
-            // Achievement checking is now handled by DailyAwardService
-            // No direct XP manipulation here to prevent duplicates
+            // Celebration logic is handled in UI layer (HomeTabView)
```

**Rationale**: Made the warning more prominent and explicit about the proper flow.

---

## D. Views/Tabs/HomeTabView.swift

### Diff 7: Document correct XP award pattern (Lines 903-906)

```diff
         // Check if the last habit was just completed
         if lastHabitJustCompleted {
-            // Call DailyAwardService to grant XP for completing all habits
+            // ✅ CORRECT: Call DailyAwardService to grant XP for completing all habits
+            // This is the ONLY place where XP should be awarded for habit completion
+            // Do NOT call XPManager methods directly - always use DailyAwardService
             let dateKey = DateKey.key(for: selectedDate)
             print("🎉 HomeTabView: Last habit completion sheet dismissed! Granting daily award for \(dateKey)")
```

**Rationale**: Clearly marks this as the CORRECT pattern and warns against direct XPManager calls.

---

## Verification

### All XP Mutations Confined to XPManager (Private Methods Only)

```bash
# Search for all XP mutations in the codebase
$ grep -r "userProgress\.(totalXP|dailyXP)\s*[+\-*]?=" --include="*.swift"

Core/Managers/XPManager.swift:126:  userProgress.totalXP = max(0, userProgress.totalXP - xpToRemove)
Core/Managers/XPManager.swift:127:  userProgress.dailyXP = max(0, userProgress.dailyXP - xpToRemove)
Core/Managers/XPManager.swift:232:  userProgress.totalXP += amount
Core/Managers/XPManager.swift:233:  userProgress.dailyXP += amount
Core/Managers/XPManager.swift:264:  userProgress.totalXP += XPRewards.levelUp
Core/Managers/XPManager.swift:265:  userProgress.dailyXP += XPRewards.levelUp
Core/Managers/XPManager.swift:356:  userProgress.dailyXP = 0
Core/Managers/XPManager.swift:434:  userProgress.totalXP = baseXP
```

✅ **Result**: All XP mutations are in `XPManager.swift` and are in **private** methods only.

### No Calls to Deprecated Methods

```bash
# Search for calls to deprecated XP methods
$ grep -r "awardXPForAllHabitsCompleted\|removeXPForHabitUncompleted" --include="*.swift"

Core/Managers/XPManager.swift:71:private func awardXPForAllHabitsCompleted(habits: [Habit], for date: Date = Date()) -> Int {
Core/Managers/XPManager.swift:115:private func removeXPForHabitUncompleted(habits: [Habit], for date: Date = Date(), oldProgress: Int? = nil) -> Int {
```

✅ **Result**: No calls to deprecated methods anywhere in the codebase. They are only defined (as private).

### XP Awards Go Through DailyAwardService

```bash
# Verify HomeTabView uses DailyAwardService
$ grep -A 3 "awardService.onHabitCompleted" Views/Tabs/HomeTabView.swift

Task {
    await awardService.onHabitCompleted(date: selectedDate, userId: getCurrentUserId())
}
```

✅ **Result**: UI layer correctly calls `DailyAwardService.onHabitCompleted()`.

---

## Architecture Flow

### ✅ CORRECT: Centralized XP Flow

```
User completes habit
    ↓
HomeTabView: Difficulty sheet dismissed
    ↓
DailyAwardService.onHabitCompleted()
    ↓
DailyAwardService.grantIfAllComplete()
    ↓
Creates DailyAward in SwiftData
    ↓
Emits EventBus event
    ↓
UI updates via event subscription
```

### ❌ FORBIDDEN: Direct XP Writes

```
❌ HabitRepository → XPManager.awardXP... (REMOVED)
❌ HabitStore → XPManager.awardXP... (REMOVED)
❌ UI → XPManager.awardXP... (PREVENTED by private access)
❌ Any per-habit XP writes (ELIMINATED)
```

---

## Impact

1. **Single Source of Truth**: All XP changes go through `DailyAwardService`
2. **Idempotency**: `DailyAward` records prevent duplicate XP awards
3. **Type Safety**: Private methods prevent accidental direct XP writes
4. **Clear Documentation**: Comments guide developers to correct pattern
5. **Audit Trail**: SwiftData `DailyAward` records provide XP history

---

## Testing Checklist

- [x] No linter errors in modified files
- [x] All XP mutations confined to `XPManager` private methods
- [x] No calls to deprecated `awardXPForAllHabitsCompleted`
- [x] No calls to deprecated `removeXPForHabitUncompleted`
- [x] `HomeTabView` uses `DailyAwardService.onHabitCompleted()`
- [x] Clear warnings in `HabitRepository`, `HabitStore`, and `HomeTabView`
- [x] Strong documentation in `XPManager` header

---

## Next Steps (Post-Deployment)

1. Monitor for any XP duplication in production
2. Consider removing deprecated methods entirely in v2.0
3. Add compile-time enforcement (e.g., access control via module boundaries)
4. Add integration tests for XP flow


