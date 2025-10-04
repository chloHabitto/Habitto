# Source of Truth Statement

This document identifies the SINGLE source of truth classes for XP/level/streak/completion data in the Habitto codebase.

## XP and Level Management

### Primary Source of Truth: XPService
**File:** `Core/Services/XPService.swift:44-282`
**Class:** `XPService: XPServiceProtocol`
**Actor Isolation:** `@MainActor`

```swift
@MainActor
final class XPService: XPServiceProtocol {
    static let shared = XPService()
    
    // Protocol methods - ONLY allowed XP/level mutations
    func awardDailyCompletionIfEligible(userId: String, dateKey: String) async throws -> Int
    func revokeDailyCompletionIfIneligible(userId: String, dateKey: String) async throws -> Int
    func getUserProgress(userId: String) async throws -> UserProgress
    func getDailyAward(userId: String, dateKey: String) async throws -> DailyAward?
}
```

**Responsibilities:**
- ✅ **ONLY service allowed to mutate XP/level data**
- ✅ Awards daily completion XP when all habits completed
- ✅ Revokes XP when completion becomes ineligible
- ✅ Manages UserProgressData updates
- ✅ Enforces business rules and invariants

### Supporting Source of Truth: DailyAwardService
**File:** `Core/Services/DailyAwardService.swift:7-383`
**Class:** `DailyAwardService: ObservableObject`
**Actor Isolation:** `public actor`

```swift
public actor DailyAwardService: ObservableObject {
    // Idempotent method to grant daily award if all habits are completed
    public func grantIfAllComplete(date: Date, userId: String, callSite: String = #function) async -> Bool
    
    // Check if all habits are completed for a specific date
    private func areAllHabitsCompleted(dateKey: String, userId: String) async -> Bool
    
    // Compute total XP from daily awards ledger
    public func computeTotalXPFromLedger(userId: String) -> Int
}
```

**Responsibilities:**
- ✅ **ONLY service allowed to create DailyAward records**
- ✅ Enforces idempotent daily award granting
- ✅ Validates all habits completion before awarding
- ✅ Maintains XP ledger integrity
- ✅ Prevents duplicate daily awards

## Completion Status Source of Truth

### Primary Source of Truth: CompletionRecord
**File:** `Core/Data/SwiftData/HabitDataModel.swift:195-231`
**Model:** `CompletionRecord`

```swift
@Model
final class CompletionRecord {
    var userId: String
    var habitId: UUID
    var date: Date
    var dateKey: String  // For date-based queries
    var isCompleted: Bool
    var createdAt: Date
    
    // Composite unique constraint to prevent duplicate completions
    @Attribute(.unique) var userIdHabitIdDateKey: String
}
```

**Source of Truth Methods:**
- **File:** `Core/Data/SwiftData/HabitDataModel.swift:136-159`
- **Method:** `HabitData.isCompletedForDate(_ date: Date) -> Bool`

```swift
/// Check if habit is completed for a specific date (source of truth)
func isCompletedForDate(_ date: Date) -> Bool {
    let dateKey = ISO8601DateHelper.shared.string(from: date)
    let completionRecord = completionHistory.first { record in
        ISO8601DateHelper.shared.string(from: record.date) == dateKey
    }
    return completionRecord?.isCompleted ?? false
}
```

**Responsibilities:**
- ✅ **ONLY authoritative source for completion status**
- ✅ Prevents duplicate completions via unique constraint
- ✅ User-scoped data isolation
- ✅ Date-based completion tracking

## Streak Calculation Source of Truth

### Primary Source of Truth: HabitData.calculateTrueStreak()
**File:** `Core/Data/SwiftData/HabitDataModel.swift:145-159`
**Method:** `calculateTrueStreak() -> Int`

```swift
/// Calculate true streak from completionHistory (source of truth)
func calculateTrueStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var streak = 0
    var currentDate = today
    
    // Count consecutive completed days backwards from today
    while isCompletedForDate(currentDate) {
        streak += 1
        currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
    }
    
    return streak
}
```

### Supporting Source of Truth: StreakDataCalculator
**File:** `Core/Data/StreakDataCalculator.swift:13-50`
**Class:** `StreakDataCalculator`

```swift
class StreakDataCalculator {
    /// Calculates the best streak from habit history, excluding vacation days
    static func calculateBestStreakFromHistory(for habit: Habit) -> Int
    
    /// Calculates current streak from habit history, excluding vacation days
    static func calculateCurrentStreakFromHistory(for habit: Habit) -> Int
}
```

**Responsibilities:**
- ✅ **ONLY authoritative source for streak calculations**
- ✅ Computes streaks from CompletionRecord history
- ✅ Handles vacation day exclusions
- ✅ Provides both current and best streak calculations

## User Progress Source of Truth

### Primary Source of Truth: UserProgressData
**File:** `Core/Models/UserProgressData.swift:7-97`
**Model:** `UserProgressData`

```swift
@Model
final class UserProgressData {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var userId: String  // One UserProgress per user
    var xpTotal: Int
    var level: Int
    var xpForCurrentLevel: Int
    var xpForNextLevel: Int
    var dailyXP: Int
    var lastCompletedDate: Date?
    var streakDays: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var achievements: [AchievementData]
}
```

**Responsibilities:**
- ✅ **ONLY authoritative source for user XP/level data**
- ✅ Single progress record per user (unique userId)
- ✅ Manages level progression calculations
- ✅ Tracks daily XP and streak days

## Forbidden Mutations

### ❌ DEPRECATED: Direct XP/Level Mutations
**File:** `Core/Models/UserProgress.swift` (Legacy struct)
**Status:** Deprecated - use `UserProgressData` and `XPService` instead

### ❌ FORBIDDEN: Direct Streak Mutations
**File:** `Core/Data/SwiftData/HabitDataModel.swift:124-134`
**Status:** Computed properties only - no direct mutations allowed

```swift
// MARK: - Computed Properties
/// Computed property for current completion status
var isCompleted: Bool {
    isCompletedForDate(Date())
}

/// Computed property for current streak
var streak: Int {
    calculateTrueStreak()
}
```

## Enforcement Mechanisms

### 1. CI Invariant Script
**File:** `Scripts/forbid_mutations.sh`
**Purpose:** Prevents direct XP/level/streak mutations outside designated services

### 2. Actor Isolation
- **XPService:** `@MainActor` isolation
- **DailyAwardService:** `public actor` isolation
- **HabitStore:** `final actor` isolation

### 3. Unique Constraints
- **DailyAward:** `@Attribute(.unique) var userIdDateKey: String`
- **CompletionRecord:** `@Attribute(.unique) var userIdHabitIdDateKey: String`
- **UserProgressData:** `@Attribute(.unique) var userId: String`

## Summary

| Data Type | Source of Truth | File:Line | Mutations Allowed |
|-----------|----------------|-----------|-------------------|
| **XP/Level** | `XPService` | `Core/Services/XPService.swift:44-282` | ✅ Only via XPService |
| **Daily Awards** | `DailyAwardService` | `Core/Services/DailyAwardService.swift:7-383` | ✅ Only via DailyAwardService |
| **Completion Status** | `CompletionRecord` | `Core/Data/SwiftData/HabitDataModel.swift:195-231` | ✅ Only via relationship |
| **Streak Calculation** | `HabitData.calculateTrueStreak()` | `Core/Data/SwiftData/HabitDataModel.swift:145-159` | ❌ Computed only |
| **User Progress** | `UserProgressData` | `Core/Models/UserProgressData.swift:7-97` | ✅ Only via XPService |

**Key Principle:** All XP/level/streak/completion data flows through designated source-of-truth services that enforce business rules, prevent duplicates, and maintain data integrity.
