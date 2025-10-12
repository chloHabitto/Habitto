# Goal Field Migration Map

**Date**: October 12, 2025  
**Purpose**: Document all `habit.goal` usages for migration to `GoalVersioningService`  
**Total Instances**: 86 across 21 files

---

## 📋 Migration Strategy

**Current State**:
- `habit.goal` is a **String** (e.g., "1 time", "3 times per day")
- Helper functions parse this string: `parseGoalAmount()`, `extractGoalNumber()`

**Target State**:
- `GoalVersioningService.goal(on: date, habitId:)` returns **Int**
- Date-effective goals (different goals on different dates)
- No string parsing needed

**Migration Approach**:
- Phase 1: Keep both systems during dual-write period
- Phase 2: Gradually replace `habit.goal` reads with service calls
- Phase 3: Remove legacy `goal` String field

---

## 📊 Usage Breakdown by Category

### 1. **UI Display** (32 instances)
Files that display goal text to users

- `Views/Screens/HabitDetailView.swift` (8 instances)
- `Views/Tabs/ProgressTabView.swift` (11 instances)
- `Views/Screens/HabitEditView.swift` (5 instances)
- `Views/Screens/ExportDataView.swift` (2 instances)
- `Views/Flows/CreateHabitStep2View.swift` (4 instances)
- `Core/UI/Items/AddedHabitItem.swift` (1 instance)
- `Core/UI/Components/HabitSelectorView.swift` (1 instance)

**Migration**: Replace with `GoalVersioningService.goal(on: date, habitId:)`

### 2. **Progress Calculation** (30 instances)
Files that calculate completion percentages

- `Core/UI/Helpers/ProgressCalculationHelper.swift` (12 instances)
- `Core/UI/Items/ScheduledHabitItem.swift` (5 instances)
- `Core/UI/Forms/ProgressCalculationLogic.swift` (4 instances)
- `Core/Data/StreakDataCalculator.swift` (1 instance)
- `Core/Data/CalendarGridViews.swift` (2 instances)
- `Core/Data/HabitRepository.swift` (1 instance)
- `Core/UI/Helpers/HabitPatternAnalyzer.swift` (2 instances)
- `Views/Screens/HabitDetailView.swift` (3 more instances)

**Migration**: Replace with service calls, pass date context

### 3. **Data Persistence** (12 instances)
Files that save/load habit data

- `Core/Data/SwiftData/SwiftDataStorage.swift` (2 instances)
- `Core/Data/CloudKit/CloudKitIntegrationService.swift` (1 instance)
- `Core/Data/CloudKitManager.swift` (1 instance)
- `Core/Data/CoreDataManager.swift` (1 instance)
- `Core/Data/SwiftData/SimpleHabitData.swift` (1 instance)
- `Core/Data/SwiftData/HabitDataModel.swift` (1 instance)
- `Core/Data/Storage/CrashSafeHabitStore.swift` (1 instance)
- `Core/Data/Backup/DataRepairUtility.swift` (4 instances)

**Migration**: Store in Firestore via `GoalVersioningService.setGoal()`

### 4. **Validation** (4 instances)
Files that validate goal values

- `Core/Validation/DataValidation.swift` (1 instance)
- `Core/Data/Migration/MigrationInvariantsValidator.swift` (1 instance)
- `Core/Data/Migration/DataFormatMigrations.swift` (2 instances)

**Migration**: Validate Int instead of String

### 5. **Migration/Sync** (5 instances)
Files that handle data migration and sync

- `Core/Services/MigrationRunner.swift` (1 instance)
- `Core/Data/CloudKit/ConflictResolutionPolicy.swift` (1 instance)
- `Core/Utils/TextSanitizer.swift` (1 instance)
- `Core/Services/GoalVersioningService.swift` (1 instance - already migrated)
- `Core/Data/Backup/DataRepairUtility.swift` (1 instance)

**Migration**: Update to use goal versioning

### 6. **Testing** (3 instances)
Test files (not counted in main migration)

---

## 🎯 Critical Files for Migration

### High Priority (User-Facing)
1. **HabitDetailView.swift** (8 instances) - Main detail screen
2. **ProgressTabView.swift** (11 instances) - Progress tracking
3. **ProgressCalculationHelper.swift** (12 instances) - Core progress logic

### Medium Priority (Data Layer)
4. **SwiftDataStorage.swift** (2 instances) - Data persistence
5. **HabitRepository.swift** (1 instance) - Repository layer

### Low Priority (Edge Cases)
6. **HabitEditView.swift** (5 instances) - Edit screen
7. **ExportDataView.swift** (2 instances) - Data export
8. **Validation files** (4 instances) - Data validation

---

## 📝 Migration Pattern Examples

### Before (String goal)
```swift
// UI Display
Text(habit.goal)  // "3 times"

// Progress Calculation
let goalAmount = parseGoalAmount(from: habit.goal)  // Returns 3
let percentage = Double(progress) / Double(goalAmount)

// Persistence
habitData.goal = habit.goal  // Save string
```

### After (Versioned goal)
```swift
// UI Display
let goalValue = try await goalService.goal(on: selectedDate, habitId: habit.id)
Text("\(goalValue) times")  // "3 times"

// Progress Calculation
let goalAmount = try await goalService.goal(on: date, habitId: habit.id)
let percentage = Double(progress) / Double(goalAmount)

// Persistence
try await goalService.setGoal(
    habitId: habit.id,
    effectiveLocalDate: dateString,
    goal: goalValue
)
```

---

## 🔄 Migration Phases

### Phase 1: Dual Read (Current)
- ✅ `GoalVersioningService` created
- ✅ Service reads from Firestore goal versions
- ⏳ Legacy `habit.goal` still in use
- ⏳ Both systems coexist

### Phase 2: Dual Write
- Write new goals to both:
  - Legacy `habit.goal` String field (for backward compat)
  - Firestore goal versions (via service)
- UI still reads from legacy field
- Firestore builds up goal history

### Phase 3: Switch Reads
- UI switches to read from `GoalVersioningService`
- Legacy `habit.goal` still written (for rollback safety)
- Firestore becomes primary source

### Phase 4: Cleanup
- Remove legacy `habit.goal` String field
- Remove helper functions: `parseGoalAmount()`, etc.
- Firestore is sole source of truth

---

## 📂 Files by Priority

### Must Migrate (Break without service)
```
Core/UI/Helpers/ProgressCalculationHelper.swift       (12 instances)
Views/Tabs/ProgressTabView.swift                      (11 instances)
Views/Screens/HabitDetailView.swift                   (8 instances)
Core/UI/Items/ScheduledHabitItem.swift                (5 instances)
Views/Screens/HabitEditView.swift                     (5 instances)
```

### Should Migrate (UX degradation)
```
Core/UI/Forms/ProgressCalculationLogic.swift          (4 instances)
Views/Flows/CreateHabitStep2View.swift                (4 instances)
Core/Data/Backup/DataRepairUtility.swift              (4 instances)
Core/Data/CalendarGridViews.swift                     (2 instances)
Views/Screens/ExportDataView.swift                    (2 instances)
```

### Can Defer (Edge cases)
```
Core/UI/Helpers/HabitPatternAnalyzer.swift            (2 instances)
Core/UI/Components/ListItemComponents.swift           (1 instance)
Core/UI/Components/HabitSelectorView.swift            (1 instance)
Core/Data/StreakDataCalculator.swift                  (1 instance)
[... and others]
```

---

## 🚀 Next Steps

1. **Now**: Service created, tests written
2. **Step 6**: Create dual-write wrapper
3. **Step 7**: Migrate high-priority files (ProgressCalculationHelper, ProgressTabView)
4. **Step 8**: Migrate medium-priority files
5. **Step 9**: Remove legacy field

---

## 📋 Detailed Instance List

### HabitDetailView.swift (8 instances)
```
Line 203:  goal: habit.goal,
Line 540:  Text(sortGoalChronologically(habit.goal))
Line 665:  // Comment about habit.goal
Line 683:  goal=\(extractGoalNumber(from: habit.goal))
Line 705:  let goalAmount = extractGoalNumber(from: habit.goal)
Line 752:  / CGFloat(extractGoalNumber(from: habit.goal))
Line 767:  Text("\(extractGoalNumber(from: habit.goal))")
Line 804:  goal: habit.goal,
```

**Migration Plan**: Replace with `goalService.goal(on: selectedDate, habitId:)`

### ProgressTabView.swift (11 instances)
All instances parse goal amount for progress calculation.

**Migration Plan**: Inject GoalVersioningService, pass date context to calculations

### ProgressCalculationHelper.swift (12 instances)
Core progress calculation logic.

**Migration Plan**: Update to accept goal as Int parameter instead of parsing String

---

**Status**: Documented  
**Ready For**: Dual-write implementation (Step 6)  
**Total Impact**: 86 instances across 21 files


