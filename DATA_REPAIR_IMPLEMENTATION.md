# Data Repair Implementation

**Date:** Implementation complete  
**Issues Fixed:**
1. Verified Apple Sign-In migration code
2. Added repair mechanism for existing affected users

---

## Issue 1: Verification ✅

### Method Signature Confirmed

**Location:** `Core/Data/Migration/GuestToAuthMigration.swift:28`

```swift
func migrateGuestDataIfNeeded(from guestUserId: String = "", to authUserId: String) async throws
```

✅ **Supports `from` parameter** - can migrate from any userId (not just empty string)

✅ **Migration logic handles both:**
- Empty string (`""`) for guest data
- Specific userId (e.g., `"5ExCpLQm..."`) for anonymous account data

### Apple Sign-In Migration Code

**Location:** `Core/Managers/AuthenticationManager.swift:365-370`

```swift
try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(
  from: anonymousUserId,  // ✅ Works with specific userId
  to: appleUserId
)
```

✅ **Code is correct** - will migrate from anonymous account to Apple account

---

## Issue 2: Repair Mechanism ✅

### New Service: DataRepairService

**File:** `Core/Services/DataRepairService.swift`

**Features:**
1. **Scan for orphaned data** - finds all data with userId != currentUserId
2. **Show summary** - counts habits, completions, awards, XP per orphaned userId
3. **Migrate all** - migrates all orphaned data to current account

**Key Methods:**
- `scanForOrphanedData()` - Returns `OrphanedDataSummary` with counts
- `migrateAllOrphanedData()` - Migrates all orphaned data to current user
- `migrateOrphanedData(from:to:)` - Migrates from specific userId

### UI Integration

**File:** `Views/Screens/AccountView.swift`

**Added:**
1. **Repair Data Section** - Shows in AccountView when signed in
2. **Scan Button** - Scans for orphaned data
3. **Confirmation Alert** - Shows summary and asks for confirmation
4. **Success/Error Alerts** - Shows migration results

**User Flow:**
1. User opens AccountView
2. Sees "Repair Data" section
3. Taps "Scan" button
4. Alert shows: "Found X habits and Y XP from previous session(s). Migrate to your account?"
5. User taps "Repair"
6. Data migrates automatically
7. Success alert shows results
8. Habits reload to show migrated data

---

## How It Works

### Scanning Process

1. **Get current userId** from `CurrentUser().idOrGuest`
2. **Fetch all data** from SwiftData:
   - HabitData
   - CompletionRecords
   - DailyAwards
   - GlobalStreakModel
   - UserProgressData
3. **Find unique userIds** that don't match current user
4. **Count data per userId**:
   - Habits count
   - Completions count
   - Awards count (with total XP)
   - Streaks count
   - Progress count
5. **Return summary** with all orphaned data

### Migration Process

1. **For each orphaned userId:**
   - Call `GuestToAuthMigration.migrateGuestDataIfNeeded(from:to:)`
   - Migrates all data types automatically
2. **Migration handles:**
   - HabitData
   - CompletionRecords
   - DailyAwards
   - UserProgressData
   - GlobalStreakModel
   - ProgressEvents
3. **Post-migration:**
   - Posts notification to refresh UI
   - Reloads habits to show migrated data

---

## Example Usage

### Scenario: User has orphaned data

**Before:**
- Current userId: `"u0mJUlZGShfONHjQbqp0xZ7vonm1"` (Apple account)
- Orphaned userId: `"5ExCpLQmBfU24jnLphpvvQvYLjq2"` (anonymous account)
- Orphaned data: 4 habits, 1 award (50 XP), multiple completions

**After Scan:**
```
Found 4 habits and 50 XP from 1 previous session.
Migrate this data to your account?
```

**After Repair:**
```
Migrated 4 habits and 50 XP from 1 previous session(s)
```

**Result:**
- All data now has userId = `"u0mJUlZGShfONHjQbqp0xZ7vonm1"`
- Queries return migrated data
- User sees all habits and XP

---

## Testing

### Test Case 1: No Orphaned Data
1. Open AccountView
2. Tap "Scan"
3. **Expected:** "No orphaned data found"

### Test Case 2: Orphaned Data Exists
1. Have data with userId = "5ExCpLQm..."
2. Sign in with Apple (userId = "u0mJUlZG...")
3. Open AccountView
4. Tap "Scan"
5. **Expected:** Shows summary with counts
6. Tap "Repair"
7. **Expected:** Success message, data visible

### Test Case 3: Multiple Orphaned Sessions
1. Have data from multiple old userIds
2. Scan
3. **Expected:** Shows total from all sessions
4. Repair
5. **Expected:** All data migrated

---

## Files Created/Modified

### New Files
1. **Core/Services/DataRepairService.swift** - Repair service

### Modified Files
1. **Views/Screens/AccountView.swift** - Added repair UI

### Verified Files
1. **Core/Data/Migration/GuestToAuthMigration.swift** - Method signature confirmed
2. **Core/Managers/AuthenticationManager.swift** - Migration code verified

---

## Summary

✅ **Issue 1 Fixed:** Verified `migrateGuestDataIfNeeded()` supports `from` parameter  
✅ **Issue 2 Fixed:** Added repair mechanism with UI in AccountView  
✅ **User-Friendly:** Simple scan → confirm → repair flow  
✅ **Comprehensive:** Handles all data types automatically  
✅ **Safe:** Shows summary before migrating, asks for confirmation

---

## Next Steps

1. **Test the repair flow** with your orphaned data
2. **Verify data appears** after repair
3. **Check logs** for migration details
4. **Future:** The Apple Sign-In migration will prevent this issue for new users
