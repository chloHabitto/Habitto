# Sign-Out Data Isolation Analysis

**Date:** Generated from codebase investigation  
**Issue:** On sign-out, XP resets correctly, but streak stays at 1 and habits remain visible

---

## 1. Sign-Out Handler

### `AuthenticationManager.signOut()` - What it clears:

**Location:** `Core/Managers/AuthenticationManager.swift:163-195`

```swift
func signOut() {
  // 1. Firebase Auth sign-out
  try Auth.auth().signOut()
  authState = .unauthenticated
  currentUser = nil

  // 2. Keychain data
  KeychainManager.shared.clearAuthenticationData()

  // 3. XP data (WORKS CORRECTLY)
  XPManager.shared.handleUserSignOut()

  // 4. Migration flags
  UserDefaults.standard.removeObject(forKey: migrationKey)
}
```

**What is NOT being cleared:**
- ❌ **GlobalStreakModel** - Not reset or cleared on sign-out
- ❌ **HabitRepository.habits array** - Not explicitly cleared (relies on reload)
- ❌ **HabitRepository cache** - Not cleared before reload

**What singletons are notified:**
- ✅ `XPManager.shared.handleUserSignOut()` - Clears XP data
- ✅ `AuthRoutingManager` (via `$authState` publisher) - Switches to guest user
- ✅ `HabitRepository` (via `$authState` publisher) - Calls `resetUserDataToGuest()` and `loadHabits()`

---

## 2. Data Queries - userId Filtering

### a) Habits Loading

**Location:** `Core/Data/SwiftData/SwiftDataStorage.swift:384-403`

```swift
// Filter by current user ID if authenticated, otherwise show guest data
if let userId = currentUserId {
  descriptor.predicate = #Predicate<HabitData> { habitData in
    habitData.userId == userId
  }
} else {
  // For guest users, show data with empty userId
  descriptor.predicate = #Predicate<HabitData> { habitData in
    habitData.userId == ""
  }
}
```

**Status:** ✅ **CORRECT** - Queries filter by `userId == ""` for guests

**How it gets userId:**
- `getCurrentUserId()` returns `Auth.auth().currentUser?.uid` or `nil`
- When signed out, returns `nil`, so queries for `userId == ""`

**Issue:** The `habits` array in `HabitRepository` is not cleared before reload, so old habits might persist in memory.

---

### b) Streak Calculation

**Location:** `Views/Screens/HomeView.swift:401-465`

```swift
let userId = await CurrentUser().idOrGuest // Returns "" when signed out

// Get or create GlobalStreakModel
let streakDescriptor = FetchDescriptor<GlobalStreakModel>(
  predicate: #Predicate { streak in
    streak.userId == userId  // Queries for userId == ""
  }
)

// Fetch CompletionRecords
var completionDescriptor = FetchDescriptor<CompletionRecord>()
let allCompletionRecords = try modelContext.fetch(completionDescriptor)
let filteredCompletionRecords = allCompletionRecords.filter { record in
  guard record.isCompleted else { return false }
  if userId.isEmpty || userId == "guest" {
    return record.userId.isEmpty || record.userId == "guest" || record.userId == userId
  } else {
    return record.userId == userId
  }
}
```

**Status:** ⚠️ **PARTIALLY CORRECT** - Queries filter by userId, BUT:
- ❌ **GlobalStreakModel is NOT reset on sign-out** - Old user's streak remains in database
- ✅ CompletionRecords are filtered correctly

**Issue:** When user signs out:
1. Old user's `GlobalStreakModel` with their `userId` still exists
2. Query for `userId == ""` doesn't find it, so creates new one with `currentStreak = 0`
3. BUT if there's any cached value or if the old streak is somehow still being read, it shows the old value

---

### c) GlobalStreakModel Reading

**Location:** `Views/Screens/HomeView.swift:98-147`

```swift
func updateStreak() {
  let userId: String
  if let firebaseUser = Auth.auth().currentUser {
    userId = firebaseUser.uid
  } else {
    userId = "" // Guest mode
  }
  
  var descriptor = FetchDescriptor<GlobalStreakModel>(
    predicate: #Predicate { streak in
      streak.userId == userId
    }
  )
  
  let allStreaks = try modelContext.fetch(descriptor)
  if let streak = allStreaks.first {
    currentStreak = streak.currentStreak
  }
}
```

**Status:** ✅ **CORRECT** - Queries filter by `userId == ""` for guests

**Issue:** If no `GlobalStreakModel` exists for `userId == ""`, it doesn't create one here. It only creates one in `updateAllStreaks()`. So if `updateStreak()` is called before `updateAllStreaks()`, it might show a stale value.

---

### d) XPManager (Reference - Works Correctly)

**Location:** `Core/Managers/XPManager.swift:216-224`

```swift
func handleUserSignOut() {
  // Reset to default state
  userProgress = UserProgress()  // Resets to 0 XP, level 1
  recentTransactions.removeAll()
  
  // Save cleared data
  saveUserProgress()
  saveRecentTransactions()
}
```

**Status:** ✅ **WORKS CORRECTLY** - Explicitly resets to default state

**Why it works:**
- XPManager stores data in UserDefaults, not SwiftData
- `handleUserSignOut()` explicitly resets all values to defaults
- No database queries needed - just in-memory state reset

---

## 3. Current User Helper

### `CurrentUser().idOrGuest` - What it returns:

**Location:** `Core/Models/CurrentUser.swift:17-35`

```swift
var id: String {
  get async {
    await MainActor.run {
      if let firebaseUser = Auth.auth().currentUser {
        return firebaseUser.uid  // Returns Firebase UID when signed in
      }
      return Self.guestId  // Returns "" (empty string) when signed out
    }
  }
}

var idOrGuest: String {
  get async {
    await id  // Alias for id
  }
}
```

**Returns:**
- ✅ **When signed in:** `Auth.auth().currentUser?.uid` (Firebase UID string)
- ✅ **When signed out (guest):** `""` (empty string)

**Status:** ✅ **CORRECT** - Returns `""` for guests, which matches the guest ID used throughout the app

---

## 4. Gap Analysis Table

| Component | Clears on sign-out? | Filters by userId? | Status | Issue |
|-----------|-------------------|-------------------|--------|-------|
| **XPManager** | ✅ Yes (`handleUserSignOut()`) | N/A (in-memory only) | ✅ Works | None |
| **Habits (HabitData)** | ⚠️ Partial (`resetUserDataToGuest()` sets `userId = ""`) | ✅ Yes (`userId == ""` for guests) | ⚠️ **Issue:** `habits` array not cleared before reload | Old habits may persist in memory |
| **CompletionRecords** | ⚠️ Partial (`resetUserDataToGuest()` sets `userId = ""`) | ✅ Yes (filtered in queries) | ✅ Works | None |
| **GlobalStreakModel** | ❌ **NO** | ✅ Yes (`userId == ""` for guests) | ❌ **BROKEN:** Old user's streak not reset | Old streak remains in database |
| **DailyAwards** | ⚠️ Partial (`resetUserDataToGuest()` sets `userId = ""`) | ✅ Yes (filtered in queries) | ✅ Works | None |
| **UserProgressData** | ⚠️ Partial (`resetUserDataToGuest()` sets `userId = ""`) | ✅ Yes (filtered in queries) | ✅ Works | None |
| **HabitRepository.habits** | ❌ **NO** | N/A (loaded from SwiftData) | ❌ **BROKEN:** Array not cleared | Old habits visible until reload completes |

---

## 5. Root Causes

### Issue 1: Streak stays at 1

**Root Cause:** `GlobalStreakModel` is NOT reset or cleared on sign-out.

**What happens:**
1. User signs out
2. `resetUserDataToGuest()` resets HabitData, CompletionRecords, etc. to `userId = ""`
3. BUT `GlobalStreakModel` is NOT reset
4. Old user's `GlobalStreakModel` with their `userId` still exists in database
5. When `updateStreak()` queries for `userId == ""`, it doesn't find the old user's streak
6. BUT if `updateAllStreaks()` runs and finds old CompletionRecords (before they're reset), it might calculate a streak > 0
7. OR if there's a timing issue where the old streak is cached/read before the new one is created

**Fix needed:** Reset or delete `GlobalStreakModel` for the signed-out user in `resetUserDataToGuest()`.

---

### Issue 2: Habits still visible

**Root Cause:** `HabitRepository.habits` array is not cleared before reload.

**What happens:**
1. User signs out
2. `resetUserDataToGuest()` resets HabitData `userId = ""` in database
3. `loadHabits(force: true)` is called
4. BUT `habits` array is NOT cleared first
5. Old habits remain visible until the reload completes
6. If reload fails or is slow, old habits stay visible

**Fix needed:** Clear `habits = []` before calling `loadHabits()` in the sign-out handler.

---

## 6. Recommended Fix

### Minimal Change to Fix Both Issues:

**File:** `Core/Data/HabitRepository.swift`

**In `resetUserDataToGuest()` method (around line 1652):**

Add GlobalStreakModel reset:

```swift
// Reset GlobalStreakModel - reset all streaks that don't have userId = ""
let allStreaksDescriptor = FetchDescriptor<GlobalStreakModel>()
let allStreaks = (try? context.fetch(allStreaksDescriptor)) ?? []
let userStreaks = allStreaks.filter { !$0.userId.isEmpty && $0.userId != "guest" }

for streak in userStreaks {
  // Reset to default values (0 streak, no history)
  streak.currentStreak = 0
  streak.longestStreak = 0
  streak.totalCompleteDays = 0
  streak.streakHistory = []
  streak.lastCompleteDate = nil
  streak.userId = ""  // Reset to guest
}
debugLog("  ✓ Reset \(userStreaks.count) GlobalStreakModel records to userId = ''")
```

**In `handleAuthStateChange()` method (around line 1547):**

Clear habits array before reload:

```swift
case .unauthenticated:
  // ... existing code ...
  
  // ✅ FIX: Clear habits array BEFORE resetting data
  self.habits = []
  
  // ✅ CRITICAL FIX: Reset all user data to userId = "" when signing out
  await resetUserDataToGuest()
  
  // ✅ FIX: Load guest habits (array already cleared above)
  await loadHabits(force: true)
```

### Alternative: Delete instead of Reset

If you want to completely remove old user data instead of converting it to guest data:

```swift
// Delete GlobalStreakModel for signed-out user
let userStreaksDescriptor = FetchDescriptor<GlobalStreakModel>(
  predicate: #Predicate { streak in
    !streak.userId.isEmpty && streak.userId != "guest"
  }
)
let userStreaks = try context.fetch(userStreaksDescriptor)
for streak in userStreaks {
  context.delete(streak)
}
```

**Recommendation:** Use **reset** (set `userId = ""`) to preserve data for guest mode, unless you want to completely delete user data on sign-out.

---

## 7. Additional Considerations

### AuthRoutingManager Guest ID Mismatch

**Issue:** `AuthRoutingManager` uses `"guest_user"` as guest ID, but `CurrentUser` uses `""` (empty string).

**Location:** `Core/Managers/AuthRoutingManager.swift:145`

```swift
let guestUserId = "guest_user"  // ❌ Mismatch with CurrentUser.guestId = ""
```

**Impact:** This might cause issues if `AuthRoutingManager.currentUserId` is used anywhere instead of `CurrentUser().idOrGuest`.

**Recommendation:** Use `CurrentUser.guestId` consistently, or update `AuthRoutingManager` to use `""` instead of `"guest_user"`.

---

## 8. Testing Checklist

After implementing fixes, verify:

- [ ] Sign out → XP resets to 0 ✅ (already works)
- [ ] Sign out → Streak resets to 0 ✅ (should work after fix)
- [ ] Sign out → Habits disappear immediately ✅ (should work after fix)
- [ ] Sign out → Sign in → User sees their own data (not guest data)
- [ ] Sign out → Create new guest habits → They appear correctly
- [ ] Sign out → Sign in → Guest habits are preserved (if using reset, not delete)

---

## Summary

**Main Issues:**
1. ❌ `GlobalStreakModel` not reset on sign-out → Streak stays at old value
2. ❌ `HabitRepository.habits` array not cleared on sign-out → Old habits visible

**Minimal Fix:**
1. Add `GlobalStreakModel` reset in `resetUserDataToGuest()`
2. Clear `habits = []` before `loadHabits()` in sign-out handler

**Files to modify:**
- `Core/Data/HabitRepository.swift` (2 changes)
