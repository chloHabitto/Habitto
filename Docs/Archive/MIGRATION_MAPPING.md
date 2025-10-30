# 🔄 Old Model → New Model Migration Mapping

## Overview

This document maps every field from the OLD system to the NEW system, showing exactly how data migrates.

---

## 1. Habit → HabitModel + DailyProgressModel

### OLD: Habit struct

```swift
struct Habit {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: CodableColor
    let habitType: HabitType  // "formation" or "breaking"
    let schedule: String  // "Everyday", "Monday, Wednesday", etc.
    let goal: String  // "5 times every day"
    let reminder: String
    let reminders: [ReminderItem]
    let startDate: Date
    let endDate: Date?
    
    // Progress data (to be split out)
    var completionHistory: [String: Int]  // "2024-10-19" -> 3
    var completionStatus: [String: Bool]  // "2024-10-19" -> true
    var completionTimestamps: [String: [Date]]
    var difficultyHistory: [String: Int]
    var actualUsage: [String: Int]  // For breaking habits
    
    // Habit breaking specific
    var baseline: Int  // Current behavior (e.g., 10 cigarettes)
    var target: Int  // Goal (e.g., 3 cigarettes)
}
```

### NEW: HabitModel (static config only)

```swift
@Model
final class HabitModel {
    var id: UUID  // ← Same
    var userId: String  // ← NEW (required for multi-user)
    var name: String  // ← Same
    var habitDescription: String  // ← From habit.description
    var icon: String  // ← Same
    var colorData: Data  // ← From habit.color (encoded)
    var habitType: String  // ← From habit.habitType.rawValue
    var goalCount: Int  // ← PARSED from habit.goal
    var goalUnit: String  // ← PARSED from habit.goal
    var scheduleData: Data  // ← PARSED from habit.schedule
    var baselineCount: Int?  // ← From habit.baseline
    var baselineUnit: String?  // ← From habit.goalUnit
    var startDate: Date  // ← Same
    var endDate: Date?  // ← Same
    var createdAt: Date  // ← Same
    var updatedAt: Date  // ← NEW
    var reminders: [ReminderModel]  // ← From habit.reminders
}
```

### NEW: DailyProgressModel (one per date)

```swift
@Model
final class DailyProgressModel {
    var id: UUID  // ← NEW (generated)
    var dateString: String  // ← Dictionary key from completionHistory
    var date: Date  // ← Parsed from dateString
    var progressCount: Int  // ← From completionHistory[dateKey] OR actualUsage[dateKey]
    var goalCount: Int  // ← COPIED from habit.goalCount
    var timestamps: [Date]  // ← From completionTimestamps[dateKey]
    var difficulty: Int?  // ← From difficultyHistory[dateKey]
    var habit: HabitModel?  // ← NEW (relationship to parent)
}
```

---

## 2. Detailed Field Mapping

### Habit.goal String → HabitModel Fields

**OLD FORMAT:** `"5 times every day"`, `"30 minutes per day"`, `"1 page everyday"`

**PARSING LOGIC:**

| Old goal String | goalCount | goalUnit | schedule |
|-----------------|-----------|----------|----------|
| `"5 times every day"` | `5` | `"times"` | `.daily` |
| `"30 minutes per day"` | `30` | `"minutes"` | `.daily` |
| `"1 page everyday"` | `1` | `"page"` | `.daily` |
| `"3 cups every Monday"` | `3` | `"cups"` | `.specificWeekdays([.monday])` |

**CODE:**
```swift
// Parse "5 times every day"
let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
let count = components.compactMap { Int($0) }.first ?? 1  // → 5

let pattern = #"(\d+)\s+(\w+)"#  // Match "5 times"
// Extract unit → "times"

// Schedule parsed from goal string or separate schedule field
```

---

### Habit.schedule String → HabitModel.schedule Enum

**OLD FORMAT:** String like `"Everyday"`, `"Monday, Wednesday, Friday"`, `"3 days a week"`

**MAPPING:**

| Old schedule String | New Schedule Enum |
|---------------------|-------------------|
| `"Everyday"` | `.daily` |
| `"Every 2 days"` | `.everyNDays(2)` |
| `"Monday, Wednesday, Friday"` | `.specificWeekdays([.monday, .wednesday, .friday])` |
| `"3 days a week"` | `.frequencyWeekly(3)` |
| `"5 days a month"` | `.frequencyMonthly(5)` |

**CODE:**
```swift
let schedule = Schedule.fromLegacyString(oldHabit.schedule)
```

---

### Habit.completionHistory → DailyProgressModel Records

**OLD FORMAT:** Dictionary `[String: Int]`
```swift
completionHistory = [
    "2024-10-15": 5,  // Completed 5 times on Oct 15
    "2024-10-16": 3,
    "2024-10-17": 5,
]
```

**NEW FORMAT:** Multiple DailyProgressModel records

```swift
// For each entry in completionHistory:
for (dateKey, count) in oldHabit.completionHistory {
    let progress = DailyProgressModel(
        date: DateUtils.date(from: dateKey)!,
        habit: newHabit,
        progressCount: count,
        goalCount: newHabit.goalCount,
        timestamps: oldHabit.completionTimestamps[dateKey] ?? [],
        difficulty: oldHabit.difficultyHistory[dateKey]
    )
    // Save progress
}
```

---

### Habit Breaking: actualUsage → DailyProgressModel

**OLD FORMAT:** Separate dictionary for breaking habits
```swift
// Formation habit
completionHistory["2024-10-15"] = 5  // 5 completions

// Breaking habit  
actualUsage["2024-10-15"] = 3  // 3 cigarettes smoked
```

**NEW FORMAT:** Unified in DailyProgressModel
```swift
// Formation habit
progressCount = 5  // 5 completions

// Breaking habit
progressCount = 3  // 3 cigarettes smoked

// SAME FIELD! Different semantic meaning based on habitType
```

**MIGRATION:**
```swift
if oldHabit.habitType == .breaking {
    // Use actualUsage for breaking habits
    progressCount = oldHabit.actualUsage[dateKey] ?? 0
} else {
    // Use completionHistory for formation habits
    progressCount = oldHabit.completionHistory[dateKey] ?? 0
}
```

---

### Habit Breaking: baseline vs target

**OLD:**
```swift
var baseline: Int  // Current behavior (e.g., 10)
var target: Int    // Goal (e.g., 3)
```

**NEW:**
```swift
var baselineCount: Int?  // Same: 10 (for reference only)
var goalCount: Int       // From target: 3 (used for scheduling)
```

**KEY INSIGHT:** In old system, `target` was the goal. In new system, it's `goalCount`.

---

## 3. GlobalStreakModel (NEW - Calculated)

**OLD:** Per-habit streaks
```swift
// Each Habit had:
var streak: Int  // Per-habit streak
```

**NEW:** ONE global streak
```swift
@Model
final class GlobalStreakModel {
    var currentStreak: Int
    var longestStreak: Int
    var totalCompleteDays: Int
    var lastCompleteDate: Date?
}
```

**MIGRATION:** Recalculate from scratch
```swift
func migrateStreak(habits: [Habit]) -> GlobalStreakModel {
    // Get all unique dates with completions
    var dates: Set<Date> = []
    for habit in habits {
        for dateKey in habit.completionHistory.keys {
            if let date = DateUtils.date(from: dateKey) {
                dates.insert(date)
            }
        }
    }
    
    // For each date, check if ALL habits were complete
    let sortedDates = dates.sorted()
    var streak = 0
    var longest = 0
    var total = 0
    
    for date in sortedDates {
        let allComplete = habits.allSatisfy { habit in
            habit.isCompleted(for: date)
        }
        
        if allComplete {
            streak += 1
            total += 1
            longest = max(longest, streak)
        } else {
            streak = 0
        }
    }
    
    return GlobalStreakModel(
        userId: userId,
        currentStreak: streak,
        longestStreak: longest,
        totalCompleteDays: total
    )
}
```

---

## 4. UserProgressModel (NEW - From XPManager)

**OLD:** UserDefaults storage
```swift
// XPManager (class)
var userProgress: UserProgress  // Struct in UserDefaults
struct UserProgress {
    var totalXP: Int
    var currentLevel: Int
    var dailyXP: Int
}

var recentTransactions: [XPTransaction]  // In UserDefaults
var dailyAwards: [String: Set<UUID>]  // In UserDefaults
```

**NEW:** SwiftData model
```swift
@Model
final class UserProgressModel {
    var userId: String  // NEW
    var totalXP: Int  // From userProgress.totalXP
    var currentLevel: Int  // From userProgress.currentLevel
    var xpForCurrentLevel: Int  // Calculated
    var xpForNextLevel: Int  // Calculated
    var xpTransactions: [XPTransactionModel]  // From recentTransactions
    var achievements: [AchievementModel]  // NEW
}
```

**MIGRATION:**
```swift
func migrateXP(xpManager: XPManager) -> UserProgressModel {
    let userProgress = UserProgressModel(
        userId: currentUserId,
        totalXP: xpManager.userProgress.totalXP
    )
    
    // Migrate transactions
    for transaction in xpManager.recentTransactions {
        let xpTransaction = XPTransactionModel(
            userId: currentUserId,
            amount: transaction.amount,
            reason: transaction.reason,
            timestamp: transaction.timestamp
        )
        userProgress.xpTransactions.append(xpTransaction)
    }
    
    return userProgress
}
```

---

## 5. Complete Migration Example

### Input: Old Habit
```swift
let oldHabit = Habit(
    id: UUID("12345..."),
    name: "Morning Run",
    description: "Run in the morning",
    icon: "figure.run",
    color: .blue,
    habitType: .formation,
    schedule: "Everyday",
    goal: "5 times every day",
    reminder: "",
    startDate: Date("2024-10-01"),
    endDate: nil,
    completionHistory: [
        "2024-10-15": 5,
        "2024-10-16": 3,
        "2024-10-17": 5
    ],
    completionStatus: [
        "2024-10-15": true,
        "2024-10-16": false,
        "2024-10-17": true
    ],
    completionTimestamps: [
        "2024-10-15": [Date("8am"), Date("9am"), ...],
        "2024-10-16": [Date("8am"), Date("9am"), Date("10am")],
        "2024-10-17": [Date("8am"), Date("9am"), ...]
    ],
    difficultyHistory: [
        "2024-10-15": 3,
        "2024-10-16": 4
    ],
    baseline: 0,
    target: 0
)
```

### Output: New Models

**1. HabitModel:**
```swift
HabitModel(
    id: UUID("12345..."),  // Same
    userId: "current_user_id",  // NEW
    name: "Morning Run",  // Same
    habitDescription: "Run in the morning",  // Same
    icon: "figure.run",  // Same
    colorData: <encoded blue>,  // Encoded
    habitType: "Habit Building",  // Same
    goalCount: 5,  // PARSED from "5 times every day"
    goalUnit: "times",  // PARSED from "5 times every day"
    scheduleData: <encoded .daily>,  // PARSED from "Everyday"
    baselineCount: nil,  // Not applicable for formation
    baselineUnit: nil,
    startDate: Date("2024-10-01"),  // Same
    endDate: nil,  // Same
    createdAt: Date("2024-10-01"),
    updatedAt: Date.now
)
```

**2. DailyProgressModel (3 records):**
```swift
// Record 1
DailyProgressModel(
    date: Date("2024-10-15"),
    habit: habitModel,
    progressCount: 5,  // From completionHistory
    goalCount: 5,  // From habit.goalCount
    timestamps: [Date("8am"), Date("9am"), ...],  // From completionTimestamps
    difficulty: 3  // From difficultyHistory
)

// Record 2
DailyProgressModel(
    date: Date("2024-10-16"),
    habit: habitModel,
    progressCount: 3,
    goalCount: 5,
    timestamps: [Date("8am"), Date("9am"), Date("10am")],
    difficulty: 4
)

// Record 3
DailyProgressModel(
    date: Date("2024-10-17"),
    habit: habitModel,
    progressCount: 5,
    goalCount: 5,
    timestamps: [Date("8am"), Date("9am"), ...],
    difficulty: nil  // Not recorded
)
```

---

## 6. Data Integrity Checks Post-Migration

After migration, verify:

### Check 1: All habits migrated
```swift
assert(oldHabits.count == newHabits.count)
```

### Check 2: All progress records migrated
```swift
let oldProgressCount = oldHabits.reduce(0) { $0 + $1.completionHistory.count }
let newProgressCount = newProgressRecords.count
assert(oldProgressCount == newProgressCount)
```

### Check 3: XP matches
```swift
assert(xpManager.userProgress.totalXP == userProgressModel.totalXP)
```

### Check 4: Streak recalculated
```swift
// Verify streak makes sense
assert(globalStreak.currentStreak <= globalStreak.longestStreak)
assert(globalStreak.totalCompleteDays >= globalStreak.longestStreak)
```

---

## 7. What Data Is LOST in Migration

### Permanently Removed:
- ❌ `completionStatus` dict - Now computed from `progressCount >= goalCount`
- ❌ Per-habit `streak` field - Replaced by global streak
- ❌ `isCompleted` field - Now computed property
- ❌ `dailyAwards` tracking - Replaced by XPTransactionModel log

### Why removed?
- All were denormalized/computed data
- Can be recalculated from source of truth
- Removing prevents data inconsistency

---

## 8. Rollback Strategy

If migration fails, we need to rollback:

**Approach:** Keep old data for 30 days

1. During migration, COPY (don't move) data to new models
2. Keep old UserDefaults keys intact
3. Use feature flag `useNewDataModel`
4. If flag = false, read from old system
5. After 30 days of verification, delete old data

**Feature flag:**
```swift
if FeatureFlags.useNewDataModel {
    // Read from SwiftData (new)
    let habits = try modelContext.fetch(FetchDescriptor<HabitModel>())
} else {
    // Read from UserDefaults (old)
    let habits = Habit.loadHabits()
}
```

---

End of Migration Mapping

