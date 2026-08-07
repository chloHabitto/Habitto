# DailyAward Integrity Investigation & Fix

## Problem Summary

There was a discrepancy between:
- **DailyAwardService**: Showing 11 awards totaling 550 XP
- **XP calculation from habits**: Only finding 4 days where all habits were completed (200 XP)

This indicates that some DailyAward records were created when NOT all scheduled habits were completed for that date.

## Root Cause

DailyAwards can become invalid in several ways:
1. **Firestore sync**: Awards imported from Firestore (`mergeAwardFromFirestore`) without validation
2. **Legacy data**: Old awards created before validation logic was in place
3. **Race conditions**: Awards created before completion records were fully saved
4. **Data migration**: Awards migrated from old systems without proper validation

## Solution

### 1. Investigation Service (`DailyAwardIntegrityService`)

Created a service to investigate and validate all DailyAward records:

**Location**: `Core/Services/DailyAwardIntegrityService.swift`

**Features**:
- Validates each DailyAward against actual completion data
- Checks that ALL scheduled habits were completed on the award date
- Identifies invalid awards with detailed reasons
- Provides statistics (total awards, valid/invalid counts, XP breakdown)

**Usage**:
```swift
let userId = await CurrentUser().idOrGuest
let result = try await DailyAwardIntegrityService.shared.investigateDailyAwards(userId: userId)

// Print detailed report
DailyAwardIntegrityService.shared.printInvestigationReport(result)
```

### 2. Cleanup Service

The same service can remove invalid awards and recalculate XP:

**Usage**:
```swift
let userId = await CurrentUser().idOrGuest
let removedCount = try await DailyAwardIntegrityService.shared.cleanupInvalidAwards(userId: userId)
```

**What it does**:
1. Investigates all awards
2. Deletes invalid awards
3. Recalculates total XP from remaining valid awards
4. Updates UserProgressData

### 3. Debug View

Created a UI for easy investigation and cleanup:

**Location**: `Views/Debug/DailyAwardIntegrityView.swift`

**Access**: Add to your debug/settings menu (similar to other debug views)

**Features**:
- Run investigation with one tap
- View detailed results (valid/invalid awards, XP breakdown)
- See list of invalid awards with reasons
- Remove invalid awards with confirmation dialog

### 4. Prevention

Added validation to `mergeAwardFromFirestore` in `SyncEngine.swift`:

- Validates imported awards after import (non-blocking)
- Logs warnings when invalid awards are detected
- Doesn't block sync (to maintain cross-device consistency)
- Allows cleanup service to remove invalid awards later

## How to Use

### Option 1: Via Debug View (Recommended)

1. Add `DailyAwardIntegrityView` to your debug/settings menu
2. Navigate to "Daily Award Integrity"
3. Tap "Investigate DailyAwards"
4. Review the results
5. If invalid awards are found, tap "Remove Invalid Awards"
6. Confirm the cleanup

### Option 2: Via Code

```swift
// Investigate
let userId = await CurrentUser().idOrGuest
let result = try await DailyAwardIntegrityService.shared.investigateDailyAwards(userId: userId)

// Print report to console
DailyAwardIntegrityService.shared.printInvestigationReport(result)

// Cleanup if needed
if !result.invalidAwards.isEmpty {
    let removedCount = try await DailyAwardIntegrityService.shared.cleanupInvalidAwards(userId: userId)
    print("Removed \(removedCount) invalid awards")
}
```

### Option 3: Via Console Logs

The investigation automatically prints detailed logs to the console, including:
- Total awards found
- Valid vs invalid counts
- XP breakdown
- Details of each invalid award (date, reason, missing habits)

## Validation Logic

An award is considered **valid** if:
1. The dateKey is in valid format (yyyy-MM-dd)
2. At least one habit was scheduled for that date
3. **ALL** scheduled habits for that date were completed (have CompletionRecord with `isCompleted == true`)

An award is considered **invalid** if:
1. Invalid dateKey format
2. No habits were scheduled for that date
3. Not all scheduled habits were completed

## Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 DAILY AWARD INTEGRITY INVESTIGATION REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Awards: 11
Valid Awards: 4
Invalid Awards: 7

Total XP from Awards: 550
Valid XP: 200
Invalid XP: 350

❌ INVALID AWARDS:

  1. Date: 2025-11-22
     XP: 50
     Reason: Not all scheduled habits were completed
     Scheduled Habits: 3
     Completed Habits: 2
     Missing: Morning Exercise

  2. Date: 2025-11-23
     XP: 50
     Reason: Not all scheduled habits were completed
     Scheduled Habits: 3
     Completed Habits: 1
     Missing: Morning Exercise, Evening Reading

...
```

## Next Steps

1. **Run investigation** to see current state
2. **Review invalid awards** to understand why they were created
3. **Clean up invalid awards** to fix XP discrepancy
4. **Monitor logs** for warnings about invalid awards being imported

## Prevention

The validation added to `mergeAwardFromFirestore` will:
- Log warnings when invalid awards are imported
- Help identify data integrity issues early
- Allow proactive cleanup using the integrity service

## Notes

- The cleanup is **safe** - it only removes awards that don't match actual completion data
- XP is automatically recalculated after cleanup
- The investigation is **read-only** - it doesn't modify data
- Cleanup requires explicit confirmation to prevent accidental deletion

