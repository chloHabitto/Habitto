# Write-Path Audit for XP/Level/Streak/Completion

## XP Mutations

### 1. XPManager.swift - Multiple XP Write Paths
**File**: `Core/Managers/XPManager.swift`

#### Line 151-152: Direct XP Mutation
```swift
userProgress.totalXP += amount
userProgress.dailyXP += amount
```
**Classification**: [DUPLICATE write] - Debug method that bypasses DailyAwardService

#### Line 368: Private addXP Method
```swift
private func addXP(_ amount: Int, reason: XPRewardReason, description: String) {
    // Add XP
    userProgress.totalXP += amount
    userProgress.dailyXP += amount
```
**Classification**: [DUPLICATE write] - Deprecated method that should not be called

#### Line 92: Award XP for All Habits
```swift
addXP(totalXP, reason: .completeAllHabits, description: "Completed all habits")
```
**Classification**: [DUPLICATE write] - Deprecated method that causes duplicate XP

#### Line 115-121: Update XP from DailyAward
```swift
func updateXPFromDailyAward(xpGranted: Int, dateKey: String) {
    userProgress.totalXP += xpGranted
    userProgress.dailyXP += xpGranted
```
**Classification**: [OK single source via DailyAwardService] - This is the correct path

### 2. DailyAwardService.swift - XP Management
**File**: `Core/Services/DailyAwardService.swift`

#### Line 115-121: Update XPManager
```swift
await MainActor.run {
    XPManager.shared.updateXPFromDailyAward(xpGranted: Self.XP_PER_DAY, dateKey: dateKey)
}
```
**Classification**: [OK single source via DailyAwardService] - Centralized XP management

#### Line 201-207: Revoke XP
```swift
await MainActor.run {
    XPManager.shared.updateXPFromDailyAward(xpGranted: -Self.XP_PER_DAY, dateKey: dateKey)
}
```
**Classification**: [OK single source via DailyAwardService] - Centralized XP revocation

## Level Mutations

### 1. XPManager.swift - Level Updates
**File**: `Core/Managers/XPManager.swift`

#### Line 52-56: Update Level from XP
```swift
func updateLevelFromXP() {
    let calculatedLevel = level(forXP: userProgress.totalXP)
    userProgress.currentLevel = max(1, calculatedLevel)
    updateLevelProgress()
}
```
**Classification**: [OK single source via DailyAwardService] - Called from updateXPFromDailyAward

#### Line 437-444: Update Level Progress
```swift
private func updateLevelProgress() {
    let currentLevel = userProgress.currentLevel
    let currentLevelStartXP = Int(pow(Double(currentLevel - 1), 2) * Double(levelBaseXP))
    let nextLevelStartXP = Int(pow(Double(currentLevel), 2) * Double(levelBaseXP))
```
**Classification**: [OK single source via DailyAwardService] - Called from updateLevelFromXP

## Streak Mutations

### 1. Habit.swift - Streak Updates
**File**: `Core/Models/Habit.swift`

#### Line 407-423: Update Streak with Reset
```swift
mutating func updateStreakWithReset() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let vacationManager = VacationManager.shared
    
    let oldStreak = streak
    
    // If today is a vacation day AND vacation is active, preserve the current streak
    if vacationManager.isActive && vacationManager.isVacationDay(today) {
        print("🔍 STREAK UPDATE DEBUG - Habit '\(name)': Vacation day, preserving streak=\(streak)")
        return
    }
    
    // Use the same logic as calculateTrueStreak() to ensure consistency
    streak = calculateTrueStreak()
```
**Classification**: [DENORMALIZED write] - Updates denormalized streak field

#### Line 441-443: Correct Streak
```swift
mutating func correctStreak() {
    streak = calculateTrueStreak()
}
```
**Classification**: [DENORMALIZED write] - Updates denormalized streak field

#### Line 450-451: Recalculate Completion Status
```swift
mutating func recalculateCompletionStatus() {
    isCompleted = isCompleted(for: today)
```
**Classification**: [DENORMALIZED write] - Updates denormalized isCompleted field

### 2. HabitRepository.swift - Streak Updates
**File**: `Core/Data/HabitRepository.swift`

#### Line 659: Update Streak After Progress Change
```swift
habits[index].updateStreakWithReset()
```
**Classification**: [DENORMALIZED write] - Updates denormalized streak field

#### Line 691: Update Streak After Revert
```swift
self.habits[index].updateStreakWithReset()
```
**Classification**: [DENORMALIZED write] - Updates denormalized streak field

### 3. HabitStore.swift - Streak Updates
**File**: `Core/Data/Repository/HabitStore.swift`

#### Line 401: Update Streak After Progress Change
```swift
currentHabits[index].updateStreakWithReset()
```
**Classification**: [DENORMALIZED write] - Updates denormalized streak field

## Completion Mutations

### 1. Habit.swift - Completion History
**File**: `Core/Models/Habit.swift`

#### Line 223-240: Mark Completed
```swift
mutating func markCompleted(for date: Date, at timestamp: Date = Date()) {
    let dateKey = Self.dateKey(for: date)
    let currentProgress = completionHistory[dateKey] ?? 0
    completionHistory[dateKey] = currentProgress + 1
    
    // Store the actual completion timestamp
    if completionTimestamps[dateKey] == nil {
        completionTimestamps[dateKey] = []
    }
    completionTimestamps[dateKey]?.append(timestamp)
    
    updateCurrentCompletionStatus()
    
    // Update streak after completion
    updateStreakWithReset()
```
**Classification**: [DENORMALIZED write] - Updates completion history and denormalized fields

#### Line 257-271: Mark Incomplete
```swift
mutating func markIncomplete(for date: Date) {
    let dateKey = Self.dateKey(for: date)
    let currentProgress = completionHistory[dateKey] ?? 0
    completionHistory[dateKey] = max(0, currentProgress - 1)
    
    // Remove the most recent timestamp if there are any
    if completionTimestamps[dateKey]?.isEmpty == false {
        completionTimestamps[dateKey]?.removeLast()
    }
    
    updateCurrentCompletionStatus()
    
    // Update streak after completion change
    updateStreakWithReset()
}
```
**Classification**: [DENORMALIZED write] - Updates completion history and denormalized fields

### 2. HabitRepository.swift - Completion Updates
**File**: `Core/Data/HabitRepository.swift`

#### Line 650-655: Update Progress
```swift
habits[index].completionHistory[dateKey] = progress
habits[index].completionTimestamps[dateKey] = completionTimestamps
habits[index].difficultyHistory[dateKey] = difficulty
```
**Classification**: [DENORMALIZED write] - Updates completion history directly

### 3. HabitStore.swift - Completion Updates
**File**: `Core/Data/Repository/HabitStore.swift`

#### Line 374-398: Update Progress with Timestamps
```swift
currentHabits[index].completionHistory[dateKey] = progress

// Handle timestamp recording for time-based completion analysis
let currentTimestamp = Date()
if progress > oldProgress {
    // Progress increased - record new completion timestamp
    if currentHabits[index].completionTimestamps[dateKey] == nil {
        currentHabits[index].completionTimestamps[dateKey] = []
    }
    let newCompletions = progress - oldProgress
    for _ in 0..<newCompletions {
        currentHabits[index].completionTimestamps[dateKey]?.append(currentTimestamp)
    }
```
**Classification**: [DENORMALIZED write] - Updates completion history directly

## Write Path Classification Summary

| Path | Classification | Issue |
|------|---------------|-------|
| XPManager.debugForceAwardXP | [DUPLICATE write] | Bypasses DailyAwardService |
| XPManager.addXP (private) | [DUPLICATE write] | Deprecated method |
| XPManager.awardXPForAllHabitsCompleted | [DUPLICATE write] | Deprecated method |
| XPManager.updateXPFromDailyAward | [OK single source via DailyAwardService] | ✅ Correct path |
| DailyAwardService.grantIfAllComplete | [OK single source via DailyAwardService] | ✅ Correct path |
| DailyAwardService.revokeIfAnyIncomplete | [OK single source via DailyAwardService] | ✅ Correct path |
| Habit.updateStreakWithReset | [DENORMALIZED write] | Updates denormalized field |
| Habit.correctStreak | [DENORMALIZED write] | Updates denormalized field |
| Habit.recalculateCompletionStatus | [DENORMALIZED write] | Updates denormalized field |
| Habit.markCompleted | [DENORMALIZED write] | Updates completion history + denormalized |
| Habit.markIncomplete | [DENORMALIZED write] | Updates completion history + denormalized |
| HabitRepository.updateProgress | [DENORMALIZED write] | Updates completion history directly |
| HabitStore.updateProgress | [DENORMALIZED write] | Updates completion history directly |

## Critical Issues Found

1. **Multiple XP Write Paths**: 3 duplicate write paths that bypass DailyAwardService
2. **Denormalized Field Updates**: Multiple paths update `isCompleted` and `streak` fields
3. **Direct Completion History Updates**: Completion history updated directly without proper relationships
4. **No User Scoping**: All mutations lack proper user isolation
5. **Inconsistent State**: Denormalized fields can become inconsistent with source data

## Items to Delete/Route Later

### Delete These Methods:
- `XPManager.debugForceAwardXP()` - Debug method that bypasses centralization
- `XPManager.addXP()` - Private method that should not exist
- `XPManager.awardXPForAllHabitsCompleted()` - Deprecated duplicate method

### Route These Through DailyAwardService:
- All habit completion updates should trigger `DailyAwardService.grantIfAllComplete()`
- All habit uncompletion updates should trigger `DailyAwardService.revokeIfAnyIncomplete()`

### Remove Denormalized Fields:
- `Habit.isCompleted` - Should be computed from completion history
- `Habit.streak` - Should be computed from completion history
- `HabitData.isCompleted` - Should be computed from CompletionRecord relationships
- `HabitData.streak` - Should be computed from CompletionRecord relationships

### Fix Completion History:
- Replace direct dictionary updates with proper SwiftData relationships
- Use CompletionRecord model instead of dictionary storage
- Ensure all completion updates go through proper repository methods
