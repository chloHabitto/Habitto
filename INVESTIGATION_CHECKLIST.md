# 🔍 Investigation Checklist - Critical Issues

## Issue #1: Migration UI Showing at Wrong Time
**Problem**: Migration UI appears immediately when opening the app, but should only appear when signing up/logging in AFTER having guest data.

### Questions to Investigate:
1. **When is `shouldShowMigrationView` set to `true`?**
   - Check all places where `shouldShowMigrationView = true` is called
   - Check if it's set during app initialization (wrong)
   - Check if it's set when user authenticates (correct)

2. **What triggers `hasGuestData()` check?**
   - When does `GuestDataMigration.hasGuestData()` run?
   - Is it called on app launch? (might be too early)
   - Is it called when auth state changes? (should be here)

3. **Why does migration UI show for authenticated users?**
   - Check if `hasGuestData()` incorrectly detects data when user is already authenticated
   - Check if migration flag (`hasMigratedGuestData()`) is being reset incorrectly

### Files to Check:
- `Core/Data/HabitRepository.swift` - `handleUserChange()` method
- `Core/Data/Migration/GuestDataMigration.swift` - `hasGuestData()` method
- `App/HabittoApp.swift` - App initialization logic
- `Views/Screens/HomeView.swift` - Where migration UI sheet is displayed

---

## Issue #2: Account Persistence After Deletion
**Problem**: Deleted account "chlo_9609@naver.com" still appears even after deletion from Firebase Console.

### Questions to Investigate:
1. **How does Firebase Auth persist sessions?**
   - Check if Firebase Auth stores sessions in Keychain
   - Check if `AuthenticationManager.deleteAccount()` properly clears Keychain
   - Check if app is auto-restoring sessions on launch

2. **What happens during app initialization?**
   - Does `AppDelegate` auto-sign-in users?
   - Does `FirebaseConfiguration.ensureAuthenticated()` create anonymous sessions?
   - Is there session restoration logic that's too aggressive?

3. **Is account deletion actually deleting or just signing out?**
   - Check `AuthenticationManager.deleteAccount()` implementation
   - Does it call Firebase's `deleteUser()` API or just `signOut()`?
   - Check `AccountDeletionService` flow

### Files to Check:
- `Core/Managers/AuthenticationManager.swift` - `deleteAccount()` method
- `Core/Services/AccountDeletionService.swift` - Account deletion flow
- `App/HabittoApp.swift` - `FirebaseConfiguration.ensureAuthenticated()`
- `App/AppFirebase.swift` - Firebase initialization

---

## Issue #3: Habit Completion Not Persisting Reliably (CRITICAL)
**Problem**: Sometimes completion saves, sometimes it doesn't. Intermittent data loss.

### Questions to Investigate:
1. **When are CompletionRecords saved?**
   - Is `createCompletionRecordIfNeeded()` called synchronously or asynchronously?
   - Is `modelContext.save()` awaited or fire-and-forget?
   - Is there a race condition between save and app close?

2. **What happens when app closes before save completes?**
   - Does SwiftData autosave work correctly?
   - Is there a save delay that causes data loss?
   - Are saves queued or immediate?

3. **Why does completion persist on second try but not first?**
   - Is there a timing issue?
   - Does completion get saved during the second completion action?
   - Is there a reload happening that overwrites data?

4. **Are CompletionRecords filtered correctly on load?**
   - Check `HabitDataModel.toHabit()` - does it filter by correct userId?
   - Are CompletionRecords being created with correct userId?
   - Is there a userId mismatch causing records to be filtered out?

### Files to Check:
- `Core/Data/Repository/HabitStore.swift` - `createCompletionRecordIfNeeded()` method
- `Core/Data/SwiftData/HabitDataModel.swift` - `toHabit()` method (filtering logic)
- `Core/Data/HabitRepository.swift` - `toggleHabitCompletion()` method
- `App/HabittoApp.swift` - App lifecycle save handlers

### Specific Code Paths to Trace:
1. User completes habit → `toggleHabitCompletion()` → `createCompletionRecordIfNeeded()` → `modelContext.save()`
2. App closes → App lifecycle handlers → `saveHabits()` → Does this save CompletionRecords?
3. App reopens → `loadHabits()` → `HabitDataModel.toHabit()` → Filters CompletionRecords by userId

---

## Issue #4: Migration UI Not Showing When Signing Up
**Problem**: After creating guest data and signing up, migration UI doesn't appear.

### Questions to Investigate:
1. **Is `hasGuestData()` returning true when it should?**
   - After guest creates habit, does `hasGuestData()` detect it?
   - Is the check happening at the right time (after sign-up, not before)?
   - Is the userId filter causing guest data to be missed?

2. **Is `hasMigratedGuestData()` incorrectly returning true?**
   - Is migration flag being set prematurely?
   - Is it checking the wrong user ID?
   - Is the flag being cleared somewhere?

3. **Is migration happening silently before UI can show?**
   - Check if auto-migration runs before UI check
   - Is migration triggered on auth state change before UI logic?
   - Is the timing wrong (check happens after migration)?

### Files to Check:
- `Core/Data/HabitRepository.swift` - `handleUserChange()` method (migration order)
- `Core/Data/Migration/GuestDataMigration.swift` - `hasGuestData()` and `hasMigratedGuestData()`
- `Views/Screens/HomeView.swift` - Migration UI sheet binding

---

## Investigation Priority Order:

### 🔴 CRITICAL (Fix First):
1. **Issue #3: Habit Completion Not Persisting** - Data loss is unacceptable
2. **Issue #4: Migration UI Not Showing** - User loses data without knowing

### 🟡 HIGH PRIORITY:
3. **Issue #1: Migration UI Timing** - UX issue, annoying but not data loss
4. **Issue #2: Account Persistence** - Security/privacy concern

---

## Investigation Steps:

### Step 1: Add Debug Logging
Add comprehensive logging to track:
- When `shouldShowMigrationView` changes
- When `hasGuestData()` is called and what it returns
- When CompletionRecords are created/updated/saved
- When `modelContext.save()` is called and if it succeeds
- When habits are loaded and how many CompletionRecords are found

### Step 2: Trace Execution Flow
- Create a test scenario: Guest → Create habit → Complete → Sign up
- Add breakpoints/logs at each step
- Document the exact flow and timing

### Step 3: Check Data Persistence
- Verify CompletionRecords are actually in SwiftData after save
- Check if userId filtering is correct
- Verify no race conditions between save and load

### Step 4: Check Auth Flow
- Verify account deletion actually deletes, not just signs out
- Check if session restoration is happening
- Verify anonymous user handling

---

## Expected vs Actual Behavior:

### COMPLETION PERSISTENCE:
- **Expected**: Complete habit → Close app → Reopen → Habit still completed ✅
- **Actual**: Complete habit → Close app → Reopen → Habit incomplete ❌ (sometimes)

### MIGRATION UI:
- **Expected**: Guest mode → Create habit → Sign up → Migration UI appears ✅
- **Actual**: Guest mode → Create habit → Sign up → No migration UI ❌

### MIGRATION UI TIMING:
- **Expected**: Migration UI only appears when signing up after having guest data ✅
- **Actual**: Migration UI appears on app launch ❌

### ACCOUNT DELETION:
- **Expected**: Delete account → Close app → Reopen → No account shown ✅
- **Actual**: Delete account → Close app → Reopen → Old account still there ❌

