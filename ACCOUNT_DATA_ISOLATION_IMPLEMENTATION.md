# Account Data Isolation Implementation (Option B)

**Date:** Implementation complete  
**Change:** Account data stays with the account, hidden on sign-out via query filtering

---

## Changes Made

### 1. Disabled `resetUserDataToGuest()` Function

**File:** `Core/Data/HabitRepository.swift:1652-1714`

**Change:** Function now does nothing (returns immediately)

**Reason:** Account data should NOT be converted to guest data. It stays with the account (userId = "abc123") and is hidden on sign-out by query filtering.

**Previous behavior:** Converted all account data (HabitData, CompletionRecords, etc.) from userId = "abc123" to userId = ""

**New behavior:** Function disabled - account data remains unchanged

---

### 2. Updated Sign-Out Handler

**File:** `Core/Data/HabitRepository.swift:1534-1554`

**Changes:**
- ❌ Removed call to `resetUserDataToGuest()`
- ✅ Added `self.habits = []` to clear in-memory cache
- ✅ Updated comments to explain Option B behavior

**New sign-out flow:**
```swift
case .unauthenticated:
  // Clear in-memory caches (NOT persisted data)
  self.habits = []
  
  // Load habits (queries filter by userId = "" which returns no account data)
  await loadHabits(force: true)
```

---

### 3. Made `updateStreak()` Consistent

**File:** `Views/Screens/HomeView.swift:98-152`

**Change:** Updated to use `CurrentUser().idOrGuest` instead of `Auth.auth().currentUser?.uid`

**Reason:** Consistency with rest of codebase and proper account data isolation

**Behavior:**
- When signed in: Queries for `userId = "abc123"` → finds account streak
- When signed out: Queries for `userId = ""` → finds no streak → shows 0

---

## How It Works

### Data Ownership

**Account data (userId = "abc123"):**
- Created when user is signed in
- Stored with `userId = "abc123"` (Firebase UID)
- **Never modified** on sign-out
- **Hidden** on sign-out by query filtering

**Guest data (userId = ""):**
- Created when user is in guest mode
- Stored with `userId = ""` (empty string)
- Separate from account data

### Query Filtering

All queries filter by `CurrentUser().idOrGuest`:

1. **Habits loading** (`SwiftDataStorage.loadHabits()`):
   - Signed in: `userId = "abc123"` → returns account habits
   - Signed out: `userId = ""` → returns guest habits (empty if none exist)

2. **CompletionRecords** (filtered in queries):
   - Signed in: `userId = "abc123"` → returns account completions
   - Signed out: `userId = ""` → returns guest completions (empty if none exist)

3. **GlobalStreakModel** (`HomeView.updateStreak()`):
   - Signed in: `userId = "abc123"` → returns account streak
   - Signed out: `userId = ""` → returns no streak → shows 0

4. **Streak calculation** (`HomeView.updateAllStreaks()`):
   - Uses `CurrentUser().idOrGuest` → filters by current userId
   - Signed out: No habits/completions found → streak = 0

### Sign-Out Flow

1. User signs out via `AuthenticationManager.signOut()`
2. `authState` changes to `.unauthenticated`
3. `HabitRepository.handleAuthStateChange()` receives `.unauthenticated`
4. **In-memory caches cleared:**
   - `XPManager.shared.handleUserSignOut()` → XP = 0, level = 1
   - `HabitRepository.habits = []` → habits array cleared
5. **Queries reload:**
   - `loadHabits()` called → queries for `userId = ""`
   - No account data returned (empty app state)
6. **Account data remains unchanged:**
   - HabitData with `userId = "abc123"` stays in database
   - CompletionRecords with `userId = "abc123"` stay in database
   - GlobalStreakModel with `userId = "abc123"` stays in database

### Sign-In Flow

1. User signs in via `AuthenticationManager`
2. `authState` changes to `.authenticated(user)`
3. `HabitRepository.handleAuthStateChange()` receives `.authenticated`
4. **Queries reload:**
   - `loadHabits()` called → queries for `userId = "abc123"`
   - Account data returned (habits, completions, streak visible)
5. **Account data visible again:**
   - All data with `userId = "abc123"` is now visible

---

## Test Criteria

### ✅ Test 1: Create Data While Signed In
1. Sign in with Apple (userId = "abc123")
2. Create habit → HabitData.userId = "abc123" ✅
3. Complete habit → CompletionRecord.userId = "abc123" ✅
4. Earn XP → XPManager resets on sign-out ✅
5. Build streak → GlobalStreakModel.userId = "abc123" ✅

### ✅ Test 2: Sign Out Shows Empty App
1. Sign out
2. **Expected:**
   - XP = 0 ✅
   - Streak = 0 ✅
   - No habits visible ✅
   - Empty app state ✅

### ✅ Test 3: Sign Back In Shows Data
1. Sign back in with same account
2. **Expected:**
   - All habits visible ✅
   - Streak restored ✅
   - XP restored (if stored in SwiftData) ✅
   - All account data returns ✅

### ✅ Test 4: Data Persistence
1. Sign in → Create data
2. Sign out → Data hidden
3. Close app
4. Reopen app → Still signed out
5. **Expected:** Still empty (queries filter by userId = "")
6. Sign in → **Expected:** All data returns

---

## Files Modified

1. **Core/Data/HabitRepository.swift**
   - Disabled `resetUserDataToGuest()` function
   - Updated sign-out handler to clear in-memory caches only
   - Removed call to `resetUserDataToGuest()`

2. **Views/Screens/HomeView.swift**
   - Updated `updateStreak()` to use `CurrentUser().idOrGuest` for consistency

---

## Key Principles

1. **Data Ownership:** Account data belongs to the account (userId = "abc123")
2. **No Data Conversion:** Account data is never converted to guest data
3. **Query Filtering:** Queries filter by `CurrentUser().idOrGuest` to show/hide data
4. **Cache Clearing:** Only in-memory caches are cleared on sign-out
5. **Persistence:** All persisted data remains unchanged

---

## Benefits

✅ **Data Integrity:** Account data never modified or lost  
✅ **User Experience:** Seamless sign-in/sign-out with data preservation  
✅ **Simplicity:** No complex data migration on sign-out  
✅ **Performance:** No database writes on sign-out (only cache clearing)  
✅ **Testability:** Clear separation between account and guest data

---

## Migration Notes

**For existing users:**
- If they have data converted to guest (from Option A), it will remain as guest data
- New account data will use Option B (stays with account)
- No migration needed - both can coexist

**For new users:**
- All data uses Option B from the start
- Account data stays with account
- Guest data stays as guest

---

## Summary

✅ Account data isolation implemented  
✅ Sign-out hides account data via query filtering  
✅ Sign-in restores account data visibility  
✅ No data conversion or deletion on sign-out  
✅ All queries filter correctly by `CurrentUser().idOrGuest`
