# CloudKit Integration Checklist

## Quick Reference: All Integration Points

### ✅ Integration Complete: CloudKitUniquenessManager.swift
- [x] File created at `Core/Data/CloudKit/CloudKitUniquenessManager.swift`
- [x] All methods implemented
- [x] No linting errors

---

## Integration Points (To Do)

### 1. Habit Creation - 2 Locations

#### Location 1: SwiftDataStorage.saveHabits()
- **File:** `Core/Data/SwiftData/SwiftDataStorage.swift`
- **Line:** ~154
- **Change:** Add uniqueness check before creating new habit
- **Status:** ⏳ TODO

#### Location 2: SwiftDataStorage.saveHabit()
- **File:** `Core/Data/SwiftData/SwiftDataStorage.swift`
- **Line:** ~551
- **Change:** Add uniqueness check before creating new habit
- **Status:** ⏳ TODO

---

### 2. Completion Record Creation - 2 Locations

#### Location 1: createCompletionRecordIfNeeded()
- **File:** `Core/Data/SwiftData/HabitDataModel.swift`
- **Line:** ~536
- **Change:** Replace manual check with CloudKitUniquenessManager
- **Status:** ⏳ TODO

#### Location 2: SwiftDataStorage.saveHabits() - Completion Records
- **File:** `Core/Data/SwiftData/SwiftDataStorage.swift`
- **Line:** ~184
- **Change:** Add uniqueness check before creating CompletionRecord
- **Status:** ⏳ TODO

---

### 3. Daily Award Creation - 1 Location

#### Location: SyncEngine.importDailyAwards()
- **File:** `Core/Data/Sync/SyncEngine.swift`
- **Line:** ~1282
- **Change:** Add uniqueness check before creating DailyAward
- **Status:** ⏳ TODO

---

### 4. Post-Sync Deduplication - 2 Locations

#### Location 1: SwiftDataContainer.init() - Observer Setup
- **File:** `Core/Data/SwiftData/SwiftDataContainer.swift`
- **Line:** ~290
- **Change:** Add `setupCloudKitDeduplicationObserver()` call
- **Status:** ⏳ TODO

#### Location 2: SwiftDataContainer - New Methods
- **File:** `Core/Data/SwiftData/SwiftDataContainer.swift`
- **Line:** After `init()` method
- **Change:** Add 4 new methods:
  - `setupCloudKitDeduplicationObserver()`
  - `schedulePeriodicDeduplication()`
  - `getDuplicateStatistics()`
  - `logDuplicateStatistics()`
- **Status:** ⏳ TODO

---

## Testing Checklist

After all integrations complete:

- [ ] Build succeeds (no compilation errors)
- [ ] Test habit creation (check logs for uniqueness check)
- [ ] Test completion record creation (check logs)
- [ ] Test daily award creation (check logs)
- [ ] Test on 2 devices (iPhone + iPad)
- [ ] Test simultaneous creation scenario
- [ ] Monitor CloudKit Dashboard for duplicates
- [ ] Check logs for deduplication activity
- [ ] Verify no duplicates in database
- [ ] Test offline → online sync scenario

---

## Files to Modify

1. ✅ `Core/Data/CloudKit/CloudKitUniquenessManager.swift` - DONE
2. ⏳ `Core/Data/SwiftData/SwiftDataStorage.swift` - 3 changes
3. ⏳ `Core/Data/SwiftData/HabitDataModel.swift` - 1 change
4. ⏳ `Core/Data/Sync/SyncEngine.swift` - 1 change
5. ⏳ `Core/Data/SwiftData/SwiftDataContainer.swift` - 5 changes

**Total:** 1 file done, 4 files to modify

---

## Quick Start

1. Open `CLOUDKIT_INTEGRATION_CODE.md` for exact code changes
2. Apply changes file by file
3. Build and test after each file
4. Complete testing checklist
5. Enable CloudKit when ready

---

**See `CLOUDKIT_INTEGRATION_CODE.md` for detailed code examples!**

