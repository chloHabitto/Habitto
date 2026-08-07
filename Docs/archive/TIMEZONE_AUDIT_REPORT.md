# Comprehensive Timezone Audit Report

## Executive Summary

**CRITICAL FINDING**: The codebase has **inconsistent timezone handling** for date key generation:
- ✅ **DateUtils.dateKey()** uses `TimeZone.current` (CORRECT - used by main app)
- ❌ **DateKey.key()** uses hardcoded `"Europe/Amsterdam"` (INCONSISTENT)
- ❌ **LocalDateFormatter** defaults to `"Europe/Amsterdam"` (INCONSISTENT)
- ✅ **Widget** now uses `TimeZone.current` (FIXED)

**Impact**: Users outside Amsterdam timezone will experience date key mismatches, causing:
- Widget showing wrong completion status
- XP awards calculated for wrong dates
- Streak calculations off by one day

---

## Phase 1: Audit Results

### All Date Key Generation Locations

| File | Function/Method | Timezone Used | Format | Status | Used For |
|------|----------------|---------------|--------|--------|----------|
| **Core/Utils/DateUtils.swift** | `dateKey(for:)` | `TimeZone.current` | `yyyy-MM-dd` | ✅ **CORRECT** | Main app completion data |
| **Core/Utils/Archive/DateKey.swift** | `key(for:)` | `"Europe/Amsterdam"` (hardcoded) | `yyyy-MM-dd` | ❌ **INCONSISTENT** | XPManager, HabitComputed |
| **Core/Time/LocalDateFormatter.swift** | `dateToString()` | `"Europe/Amsterdam"` (default) | `yyyy-MM-dd` | ❌ **INCONSISTENT** | FirestoreRepository, Services |
| **HabittoWidget/MonthlyProgressWidget.swift** | `formatDateKey(for:)` (2x) | `TimeZone.current` | `yyyy-MM-dd` | ✅ **FIXED** | Widget date keys |
| **Core/Models/FirestoreModels.swift** | `dateKey(for:)` | `"Europe/Amsterdam"` | `yyyy-MM-dd` | ❌ **INCONSISTENT** | Firestore date keys |
| **Core/Data/Migration/XPMigrationService.swift** | Multiple | `"Europe/Amsterdam"` | `yyyy-MM-dd` | ❌ **INCONSISTENT** | Migration scripts |
| **Core/Data/Migration/GuestToAuthMigration.swift** | Migration | `"Europe/Amsterdam"` | `yyyy-MM-dd` | ❌ **INCONSISTENT** | Guest migration |
| **Core/Services/FirestoreService.swift** | Multiple | `"Europe/Amsterdam"` | `yyyy-MM-dd` | ❌ **INCONSISTENT** | Firestore operations |

### Hardcoded "Europe/Amsterdam" References

Found **37 instances** of hardcoded `"Europe/Amsterdam"` timezone:
- `Core/Utils/Archive/DateKey.swift` - Main date key utility (USED)
- `Core/Time/LocalDateFormatter.swift` - Date formatter (USED)
- `Core/Models/FirestoreModels.swift` - Firestore date keys
- `Core/Services/FirestoreService.swift` - Firestore operations
- `Core/Data/Migration/*.swift` - Migration scripts
- `Views/Tabs/ProgressTabView.swift` - UI date formatting
- Test files and documentation

### Usage Analysis

**DateKey.key() is used in:**
- `Core/Managers/XPManager.swift` (2 places)
- `Core/Models/HabitComputed.swift` (2 places)
- `Core/Services/MigrationRunner.swift` (1 place)
- `Views/Tabs/HomeTabView.swift` (2 places)

**LocalDateFormatter is used in:**
- `Core/Data/Firestore/FirestoreRepository.swift`
- `Core/Services/DailyAwardService.swift`
- `Core/Services/CompletionService.swift`
- `Core/Services/GoalMigrationService.swift`
- `Core/Services/GoalVersioningService.swift`
- `Core/Services/GoldenTestRunner.swift`

---

## Phase 2: Inconsistency Analysis

### Critical Inconsistencies

| Issue | Location | Impact | Priority |
|-------|----------|--------|----------|
| **DateKey uses Amsterdam** | `Core/Utils/Archive/DateKey.swift` | XP calculations, HabitComputed use wrong timezone | 🔴 **HIGH** |
| **LocalDateFormatter defaults to Amsterdam** | `Core/Time/LocalDateFormatter.swift` | Services use wrong timezone | 🔴 **HIGH** |
| **FirestoreModels uses Amsterdam** | `Core/Models/FirestoreModels.swift` | Firestore sync uses wrong timezone | 🟡 **MEDIUM** |
| **Migration scripts use Amsterdam** | `Core/Data/Migration/*.swift` | Historical data migration | 🟢 **LOW** (one-time) |
| **FirestoreService uses Amsterdam** | `Core/Services/FirestoreService.swift` | Firestore operations | 🟡 **MEDIUM** |

### Consistency Matrix

| Component | DateUtils | DateKey | LocalDateFormatter | Widget | Status |
|-----------|-----------|---------|-------------------|--------|--------|
| **Main App** | ✅ Uses | ❌ Uses | ❌ Uses | N/A | ⚠️ **MIXED** |
| **Widget** | ❌ Can't import | N/A | ❌ Can't import | ✅ Uses | ✅ **FIXED** |
| **Services** | ❌ Doesn't use | ❌ Uses | ✅ Uses | N/A | ⚠️ **MIXED** |
| **Firestore** | ❌ Doesn't use | ❌ Uses | ✅ Uses | N/A | ⚠️ **MIXED** |

---

## Phase 3: Consolidation Strategy

### Recommendation: **Option A - Migrate to DateUtils.dateKey()**

**Rationale:**
1. `DateUtils.dateKey()` is already used by the main app for completion data
2. It uses `TimeZone.current` (correct for user's device)
3. Widget already fixed to use `TimeZone.current`
4. Consolidating to one utility reduces maintenance burden

### Migration Plan

#### Step 1: Update DateKey.swift
- Change from `"Europe/Amsterdam"` to `TimeZone.current`
- Add deprecation warning pointing to DateUtils
- Keep for backward compatibility during migration

#### Step 2: Update LocalDateFormatter.swift
- Change default from `AmsterdamTimeZoneProvider` to `SystemTimeZoneProvider`
- Update all services to use `TimeZone.current`

#### Step 3: Create Shared DateKeyUtils
- Create `Shared/DateKeyUtils.swift` for widget compatibility
- Both app and widget can import from Shared target
- Remove duplicate `formatDateKey()` from widget

#### Step 4: Update Firestore Operations
- Migrate Firestore date key generation to use `TimeZone.current`
- Ensure backward compatibility with existing data

---

## Phase 4: Widget-Specific Fix

### Current Problem
- Widget cannot import `DateUtils` from main app target
- Widget has duplicate `formatDateKey()` functions
- Risk of future timezone mismatches

### Solution: Shared DateKeyUtils

**File Structure:**
```
Shared/
  └── DateKeyUtils.swift  (Added to BOTH targets)
```

**Implementation:**
```swift
// Shared/DateKeyUtils.swift
import Foundation

/// Shared date key utility for app and widget
/// ⚠️ CRITICAL: Must use TimeZone.current to match app's DateUtils.dateKey()
/// Changing this will cause date key mismatches between app and widget
public struct DateKeyUtils {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current  // ✅ MUST match DateUtils
        return formatter
    }()
    
    /// Generate date key in format "yyyy-MM-dd" using local timezone
    public static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    /// Parse date key back to Date
    public static func date(from dateKey: String) -> Date? {
        dateFormatter.date(from: dateKey)
    }
}
```

**Update Widget:**
- Remove both `formatDateKey()` functions
- Replace with `DateKeyUtils.dateKey(for:)`

---

## Phase 5: Safeguards

### 1. Documentation Block

Add to `Shared/DateKeyUtils.swift`:
```swift
// MARK: - CRITICAL TIMEZONE WARNING
//
// ⚠️ DO NOT CHANGE THE TIMEZONE IN THIS FILE ⚠️
//
// This utility MUST use TimeZone.current to match:
// - Core/Utils/DateUtils.dateKey() (main app)
// - Habit.dateKey(for:) (completion data storage)
//
// Changing to UTC or any hardcoded timezone will cause:
// - Widget showing wrong completion status (off-by-one-day errors)
// - Date key mismatches between app and widget
// - User data appearing on wrong dates
//
// Reference: TIMEZONE_AUDIT_REPORT.md (2026-01-12)
// Bug Fix: Widget timezone mismatch causing completion data lookup failures
```

### 2. Unit Test

Create `Tests/DateKeyConsistencyTests.swift`:
```swift
func testAppAndWidgetGenerateSameDateKey() {
    let testDate = Date()
    let appKey = DateUtils.dateKey(for: testDate)
    let widgetKey = DateKeyUtils.dateKey(for: testDate)
    XCTAssertEqual(appKey, widgetKey, "App and widget must generate identical date keys")
}
```

### 3. Linter Rule (Future)

Consider adding a SwiftLint rule to flag:
- Hardcoded `"Europe/Amsterdam"` timezone
- `TimeZone(secondsFromGMT: 0)` (UTC) in date key generation
- Direct `DateFormatter` creation without timezone check

---

## Implementation Priority

### 🔴 **HIGH PRIORITY** (Fix Immediately)
1. ✅ Widget timezone fix (COMPLETED)
2. Create `Shared/DateKeyUtils.swift`
3. Update widget to use shared utility
4. Update `DateKey.swift` to use `TimeZone.current`

### 🟡 **MEDIUM PRIORITY** (Fix This Sprint)
5. Update `LocalDateFormatter` default to `TimeZone.current`
6. Update Firestore date key generation
7. Add unit tests for consistency

### 🟢 **LOW PRIORITY** (Technical Debt)
8. Update migration scripts (one-time, less critical)
9. Update test files and documentation
10. Add linter rules

---

## Files to Modify

### Create:
- `Shared/DateKeyUtils.swift` (NEW)

### Update:
- `Core/Utils/Archive/DateKey.swift` - Change to `TimeZone.current`
- `Core/Time/LocalDateFormatter.swift` - Change default to `SystemTimeZoneProvider`
- `HabittoWidget/MonthlyProgressWidget.swift` - Use `DateKeyUtils.dateKey()`
- `Core/Models/FirestoreModels.swift` - Use `TimeZone.current`
- `Core/Services/FirestoreService.swift` - Use `TimeZone.current`

### Test:
- `Tests/DateKeyConsistencyTests.swift` (NEW)

---

## Risk Assessment

### Low Risk Changes
- ✅ Widget fix (already done, isolated)
- ✅ Creating shared utility (new file, no breaking changes)

### Medium Risk Changes
- ⚠️ Updating `DateKey.swift` (used in 7 places, need testing)
- ⚠️ Updating `LocalDateFormatter` (used in 6 services, need testing)

### High Risk Changes
- 🔴 Firestore date key changes (affects sync, need careful migration)
- 🔴 Migration script changes (affects historical data)

---

## Next Steps

1. **Immediate**: Create `Shared/DateKeyUtils.swift` and update widget
2. **This Week**: Update `DateKey.swift` and `LocalDateFormatter.swift`
3. **This Sprint**: Update Firestore operations and add tests
4. **Future**: Clean up migration scripts and add linter rules

---

## Conclusion

The codebase has **3 different date key generation utilities** using **2 different timezones**. This inconsistency causes date key mismatches, especially for users outside Amsterdam timezone.

**Recommended Action**: Consolidate to `TimeZone.current` everywhere, using a shared utility that both app and widget can use. This ensures consistency and prevents future timezone bugs.
