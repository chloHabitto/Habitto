# Sign-Out Habits Not Hiding - Investigation & Fix

**Date:** Fixes implemented  
**Issue:** Habits still visible after sign-out (should show 0)

---

## Problem

**Current behavior:**
- Signed out: 4 habits visible ❌, streak 0 ✓, XP shows 50 but bar empty ⚠️
- Signed back in: 4 habits ✓, streak 1 ✓, XP 50 ✓

**Expected behavior:**
- Signed out: 0 habits, 0 streak, 0 XP (completely empty app)
- Signed back in: 4 habits, 1 streak, 50 XP

**Root cause:** Timing issue - `loadHabits()` might be called before `Auth.auth().currentUser` is fully cleared, causing query to use old userId.

---

## Fixes Implemented

### 1. Added Logging in Sign-Out Handler

**File:** `Core/Managers/AuthenticationManager.swift:163-195`

**Added:**
```swift
// ✅ DEBUG: Log userId after sign-out
Task {
  let userIdAfterSignOut = await CurrentUser().idOrGuest
  print("🔐 Sign-out: CurrentUser().idOrGuest = '\(userIdAfterSignOut.isEmpty ? "EMPTY" : userIdAfterSignOut)'")
  print("🔐 Sign-out: Auth.auth().currentUser = \(Auth.auth().currentUser?.uid ?? "nil")")
}
```

**Purpose:** Verify that `CurrentUser().idOrGuest` returns `""` after sign-out.

---

### 2. Added Delay Before Loading Habits

**File:** `Core/Data/HabitRepository.swift:1550-1559`

**Added:**
```swift
// ✅ CRITICAL: Small delay to ensure Auth.auth().currentUser is fully nil
// This prevents race condition where loadHabits() might see old userId
try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

// ✅ DEBUG: Verify userId after delay
let userIdAfterDelay = await CurrentUser().idOrGuest
debugLog("🔐 HabitRepository: CurrentUser().idOrGuest after delay = '\(userIdAfterDelay.isEmpty ? "EMPTY" : userIdAfterDelay)'")
debugLog("🔐 HabitRepository: Auth.auth().currentUser = \(Auth.auth().currentUser?.uid ?? "nil")")
```

**Purpose:** Ensure `Auth.auth().currentUser` is fully cleared before querying habits.

---

### 3. Enhanced Logging in Habit Loading

**File:** `Core/Data/SwiftData/SwiftDataStorage.swift:384-420`

**Added:**
```swift
// ✅ DEBUG: Log userId being used for query
let userIdForQuery = currentUserId ?? ""
logger.info("🔄 Loading habits for userId: '\(userIdForQuery.isEmpty ? "EMPTY (guest)" : userIdForQuery.prefix(8) + "...")'")
print("🔄 [HABIT_LOAD] Loading habits for userId: '\(userIdForQuery.isEmpty ? "EMPTY (guest)" : userIdForQuery.prefix(8) + "...")'")

// ✅ DEBUG: Log all habit userIds found (for debugging)
if !habitDataArray.isEmpty {
  let habitUserIds = Set(habitDataArray.map { $0.userId })
  logger.info("🔄 [HABIT_LOAD] Habit userIds in result: \(habitUserIds.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." })")
  print("🔄 [HABIT_LOAD] Habit userIds found: \(habitUserIds.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." })")
}
```

**Purpose:** Track exactly what userId is being used for the query and what habits are returned.

---

### 4. Enhanced Retry Logic Logging

**File:** `Core/Data/SwiftData/SwiftDataStorage.swift:362-382`

**Added:**
```swift
logger.info("⚠️ getCurrentUserId returned nil, but Auth.auth().currentUser exists - waiting for Firebase Auth...")
logger.info("   Auth.auth().currentUser.uid: \(Auth.auth().currentUser?.uid ?? "nil")")
// ... in retry loop ...
logger.info("⚠️ Retry \(attempt)/3: getCurrentUserId still nil, Auth.auth().currentUser = \(Auth.auth().currentUser?.uid ?? "nil")")
```

**Purpose:** Detect if retry logic is interfering with sign-out (shouldn't retry when signed out).

---

### 5. Enhanced Habit Update Logging

**File:** `Core/Data/HabitRepository.swift:699-718`

**Added:**
```swift
let currentUserId = await CurrentUser().idOrGuest
debugLog("🔄 LOAD_HABITS: About to update habits array")
debugLog("   Current userId: '\(currentUserId.isEmpty ? "EMPTY" : currentUserId.prefix(8) + "...")'")
debugLog("   Loaded habits count: \(uniqueHabits.count)")
print("🔄 [HABIT_UPDATE] Updating habits array: \(uniqueHabits.count) habits for userId '\(currentUserId.isEmpty ? "EMPTY" : currentUserId.prefix(8) + "...")'")
```

**Purpose:** Verify what userId is used when updating the habits array.

---

## Expected Log Flow

### When Sign-Out Completes:

```
🔐 AuthenticationManager: Starting sign out
✅ AuthenticationManager: Cleared sensitive data from Keychain
✅ AuthenticationManager: Cleared XP data
✅ AuthenticationManager: User signed out successfully
🔐 Sign-out: CurrentUser().idOrGuest = 'EMPTY'
🔐 Sign-out: Auth.auth().currentUser = nil

🔄 HabitRepository: User signed out
🔐 HabitRepository: CurrentUser().idOrGuest before clear = 'EMPTY'
✅ HabitRepository: Cleared in-memory habits array (count: 0)
🔐 HabitRepository: CurrentUser().idOrGuest after delay = 'EMPTY'
🔐 HabitRepository: Auth.auth().currentUser = nil
🔄 HabitRepository: User signed out, loading guest data...

🔄 [SWIFTDATA_QUERY] loadHabits() called - currentUserId: 'EMPTY_STRING'
🔄 Loading habits for userId: 'EMPTY (guest)'
🔄 Query predicate: userId == '' (empty string)
🔄 [HABIT_LOAD] Query result: Found 0 habits for userId 'EMPTY'
🔄 [HABIT_UPDATE] Updating habits array: 0 habits for userId 'EMPTY'
✅ HabitRepository: Guest data loaded for unauthenticated user (habits count: 0)
```

---

## Potential Issues to Check

### Issue 1: Retry Logic Interference

**If you see in logs:**
```
⚠️ getCurrentUserId returned nil, but Auth.auth().currentUser exists
   Auth.auth().currentUser.uid: u0mJUlZG...
```

**Problem:** Retry logic is seeing old user and retrying, causing query to use old userId.

**Fix:** The delay should prevent this, but if it persists, we may need to disable retries when authState is `.unauthenticated`.

---

### Issue 2: Query Not Filtering Correctly

**If you see in logs:**
```
🔄 Query predicate: userId == 'u0mJUlZG...'  // ❌ Wrong!
🔄 [HABIT_LOAD] Habit userIds found: ['u0mJUlZG...']  // ❌ Should be empty!
```

**Problem:** Query is using old userId instead of empty string.

**Fix:** The delay should ensure `getCurrentUserId()` returns `nil` before query runs.

---

### Issue 3: Habits Array Not Updating

**If you see in logs:**
```
🔄 [HABIT_LOAD] Query result: Found 0 habits  // ✅ Correct
🔄 [HABIT_UPDATE] Updating habits array: 0 habits  // ✅ Correct
🎯 [UI_STATE] HabitRepository after assignment: habits.count: 4 → 0  // ✅ Correct
```

But UI still shows 4 habits → **UI refresh issue**, not data issue.

---

## Testing

### Test Steps:
1. Sign in with Apple
2. Verify 4 habits visible
3. Sign out
4. **Check logs for:**
   - `CurrentUser().idOrGuest = 'EMPTY'`
   - `Query predicate: userId == ''`
   - `Found 0 habits`
   - `habits.count: 4 → 0`
5. **Verify UI:** Should show 0 habits

### If Still Not Working:

**Check logs for:**
1. What userId is used in query? (Should be `EMPTY`)
2. What habits are returned? (Should be 0)
3. What habits array count after update? (Should be 0)
4. Is retry logic interfering? (Should not retry when signed out)

---

## Summary

✅ **Added:** Comprehensive logging throughout sign-out and habit loading flow  
✅ **Added:** 0.1s delay before loading habits to prevent race condition  
✅ **Added:** Verification of userId at each step  
✅ **Enhanced:** Retry logic logging to detect interference

**Next step:** Test sign-out and check logs to identify where the issue occurs.
