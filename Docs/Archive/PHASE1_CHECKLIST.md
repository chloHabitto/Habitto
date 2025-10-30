# ✅ PHASE 1 CHECKLIST - Data Model Foundation

**Date:** October 22, 2025  
**Status:** 🟡 AWAITING APPROVAL  
**Estimated Time:** 5-7 days  

---

## 📋 PRE-FLIGHT CHECKS (MUST COMPLETE FIRST)

- [ ] **User confirms data backup exists**
- [ ] **User approves this checklist**
- [ ] **User answers compatibility question** (Can app be broken during Phase 1?)
- [ ] **All planning documents reviewed and approved**
- [ ] **Git branch created:** `refactor/phase1-data-models`
- [ ] **Backup of current database created**
- [ ] **Test data set prepared** (copy of real data)

---

## 📚 PLANNING DOCUMENTS TO CREATE (Before Any Code)

### Document 1: Migration Safety Plan
**File:** `MIGRATION_SAFETY_PLAN.md`

**Contents:**
- [ ] Complete backup strategy
- [ ] Export user data to JSON
- [ ] Validation checksums for integrity
- [ ] Rollback procedures per step
- [ ] Data corruption detection
- [ ] User data restore process

**Estimated Time:** 2 hours  
**Deliverable:** Complete safety procedures documented

---

### Document 2: SwiftData Schema V2 Definition
**File:** `SWIFTDATA_SCHEMA_V2.md`

**Contents:**
- [ ] Complete HabitModel definition with all fields
- [ ] Complete DailyProgressModel definition
- [ ] Complete GlobalStreakModel definition
- [ ] Complete UserProgressModel definition
- [ ] All relationships documented
- [ ] All validation rules defined
- [ ] Date format standard (ISO 8601)
- [ ] Migration mapping from V1 to V2

**Estimated Time:** 3 hours  
**Deliverable:** Complete schema specification

---

### Document 3: Repository Interface Contract
**File:** `REPOSITORY_CONTRACT.md`

**Contents:**
- [ ] HabitRepository interface (all public methods)
- [ ] ProgressRepository interface
- [ ] StreakRepository interface
- [ ] XPRepository interface
- [ ] Expected behavior for each method
- [ ] Error cases and error types
- [ ] Thread-safety guarantees (@MainActor requirements)
- [ ] Async/await patterns

**Estimated Time:** 2 hours  
**Deliverable:** Complete API contract

---

## 🏗️ IMPLEMENTATION STEPS

### Step 1: Create New Model Files (No Breaking Changes)

**Files to CREATE:**
- [ ] `Core/Models/V2/HabitModel.swift` (new file)
- [ ] `Core/Models/V2/DailyProgressModel.swift` (new file)
- [ ] `Core/Models/V2/GlobalStreakModel.swift` (new file)
- [ ] `Core/Models/V2/UserProgressModel.swift` (new file)
- [ ] `Core/Models/V2/XPTransactionModel.swift` (new file)
- [ ] `Core/Models/V2/ReminderModel.swift` (new file)
- [ ] `Core/Models/V2/Schedule.swift` (enum definitions)
- [ ] `Core/Models/V2/HabitType.swift` (enum definitions)

**Changes:**
- ✅ NEW directory: `Core/Models/V2/`
- ✅ All models marked with `@Model` for SwiftData
- ✅ All relationships defined with `@Relationship`
- ✅ All unique IDs marked with `@Attribute(.unique)`
- ✅ Date fields use consistent ISO 8601 format

**Testing:**
- [ ] Models compile without errors
- [ ] Can create instances of each model
- [ ] Relationships work correctly
- [ ] No conflicts with V1 models

**Rollback:** Delete `Core/Models/V2/` directory

**Estimated Time:** 4 hours  
**Risk Level:** 🟢 LOW (no changes to existing code)

---

### Step 2: Add V2 Schema to SwiftData Container

**Files to MODIFY:**
- [ ] `App/HabittoApp.swift` (add schema version 2)

**Changes:**
```swift
// Add V2 schema alongside V1 (not replacing yet)
let schemaV2 = Schema([
    HabitModel.self,
    DailyProgressModel.self,
    GlobalStreakModel.self,
    UserProgressModel.self,
    XPTransactionModel.self,
    ReminderModel.self
])

let versionedSchema = VersionedSchema([schemaV1, schemaV2])
```

**Testing:**
- [ ] App launches without crashes
- [ ] V1 models still work
- [ ] V2 models can be created (in tests)
- [ ] No data loss

**Rollback:** Remove schemaV2 from versioned schema

**Estimated Time:** 1 hour  
**Risk Level:** 🟡 MEDIUM (touching app initialization)

---

### Step 3: Fix toHabit() Bug (CRITICAL)

**Files to MODIFY:**
- [ ] `Core/Data/SwiftData/HabitDataModel.swift`

**Changes:**
```swift
// Line ~175 in toHabit() method
// ADD: Rebuild completionStatus from CompletionRecords

let completionStatusDict: [String: Bool] = Dictionary(
    uniqueKeysWithValues: completionHistory.map {
        (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted)
    }
)

let completionTimestampsDict: [String: [Date]] = Dictionary(
    uniqueKeysWithValues: completionHistory.map {
        let dateKey = ISO8601DateHelper.shared.string(from: $0.date)
        let timestamps = $0.timestamps ?? []
        return (dateKey, timestamps)
    }
)

return Habit(
    ...
    completionStatus: completionStatusDict,  // ✅ NOW POPULATED
    completionTimestamps: completionTimestampsDict  // ✅ NOW POPULATED
)
```

**Testing:**
- [ ] Load app with existing data
- [ ] Verify Habit1 shows as complete (if it was completed)
- [ ] Verify Habit2 shows correct completion state
- [ ] Verify streak calculates correctly
- [ ] Verify XP matches expected value
- [ ] Restart app and verify data persists

**Rollback:** Revert `HabitDataModel.swift` to previous version

**Estimated Time:** 1 hour  
**Risk Level:** 🔴 HIGH (critical data loading path)  
**Priority:** ⚡ DO THIS FIRST - Fixes immediate data corruption

---

### Step 4: Create Migration Script

**Files to CREATE:**
- [ ] `Core/Migration/V1ToV2Migration.swift` (new file)
- [ ] `Core/Migration/MigrationValidator.swift` (new file)
- [ ] `Core/Migration/DataBackup.swift` (new file)

**Changes:**
```swift
// V1ToV2Migration.swift
actor V1ToV2Migration {
    func migrate(modelContext: ModelContext) async throws {
        // 1. Backup all V1 data
        try await backupV1Data()
        
        // 2. Load all V1 habits
        let oldHabits = try await fetchAllV1Habits()
        
        // 3. For each habit, create V2 models
        for oldHabit in oldHabits {
            let newHabit = try await migrateHabit(oldHabit)
            try await migrateCompletionRecords(oldHabit, to: newHabit)
        }
        
        // 4. Recalculate global streak
        try await recalculateGlobalStreak()
        
        // 5. Migrate XP data
        try await migrateUserProgress()
        
        // 6. Validate migration
        try await validateMigration()
        
        // 7. Mark migration complete
        UserDefaults.standard.set(true, forKey: "migration_v2_complete")
    }
}
```

**Testing:**
- [ ] Test on COPY of real data first
- [ ] Verify no data loss
- [ ] Verify all completions migrated
- [ ] Verify streak calculates correctly
- [ ] Verify XP values correct
- [ ] Verify rollback works

**Rollback:** Delete all V2 models, restore from backup

**Estimated Time:** 6 hours  
**Risk Level:** 🔴 HIGH (migrating user data)

---

### Step 5: Add Data Validation Layer

**Files to CREATE:**
- [ ] `Core/Validation/HabitValidator.swift` (new file)
- [ ] `Core/Validation/ProgressValidator.swift` (new file)
- [ ] `Core/Validation/ValidationError.swift` (new file)

**Changes:**
```swift
// HabitValidator.swift
struct HabitValidator {
    static func validate(_ habit: HabitModel) throws {
        // Name validation
        guard !habit.name.isEmpty else {
            throw ValidationError.emptyName
        }
        
        // Goal validation
        guard habit.goalCount > 0 else {
            throw ValidationError.invalidGoal
        }
        
        // Date validation
        if let endDate = habit.endDate {
            guard endDate >= habit.startDate else {
                throw ValidationError.endBeforeStart
            }
        }
        
        // Breaking habit validation
        if habit.habitType == .breaking {
            guard let baseline = habit.baselineCount,
                  baseline > habit.goalCount else {
                throw ValidationError.baselineLessThanGoal
            }
        }
    }
}
```

**Testing:**
- [ ] Test each validation rule
- [ ] Verify invalid habits rejected
- [ ] Verify valid habits accepted
- [ ] Error messages are clear

**Rollback:** Delete validation files

**Estimated Time:** 3 hours  
**Risk Level:** 🟢 LOW (additive only)

---

### Step 6: Add Date Utility Consolidation

**Files to CREATE:**
- [ ] `Core/Utilities/DateFormatter.swift` (new file)

**Files to MODIFY:**
- [ ] `Core/Utilities/ISO8601DateHelper.swift` (consolidate)
- [ ] `Core/Utilities/LegacyDateUtils.swift` (deprecate)

**Changes:**
- ✅ Single date formatting function: `dateKey(from: Date) -> String`
- ✅ Format: "yyyy-MM-dd" (ISO 8601)
- ✅ Single date parsing function: `date(from: String) -> Date?`
- ✅ Timezone-aware using `Calendar.current`
- ✅ Deprecation warnings for old utilities

**Testing:**
- [ ] Verify date keys consistent across app
- [ ] Test timezone handling
- [ ] Test DST transitions
- [ ] Verify parsing roundtrip (date -> string -> date)

**Rollback:** Keep old utilities, delete new ones

**Estimated Time:** 2 hours  
**Risk Level:** 🟡 MEDIUM (date handling is critical)

---

### Step 7: Test Migration on Real Data Copy

**Files to CREATE:**
- [ ] `Tests/MigrationTests.swift` (new file)

**Testing Steps:**
1. [ ] Export your current app data to JSON
2. [ ] Load data into test environment
3. [ ] Run migration script
4. [ ] Verify all habits present
5. [ ] Verify all completions migrated
6. [ ] Verify streak calculation correct
7. [ ] Verify XP values correct
8. [ ] Check for any orphaned records
9. [ ] Verify data integrity checksums

**Pass Criteria:**
- ✅ Zero data loss
- ✅ All completion dates preserved
- ✅ All XP transactions preserved
- ✅ Streak matches expected value
- ✅ No crashes during migration
- ✅ Migration completes in < 5 seconds

**If ANY test fails:** Stop and debug before proceeding

**Estimated Time:** 4 hours  
**Risk Level:** 🔴 HIGH (this is the final safety check)

---

## 📊 PHASE 1 COMPLETION CRITERIA

### Must Have (Blocking)
- [ ] ✅ All V2 models created and compiling
- [ ] ✅ toHabit() bug FIXED and tested
- [ ] ✅ Migration script written and tested on copy of data
- [ ] ✅ All data validation tests passing
- [ ] ✅ Zero data loss in migration
- [ ] ✅ App loads with existing data correctly
- [ ] ✅ Completion states show correctly
- [ ] ✅ Streak calculates correctly
- [ ] ✅ XP values are correct

### Should Have (Important but not blocking)
- [ ] ✅ Date utilities consolidated
- [ ] ✅ Validation layer complete
- [ ] ✅ All debug prints removed from new code
- [ ] ✅ Documentation updated

### Nice to Have (Can defer to Phase 2)
- [ ] Performance benchmarks
- [ ] Analytics events
- [ ] Error reporting setup

---

## 🧪 TESTING MATRIX

| Scenario | Expected Result | Pass/Fail |
|----------|-----------------|-----------|
| Load app with existing habits | All habits visible | ⬜ |
| Habit completion states | Correct complete/incomplete | ⬜ |
| Streak calculation | Matches manual count | ⬜ |
| XP value | Matches expected formula | ⬜ |
| Complete a habit | Progress saves and persists | ⬜ |
| Undo completion | Progress reverts correctly | ⬜ |
| App restart | All data persists | ⬜ |
| Create new habit | Saves to V2 models | ⬜ |
| Offline mode | All operations work | ⬜ |
| Background sync | Firestore updates without blocking | ⬜ |

---

## 🔄 ROLLBACK PROCEDURES

### If Step 1-2 Fails:
```bash
git checkout main
git branch -D refactor/phase1-data-models
rm -rf Core/Models/V2/
```
**Data Loss Risk:** None (no data touched yet)

### If Step 3 (toHabit fix) Fails:
```bash
git revert <commit-hash>
```
**Data Loss Risk:** None (only reading, not writing)

### If Step 4-5 (Migration) Fails:
```bash
# Restore from backup
cp backup/habits.json ./
# Revert migration
git revert <commit-hash>
# Clear migration flag
defaults delete com.habitto.app migration_v2_complete
```
**Data Loss Risk:** Medium (requires backup to be good)

### If Complete Failure:
```bash
git reset --hard origin/main
# Restore backup
./restore_backup.sh
```
**Data Loss Risk:** None if backup is recent

---

## ⏱️ TIME ESTIMATES

| Task | Optimistic | Realistic | Pessimistic |
|------|-----------|-----------|-------------|
| Planning Docs | 4 hours | 7 hours | 10 hours |
| Create Models | 3 hours | 4 hours | 6 hours |
| Add to Schema | 0.5 hours | 1 hour | 2 hours |
| Fix toHabit() | 0.5 hours | 1 hour | 2 hours |
| Migration Script | 4 hours | 6 hours | 10 hours |
| Validation Layer | 2 hours | 3 hours | 5 hours |
| Date Utilities | 1 hour | 2 hours | 3 hours |
| Testing | 3 hours | 4 hours | 6 hours |
| **TOTAL** | **18 hours** | **28 hours** | **44 hours** |

**Realistic Timeline:** 3.5 days of focused work (8 hours/day)

---

## 🚨 RISK ASSESSMENT

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss during migration | Medium | Critical | Backup before every step |
| Migration script bugs | High | High | Test on copy first |
| toHabit() fix breaks something | Low | Medium | Comprehensive testing |
| V2 models have schema issues | Low | Medium | Review before implementing |
| Timeline slips | Medium | Low | Build in buffer time |

---

## 📋 APPROVAL CHECKLIST

**Before I start coding, you must approve:**

- [ ] **This checklist** (you've reviewed and agree with approach)
- [ ] **MIGRATION_SAFETY_PLAN.md** (backup/restore procedures)
- [ ] **SWIFTDATA_SCHEMA_V2.md** (data model definitions)
- [ ] **REPOSITORY_CONTRACT.md** (API contracts)

**And answer these questions:**

1. **Data backup exists?** [YES/NO]
2. **App can be broken during Phase 1?** [YES/NO - or maintain compatibility?]
3. **Priority: Speed or Correctness?** [Your answer: CORRECTNESS confirmed]
4. **Feature freeze agreed?** [Your answer: YES confirmed]

---

## 🎯 SUCCESS METRICS

**Phase 1 is COMPLETE when:**

1. ✅ App loads existing habits correctly (no data loss)
2. ✅ Completion states display correctly (toHabit bug fixed)
3. ✅ Can complete a habit and see it persist
4. ✅ XP only awarded when all habits for day complete
5. ✅ Streak calculates correctly from CompletionRecords
6. ✅ Data survives app restart (persists correctly)
7. ✅ All tests in testing matrix pass
8. ✅ Zero crashes in testing
9. ✅ Backup/restore procedures tested and work
10. ✅ You're confident in the foundation for Phase 2

---

## 📚 DOCUMENTATION UPDATES REQUIRED

**During Phase 1:**
- [ ] Update `APP_OVERVIEW.md` with V2 architecture
- [ ] Update `DATA_ARCHITECTURE.md` with new models
- [ ] Create `MIGRATION_GUIDE.md` for future developers
- [ ] Archive old architecture docs to `archive/`

**Keep only ONE source of truth for each topic.**

---

## ✅ NEXT STEPS

1. **Review this checklist** - Approve or request changes
2. **Answer the approval questions** above
3. **I'll create the 3 planning documents** (Migration Safety, Schema V2, Repository Contract)
4. **You review and approve those documents**
5. **I create git branch and backup**
6. **I proceed with Step 1** (Create V2 models)
7. **Test after each step, get your approval before next step**

---

**Status:** 🟡 AWAITING YOUR APPROVAL  
**Next Action:** Your review and answers to questions

**Reply with:**
- ✅ "APPROVED - proceed with planning documents" OR
- 📝 "CHANGES NEEDED - [explain what]"

