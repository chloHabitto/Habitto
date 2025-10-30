# 🏗️ New Data Architecture Design - Phase 1

## Date: October 19, 2025

This document defines the complete new data architecture that will replace the current fragmented system.

---

## 📐 SwiftData Models

### 1. HabitModel (Core Habit Definition)

```swift
import Foundation
import SwiftData
import SwiftUI

@Model
final class HabitModel {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    var userId: String  // For multi-user support
    
    // MARK: - Basic Info
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data  // Encoded Color
    
    // MARK: - Type
    var habitType: String  // "formation" or "breaking"
    
    // MARK: - Goal Configuration
    var goalCount: Int  // The number (1, 5, 30, etc.)
    var goalUnit: String  // "time", "times", "min", "pages", etc.
    var scheduleType: String  // Enum stored as String
    var scheduleData: Data  // JSON-encoded schedule details
    
    // MARK: - Breaking Habit Specific (Optional)
    var baselineCount: Int?  // Current behavior for comparison (e.g., 10 cigarettes)
    var baselineUnit: String?  // Unit for baseline (usually same as goalUnit)
    
    // MARK: - Date Range
    var startDate: Date
    var endDate: Date?
    
    // MARK: - Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Reminders
    @Relationship(deleteRule: .cascade) var reminders: [ReminderModel]
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \DailyProgressModel.habit) 
    var progressRecords: [DailyProgressModel]
    
    // MARK: - Computed Properties
    var color: Color {
        get { Self.decodeColor(colorData) }
        set { colorData = Self.encodeColor(newValue) }
    }
    
    var habitTypeEnum: HabitType {
        get { HabitType(rawValue: habitType) ?? .formation }
        set { habitType = newValue.rawValue }
    }
    
    var schedule: Schedule {
        get { 
            guard let decoded = try? JSONDecoder().decode(Schedule.self, from: scheduleData) 
            else { return .daily }
            return decoded
        }
        set {
            scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        habitDescription: String,
        icon: String,
        color: Color,
        habitType: HabitType,
        goalCount: Int,
        goalUnit: String,
        schedule: Schedule,
        baselineCount: Int? = nil,
        baselineUnit: String? = nil,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.habitDescription = habitDescription
        self.icon = icon
        self.colorData = Self.encodeColor(color)
        self.habitType = habitType.rawValue
        self.goalCount = goalCount
        self.goalUnit = goalUnit
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        self.baselineCount = baselineCount
        self.baselineUnit = baselineUnit
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.reminders = []
        self.progressRecords = []
    }
    
    // MARK: - Helper Methods
    static func encodeColor(_ color: Color) -> Data {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let components = [red, green, blue, alpha]
        return (try? NSKeyedArchiver.archivedData(
            withRootObject: components, 
            requiringSecureCoding: false)) ?? Data()
    }
    
    static func decodeColor(_ data: Data) -> Color {
        guard let components = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSArray.self, 
            from: data) as? [CGFloat],
              components.count == 4 
        else { return .blue }
        return Color(red: Double(components[0]), 
                    green: Double(components[1]), 
                    blue: Double(components[2]), 
                    opacity: Double(components[3]))
    }
}

// MARK: - Supporting Types

enum HabitType: String, Codable, CaseIterable {
    case formation = "Habit Building"
    case breaking = "Habit Breaking"
}

enum Schedule: Codable, Equatable {
    case daily
    case everyNDays(Int)
    case specificWeekdays([Weekday])
    case frequencyWeekly(Int)  // n days per week (flexible)
    case frequencyMonthly(Int)  // n days per month (flexible)
    
    // Helper: Should habit appear on this date?
    func shouldAppear(on date: Date, habitStartDate: Date) -> Bool {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let startDate = calendar.startOfDay(for: habitStartDate)
        
        // Don't show before habit start date
        guard targetDate >= startDate else { return false }
        
        switch self {
        case .daily:
            return true
            
        case .everyNDays(let n):
            let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 0
            return daysSinceStart % n == 0
            
        case .specificWeekdays(let weekdays):
            let weekday = calendar.component(.weekday, from: targetDate)
            return weekdays.contains(Weekday(weekdayNumber: weekday))
            
        case .frequencyWeekly(_):
            // For frequency-based, show EVERY day - user decides which days to complete
            return true
            
        case .frequencyMonthly(_):
            // For frequency-based, show EVERY day - user decides which days to complete
            return true
        }
    }
}

enum Weekday: String, Codable, CaseIterable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var weekdayNumber: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
    
    init(weekdayNumber: Int) {
        switch weekdayNumber {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .wednesday
        case 4: self = .thursday
        case 5: self = .friday
        case 6: self = .saturday
        case 7: self = .saturday
        default: self = .sunday
        }
    }
}
```

---

### 2. DailyProgressModel (Single Source of Truth)

```swift
import Foundation
import SwiftData

@Model
final class DailyProgressModel {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    
    // MARK: - Core Data
    var dateString: String  // "yyyy-MM-dd" format - indexed
    var date: Date  // Actual date for queries
    
    // MARK: - Progress Tracking
    var progressCount: Int  // For formation: completions, For breaking: usage count
    var goalCount: Int  // Daily goal for this habit (copied from HabitModel)
    
    // MARK: - Metadata
    var timestamps: [Date]  // When each action happened (for time-of-day analytics)
    var difficulty: Int?  // 1-5 scale, optional (user feedback)
    
    // MARK: - Relationships
    var habit: HabitModel?
    
    // MARK: - Computed Properties
    var isComplete: Bool {
        progressCount >= goalCount
    }
    
    var isOverGoal: Bool {
        progressCount > goalCount
    }
    
    var completionPercentage: Double {
        guard goalCount > 0 else { return 0 }
        return min(Double(progressCount) / Double(goalCount), 1.0)
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        date: Date,
        habitId: UUID,
        progressCount: Int = 0,
        goalCount: Int,
        timestamps: [Date] = [],
        difficulty: Int? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.dateString = DateUtils.dateKey(for: date)
        self.progressCount = progressCount
        self.goalCount = goalCount
        self.timestamps = timestamps
        self.difficulty = difficulty
    }
    
    // MARK: - Progress Actions
    mutating func increment(at timestamp: Date = Date()) {
        progressCount += 1
        timestamps.append(timestamp)
    }
    
    mutating func decrement() {
        guard progressCount > 0 else { return }
        progressCount -= 1
        if !timestamps.isEmpty {
            timestamps.removeLast()
        }
    }
    
    mutating func setProgress(_ count: Int, timestamps: [Date] = []) {
        progressCount = count
        self.timestamps = timestamps
    }
    
    mutating func setDifficulty(_ rating: Int) {
        difficulty = max(1, min(5, rating))
    }
}
```

---

### 3. GlobalStreakModel (One Per User)

```swift
import Foundation
import SwiftData

@Model
final class GlobalStreakModel {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    var userId: String
    
    // MARK: - Streak Data
    var currentStreak: Int  // Consecutive days ALL habits completed
    var longestStreak: Int  // Best ever consecutive streak
    var totalCompleteDays: Int  // Lifetime count (not necessarily consecutive)
    var lastCompleteDate: Date?  // For detecting breaks
    
    // MARK: - Metadata
    var lastUpdated: Date
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        userId: String,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalCompleteDays: Int = 0,
        lastCompleteDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalCompleteDays = totalCompleteDays
        self.lastCompleteDate = lastCompleteDate
        self.lastUpdated = Date()
    }
    
    // MARK: - Update Methods
    mutating func incrementStreak(on date: Date) {
        let calendar = Calendar.current
        let dateNormalized = calendar.startOfDay(for: date)
        
        // Check if this is the next day after last complete date
        if let lastDate = lastCompleteDate {
            let lastDateNormalized = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDateNormalized, to: dateNormalized).day ?? 0
            
            if daysDiff == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
            } else if daysDiff > 1 {
                // Break in streak - reset to 1
                currentStreak = 1
            }
            // If daysDiff == 0, it's the same day - don't increment
        } else {
            // First complete day ever
            currentStreak = 1
        }
        
        // Update longest streak if needed
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        // Update totals
        totalCompleteDays += 1
        lastCompleteDate = dateNormalized
        lastUpdated = Date()
    }
    
    mutating func breakStreak() {
        currentStreak = 0
        lastUpdated = Date()
    }
    
    mutating func recalculateFrom(progressRecords: [DailyProgressModel], habits: [HabitModel]) {
        // Full recalculation from scratch
        // Used for migrations and integrity checks
        
        var streak = 0
        var longest = 0
        var totalComplete = 0
        var lastComplete: Date? = nil
        
        // Get all unique dates with progress
        let dates = Set(progressRecords.map { $0.date }).sorted()
        
        for date in dates {
            // Check if ALL habits scheduled for this date are complete
            let habitsForDate = habits.filter { habit in
                habit.schedule.shouldAppear(on: date, habitStartDate: habit.startDate)
            }
            
            let progressForDate = progressRecords.filter { 
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }
            
            let allComplete = habitsForDate.allSatisfy { habit in
                progressForDate.contains { progress in
                    progress.habit?.id == habit.id && progress.isComplete
                }
            }
            
            if allComplete && !habitsForDate.isEmpty {
                // Day is complete
                if let last = lastComplete {
                    let daysDiff = Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0
                    if daysDiff == 1 {
                        streak += 1
                    } else {
                        streak = 1
                    }
                } else {
                    streak = 1
                }
                
                if streak > longest {
                    longest = streak
                }
                
                totalComplete += 1
                lastComplete = date
            } else if !habitsForDate.isEmpty {
                // Day is incomplete (but had habits scheduled)
                streak = 0
            }
        }
        
        self.currentStreak = streak
        self.longestStreak = longest
        self.totalCompleteDays = totalComplete
        self.lastCompleteDate = lastComplete
        self.lastUpdated = Date()
    }
}
```

---

### 4. UserProgressModel (XP and Achievements)

```swift
import Foundation
import SwiftData

@Model
final class UserProgressModel {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    var userId: String
    
    // MARK: - XP Data
    var totalXP: Int
    var currentLevel: Int
    var xpForCurrentLevel: Int  // XP within current level
    var xpForNextLevel: Int  // XP needed for next level
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade) var xpTransactions: [XPTransactionModel]
    @Relationship(deleteRule: .cascade) var achievements: [AchievementModel]
    
    // MARK: - Metadata
    var lastUpdated: Date
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        userId: String,
        totalXP: Int = 0,
        currentLevel: Int = 1
    ) {
        self.id = id
        self.userId = userId
        self.totalXP = totalXP
        self.currentLevel = currentLevel
        self.xpForCurrentLevel = 0
        self.xpForNextLevel = Self.xpRequiredForLevel(1)
        self.xpTransactions = []
        self.achievements = []
        self.lastUpdated = Date()
        
        updateLevelProgress()
    }
    
    // MARK: - Level Calculation
    static func xpRequiredForLevel(_ level: Int) -> Int {
        // Formula: 300 * (level)^2
        // Level 2: 300 XP
        // Level 3: 900 XP
        // Level 4: 1600 XP
        return 300 * level * level
    }
    
    static func calculateLevel(fromXP totalXP: Int) -> Int {
        var level = 1
        while totalXP >= xpRequiredForLevel(level) {
            level += 1
        }
        return level - 1
    }
    
    mutating func updateLevelProgress() {
        let newLevel = Self.calculateLevel(fromXP: totalXP)
        currentLevel = newLevel
        
        let currentLevelStartXP = Self.xpRequiredForLevel(newLevel - 1)
        let nextLevelStartXP = Self.xpRequiredForLevel(newLevel)
        
        xpForCurrentLevel = totalXP - currentLevelStartXP
        xpForNextLevel = nextLevelStartXP - currentLevelStartXP
        lastUpdated = Date()
    }
    
    // MARK: - XP Management
    mutating func addXP(_ amount: Int, reason: String) {
        totalXP += amount
        
        let transaction = XPTransactionModel(
            userId: userId,
            amount: amount,
            reason: reason,
            timestamp: Date()
        )
        xpTransactions.append(transaction)
        
        updateLevelProgress()
    }
    
    mutating func removeXP(_ amount: Int, reason: String) {
        totalXP = max(0, totalXP - amount)
        
        let transaction = XPTransactionModel(
            userId: userId,
            amount: -amount,
            reason: reason,
            timestamp: Date()
        )
        xpTransactions.append(transaction)
        
        updateLevelProgress()
    }
}

@Model
final class XPTransactionModel {
    @Attribute(.unique) var id: UUID
    var userId: String
    var amount: Int  // Can be positive or negative
    var reason: String
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        userId: String,
        amount: Int,
        reason: String,
        timestamp: Date
    ) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.reason = reason
        self.timestamp = timestamp
    }
}

@Model
final class AchievementModel {
    @Attribute(.unique) var id: UUID
    var userId: String
    var achievementId: String  // e.g., "first_habit", "week_streak"
    var title: String
    var description: String
    var unlockedAt: Date
    var xpAwarded: Int
    
    init(
        id: UUID = UUID(),
        userId: String,
        achievementId: String,
        title: String,
        description: String,
        unlockedAt: Date = Date(),
        xpAwarded: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.achievementId = achievementId
        self.title = title
        self.description = description
        self.unlockedAt = unlockedAt
        self.xpAwarded = xpAwarded
    }
}
```

---

### 5. ReminderModel (Supporting Model)

```swift
import Foundation
import SwiftData

@Model
final class ReminderModel {
    @Attribute(.unique) var id: UUID
    var time: Date
    var isActive: Bool
    var notificationIdentifier: String?
    
    init(
        id: UUID = UUID(),
        time: Date,
        isActive: Bool = true,
        notificationIdentifier: String? = nil
    ) {
        self.id = id
        self.time = time
        self.isActive = isActive
        self.notificationIdentifier = notificationIdentifier
    }
}
```

---

## 🗺️ Old Model → New Model Mapping

### OLD: HabitData / Habit → NEW: HabitModel

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `id` | `id` | Same |
| `userId` | `userId` | Same |
| `name` | `name` | Same |
| `habitDescription` | `habitDescription` | Same |
| `icon` | `icon` | Same |
| `color` / `colorData` | `colorData` | Same encoding |
| `habitType` | `habitType` | Same ("formation" or "breaking") |
| `schedule` (String) | `schedule` (Enum) | **PARSED** into typed enum |
| `goal` (String) | `goalCount` + `goalUnit` + `schedule` | **SPLIT** "5 times everyday" → count=5, unit="times", schedule=.daily |
| `baseline` | `baselineCount` | Same |
| `target` | `goalCount` | **RENAMED**: "target" was always the goal |
| `startDate` | `startDate` | Same |
| `endDate` | `endDate` | Same |
| `createdAt` | `createdAt` | Same |
| `reminders` | `reminders` → ReminderModel | Converted to relationship |
| **❌ REMOVED:** | | |
| `completionHistory` | → DailyProgressModel | Migrated to new model |
| `completionStatus` | → DailyProgressModel.isComplete | Computed property |
| `completionTimestamps` | → DailyProgressModel.timestamps | Migrated |
| `difficultyHistory` | → DailyProgressModel.difficulty | Migrated |
| `actualUsage` | → DailyProgressModel.progressCount | Unified |
| `isCompleted` | ❌ REMOVED | Was denormalized, now computed |
| `streak` | → GlobalStreakModel | Global, not per-habit |

### NEW: DailyProgressModel (No direct old equivalent)

This is a **NEW unified model** that consolidates:

| Old Source | Maps To | Notes |
|------------|---------|-------|
| `completionHistory[dateKey]` | `progressCount` | For formation habits |
| `actualUsage[dateKey]` | `progressCount` | For breaking habits |
| `completionStatus[dateKey]` | `isComplete` (computed) | No longer stored |
| `completionTimestamps[dateKey]` | `timestamps` | Same data, new structure |
| `difficultyHistory[dateKey]` | `difficulty` | Same data, new structure |
| Goal amount from `goal` string | `goalCount` | Copied from HabitModel for fast queries |

### NEW: GlobalStreakModel (Replaces per-habit streaks)

| Old Source | Maps To | Notes |
|------------|---------|-------|
| `habit.streak` (each habit) | → `currentStreak` (global) | **RECALCULATED** from ALL habits |
| Nothing (new) | `longestStreak` | **NEW**: Best streak ever |
| Nothing (new) | `totalCompleteDays` | **NEW**: Lifetime count |
| Nothing (new) | `lastCompleteDate` | **NEW**: For break detection |

**Migration Logic:**
- Calculate from scratch using all `completionHistory` data
- For each date, check if ALL scheduled habits were complete
- Count consecutive complete days

### OLD: UserProgress (XPManager) → NEW: UserProgressModel

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `userProgress.totalXP` | `totalXP` | Same |
| `userProgress.currentLevel` | `currentLevel` | Same |
| `userProgress.xpForCurrentLevel` | `xpForCurrentLevel` | Same |
| `userProgress.xpForNextLevel` | `xpForNextLevel` | Same |
| `recentTransactions` | `xpTransactions` | **PERSISTED** in SwiftData now |
| Nothing | `achievements` | **NEW**: Achievement tracking |

---

## 🔄 Data Flow Examples

### Example 1: User Completes a Habit

**Old System (Current):**
```
User taps habit
→ habit.markCompleted(for: date)
→ Updates completionHistory[dateKey] += 1
→ Updates completionStatus[dateKey] = true (if goal met)
→ Saves entire Habit object
→ Triggers XPManager check (separate)
→ Triggers DailyAwardService (separate)
```

**New System (Proposed):**
```
User taps habit
→ Fetch DailyProgressModel for (habitId, date)
→ progress.increment(at: Date())
→ Check progress.isComplete
→ Save DailyProgressModel
→ Query ALL DailyProgress for today
→ If ALL complete:
    - Update GlobalStreakModel
    - Award XP via UserProgressModel
    - Trigger celebration
```

**Benefits:**
- Single transaction per completion
- Clear separation: HabitModel (static) vs DailyProgressModel (dynamic)
- Easy to query today's progress without loading all habits

---

### Example 2: User Undoes a Completion

**Old System (Current):**
```
User taps undo
→ habit.markIncomplete(for: date)
→ Updates completionHistory[dateKey] -= 1
→ Updates completionStatus[dateKey] = false (if below goal)
→ Saves entire Habit object
→ ❌ NO automatic reward reversal
```

**New System (Proposed):**
```
User taps undo
→ Fetch DailyProgressModel for (habitId, date)
→ progress.decrement()
→ Check if day WAS complete before
→ Check if day is STILL complete after
→ If day became incomplete:
    - Revert GlobalStreakModel.currentStreak
    - Remove XP via UserProgressModel.removeXP()
    - Hide celebration
→ Save DailyProgressModel
```

**Benefits:**
- Automatic reward reversal
- Transactional integrity
- Can detect "day state change"

---

### Example 3: Progress Tab Loads Weekly Stats

**Old System (Current):**
```
Load all Habits
→ For each habit:
    - Iterate through completionHistory
    - Check completionStatus for each date
→ Calculate completion rate manually
→ Parse goal strings for each habit
→ Heavy computation
```

**New System (Proposed):**
```sql
-- SwiftData query equivalent
SELECT 
    dateString,
    COUNT(*) as totalScheduled,
    SUM(CASE WHEN progressCount >= goalCount THEN 1 ELSE 0 END) as completed
FROM DailyProgressModel
WHERE date >= startOfWeek AND date <= endOfWeek
GROUP BY dateString
```

**Benefits:**
- Single efficient query
- No habit iteration needed
- Database does the aggregation
- Indexed on date for speed

---

## 📊 Analytics Query Examples

### Query 1: Today's Completion Rate

```swift
// Get all progress for today
let today = Calendar.current.startOfDay(for: Date())
let predicate = #Predicate<DailyProgressModel> { progress in
    progress.date == today
}

let progressRecords = try modelContext.fetch(FetchDescriptor(predicate: predicate))

let total = progressRecords.count
let completed = progressRecords.filter { $0.isComplete }.count
let completionRate = Double(completed) / Double(total)
```

### Query 2: Weekly Completion Trend

```swift
let weekStart = Calendar.current.startOfWeek(for: Date())
let weekEnd = Calendar.current.endOfWeek(for: Date())

let predicate = #Predicate<DailyProgressModel> { progress in
    progress.date >= weekStart && progress.date <= weekEnd
}

let weekProgress = try modelContext.fetch(FetchDescriptor(predicate: predicate))

// Group by date
let byDate = Dictionary(grouping: weekProgress) { $0.dateString }
let dailyRates = byDate.mapValues { records in
    Double(records.filter { $0.isComplete }.count) / Double(records.count)
}
```

### Query 3: Struggling Habits (< 50% completion)

```swift
// Get all unique habits from progress records
let allProgress = try modelContext.fetch(FetchDescriptor<DailyProgressModel>())

let byHabit = Dictionary(grouping: allProgress) { $0.habit?.id ?? UUID() }

let strugglingHabits = byHabit.compactMap { (habitId, records) -> (HabitModel, Double)? in
    guard let habit = records.first?.habit else { return nil }
    
    let completionRate = Double(records.filter { $0.isComplete }.count) / Double(records.count)
    
    if completionRate < 0.5 {
        return (habit, completionRate)
    }
    return nil
}
```

---

## 🔗 Relationships Diagram

```
UserProgressModel (1)
    ├─ xpTransactions (many) → XPTransactionModel
    └─ achievements (many) → AchievementModel

GlobalStreakModel (1 per user)
    └─ No relationships (independent)

HabitModel (many)
    ├─ reminders (many) → ReminderModel
    └─ progressRecords (many) → DailyProgressModel

DailyProgressModel (many)
    └─ habit (1) → HabitModel (inverse relationship)
```

---

## 🗄️ SwiftData Schema

```swift
import SwiftData

let schema = Schema([
    HabitModel.self,
    DailyProgressModel.self,
    GlobalStreakModel.self,
    UserProgressModel.self,
    XPTransactionModel.self,
    AchievementModel.self,
    ReminderModel.self
])

let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    groupContainer: .identifier("group.com.habitto.app")
)

let modelContainer = ModelContainer(
    for: schema,
    configurations: [modelConfiguration]
)
```

---

## 📈 Performance Indexes

```swift
// Add these indexes for optimal query performance:

// DailyProgressModel
@Index([\.dateString, \.habit])  // For date range + habit queries
@Index([\.date])  // For date range queries
@Index([\.habit])  // For per-habit queries

// GlobalStreakModel
@Index([\.userId])  // For user lookup

// UserProgressModel
@Index([\.userId])  // For user lookup

// HabitModel
@Index([\.userId, \.startDate])  // For user's active habits
```

---

## ✅ Validation Rules

### HabitModel Validation:
- `name` must not be empty
- `goalCount` must be > 0
- `goalUnit` must not be empty
- `startDate` <= `endDate` (if endDate exists)
- For breaking habits: `baselineCount` must be > `goalCount`

### DailyProgressModel Validation:
- `progressCount` >= 0
- `goalCount` > 0
- `difficulty` must be 1-5 (if set)
- `dateString` must match `date` (yyyy-MM-dd format)

### GlobalStreakModel Validation:
- `currentStreak` >= 0
- `longestStreak` >= `currentStreak`
- `totalCompleteDays` >= 0
- If `currentStreak` > 0, then `lastCompleteDate` must exist

### UserProgressModel Validation:
- `totalXP` >= 0
- `currentLevel` >= 1
- `totalXP` must match sum of `xpTransactions`

---

## 🚀 Migration Strategy

### Phase 1A: Create New Schema

1. Add all new models to SwiftData schema
2. Create migration version
3. Deploy to TestFlight (new users only)
4. Verify no crashes

### Phase 1B: Dual-Write Mode

1. When user completes habit:
   - Write to OLD system (completionHistory)
   - Write to NEW system (DailyProgressModel)
2. Read from OLD system (for now)
3. Log any data mismatches
4. Run for 1 week on TestFlight

### Phase 2: Data Migration Script

```swift
func migrateAllHabitsToNewSystem(modelContext: ModelContext) async throws {
    print("🔄 Starting migration to new data system...")
    
    // 1. Load all old habits
    let oldHabits = Habit.loadHabits()
    
    // 2. For each habit, create HabitModel + DailyProgressModels
    for oldHabit in oldHabits {
        // Create new HabitModel
        let newHabit = try await migrateHabit(oldHabit, context: modelContext)
        
        // Migrate all completion history
        for (dateKey, count) in oldHabit.completionHistory {
            try await migrateDailyProgress(
                habitId: newHabit.id,
                dateKey: dateKey,
                count: count,
                oldHabit: oldHabit,
                context: modelContext
            )
        }
    }
    
    // 3. Calculate global streak from scratch
    try await recalculateGlobalStreak(modelContext: modelContext)
    
    // 4. Migrate XP data
    try await migrateUserProgress(modelContext: modelContext)
    
    print("✅ Migration complete!")
}
```

### Phase 3: Switch Reads

1. Update all read queries to use NEW system
2. Keep dual-write for safety
3. Monitor for issues
4. Run for 1 week

### Phase 4: Cleanup

1. Stop writing to OLD system
2. Mark old fields as deprecated
3. Remove old code in next major version
4. Celebrate! 🎉

---

## 🎯 Benefits of New Architecture

| Aspect | Old System | New System |
|--------|------------|------------|
| **Progress Storage** | 3 dictionaries per habit | 1 table for all habits |
| **Completion Check** | Parse string, check multiple fields | Simple: `progress.isComplete` |
| **Streak Calculation** | Per-habit, inconsistent | Global, single source of truth |
| **Analytics Queries** | Load all habits, iterate | Direct SQL-like queries |
| **Undo Support** | Manual, error-prone | Automatic reward reversal |
| **Data Consistency** | Multiple fields can desync | Single record, atomic updates |
| **Frequency Schedules** | Broken (consecutive days) | Fixed (flexible selection) |
| **Habit Breaking** | Confusing (actualUsage vs completionHistory) | Unified (progressCount) |
| **Migration** | Difficult (denormalized data) | Clean (normalized structure) |
| **Testing** | Hard to mock | Easy to inject ModelContext |

---

## ❓ Questions for Review

Before we proceed to implementation:

1. **Schedule Enum**: Should we add more schedule types (e.g., "first Monday of month")?
2. **Difficulty Scale**: Keep 1-5 or change to 1-10?
3. **XP Formula**: Confirm level formula (300 * level^2)?
4. **Migration Timing**: Should we delete old data after successful migration, or keep for rollback?
5. **Indexes**: Any additional query patterns we should optimize for?

---

## 📝 Next Steps

Once this design is approved:

1. ✅ Create new SwiftData models (this document)
2. Write migration script
3. Create repository layer for new models
4. Update UI to read from new models
5. Implement dual-write mode
6. Test migration on sample data
7. Deploy to TestFlight
8. Monitor and iterate

---

**Ready to proceed with implementation? Let's review this design first!**

