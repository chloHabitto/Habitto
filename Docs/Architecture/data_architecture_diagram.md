# Habitto Data Architecture Analysis

## Overview
The Habitto app uses a hybrid data architecture combining multiple storage systems and models to manage habit tracking, user progress, XP/leveling, and achievements.

## Data Architecture Diagram

```mermaid
graph TB
    %% User Interface Layer
    subgraph "UI Layer"
        HomeView[HomeView]
        HabitEditView[HabitEditView]
        HabitCard[HabitCard]
        CompletionSheet[CompletionSheet]
    end

    %% State Management Layer
    subgraph "State Management"
        HomeViewState[HomeViewState]
        CompletionStateManager[CompletionStateManager]
        VacationManager[VacationManager]
    end

    %% Repository Layer
    subgraph "Repository Layer"
        HabitRepository[HabitRepository]
        HabitRepositoryNew[HabitRepositoryNew]
        HabitRepositoryImpl[HabitRepositoryImpl]
        HabitStore[HabitStore Actor]
    end

    %% Core Data Models
    subgraph "Core Models (Structs)"
        Habit[Habit Struct<br/>- id: UUID<br/>- name: String<br/>- completionHistory: [String: Int]<br/>- streak: Int<br/>- isCompleted: Bool<br/>- difficultyHistory: [String: Int]<br/>- actualUsage: [String: Int]]
        UserProgress[UserProgress<br/>- totalXP: Int<br/>- currentLevel: Int<br/>- dailyXP: Int<br/>- achievements: [Achievement]]
        HabitProgress[HabitProgress<br/>- habit: Habit<br/>- completionPercentage: Double<br/>- status: HabitStatus]
        Achievement[Achievement<br/>- title: String<br/>- xpReward: Int<br/>- requirement: AchievementRequirement<br/>- progress: Int]
        XPTransaction[XPTransaction<br/>- amount: Int<br/>- reason: XPRewardReason<br/>- timestamp: Date]
    end

    %% SwiftData Models
    subgraph "SwiftData Models"
        HabitData[HabitData @Model<br/>- id: UUID @Attribute(.unique)<br/>- userId: String<br/>- name: String<br/>- isCompleted: Bool ⚠️ DENORMALIZED<br/>- streak: Int ⚠️ DENORMALIZED]
        CompletionRecord[CompletionRecord @Model<br/>- date: Date<br/>- isCompleted: Bool]
        DifficultyRecord[DifficultyRecord @Model<br/>- date: Date<br/>- difficulty: Int]
        UsageRecord[UsageRecord @Model<br/>- key: String<br/>- value: Int]
        DailyAward[DailyAward @Model<br/>- id: UUID @Attribute(.unique)<br/>- userId: String<br/>- dateKey: String<br/>- xpGranted: Int]
        HabitNote[HabitNote @Model<br/>- content: String<br/>- createdAt: Date]
    end

    %% Services & Managers
    subgraph "Services & Managers"
        XPManager[XPManager<br/>- userProgress: UserProgress<br/>- recentTransactions: [XPTransaction]<br/>- updateXPFromDailyAward()]
        DailyAwardService[DailyAwardService<br/>- grantIfAllComplete()<br/>- revokeIfAnyIncomplete()]
        AchievementManager[AchievementManager<br/>- achievements: [Achievement]<br/>- trackHabitCompletion()]
        StreakDataCalculator[StreakDataCalculator<br/>- calculateBestStreakFromHistory()<br/>- calculateStreakStatistics()]
        DataValidationService[DataValidationService<br/>- validateHabit()<br/>- validateHabits()]
    end

    %% Storage Layer
    subgraph "Storage Layer"
        UserDefaultsStorage[UserDefaultsStorage<br/>- Habit Storage<br/>- XP Data<br/>- User Preferences]
        SwiftDataStorage[SwiftDataStorage<br/>- HabitData<br/>- DailyAward<br/>- CompletionRecord]
        CloudKitStorage[CloudKitStorage<br/>- Cloud Sync<br/>- Conflict Resolution]
        OptimizedHabitStorageManager[OptimizedHabitStorageManager<br/>- Performance Optimization<br/>- Debounced Saves]
    end

    %% Data Flow Connections
    HomeView --> HomeViewState
    HomeViewState --> HabitRepository
    HabitRepository --> HabitStore
    HabitStore --> UserDefaultsStorage
    HabitStore --> SwiftDataStorage
    
    %% Model Relationships
    HabitData -->|1:many| CompletionRecord
    HabitData -->|1:many| DifficultyRecord
    HabitData -->|1:many| UsageRecord
    HabitData -->|1:many| HabitNote
    
    %% XP & Award Flow
    HabitRepository --> XPManager
    XPManager --> DailyAwardService
    DailyAwardService --> DailyAward
    XPManager --> UserProgress
    AchievementManager --> Achievement
    
    %% Completion Flow
    CompletionSheet --> CompletionStateManager
    CompletionStateManager --> HabitRepository
    HabitRepository --> StreakDataCalculator
    
    %% Data Conversion
    HabitData -.->|toHabit()| Habit
    Habit -.->|updateFromHabit()| HabitData
```

## Key Relationships

### 1. Core Habit Model
- **Habit (Struct)**: Primary model stored in UserDefaults
  - Contains: `completionHistory: [String: Int]` (date -> completion count)
  - Contains: `streak: Int` (denormalized, computed from completion history)
  - Contains: `difficultyHistory: [String: Int]` (date -> difficulty 1-10)
  - Contains: `actualUsage: [String: Int]` (for habit breaking)

### 2. SwiftData Models
- **HabitData**: SwiftData version with relationships
  - `@Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]`
  - `@Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]`
  - `@Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]`
  - **⚠️ WARNING**: `isCompleted` and `streak` are denormalized fields that must be kept in sync

### 3. XP & Leveling System
- **UserProgress**: Contains total XP, current level, daily XP
- **DailyAward**: SwiftData model tracking daily XP grants (50 XP per day)
- **XPTransaction**: Log of all XP changes with reasons
- **Achievement**: Progress tracking for various achievements

### 4. Data Flow Architecture

#### Habit Completion Flow:
1. **UI**: `CompletionSheet` → `HomeViewState.toggleHabitCompletion()`
2. **Repository**: `HabitRepository` → `HabitStore.updateProgress()`
3. **Storage**: Updates both UserDefaults and SwiftData
4. **XP**: `DailyAwardService.grantIfAllComplete()` → `XPManager.updateXPFromDailyAward()`
5. **Achievements**: `AchievementManager.trackHabitCompletion()`
6. **Streaks**: `StreakDataCalculator.calculateBestStreakFromHistory()`

## Data Storage Strategy

### Dual Storage System
- **UserDefaults**: Primary storage for Habit structs (legacy compatibility)
- **SwiftData**: Modern storage with relationships and CloudKit sync
- **Migration**: Ongoing migration from UserDefaults to SwiftData

### Performance Optimizations
- **OptimizedHabitStorageManager**: Debounced saves (0.5s interval)
- **Cache Management**: StreakDataCalculator uses caching for expensive operations
- **Denormalized Fields**: Cached `isCompleted` and `streak` for performance

## Critical Issues Identified

### 1. Data Consistency Issues
- **Denormalized Fields**: `isCompleted` and `streak` in HabitData are cached and can become inconsistent
- **Dual Storage**: Same data stored in both UserDefaults and SwiftData can diverge
- **Migration State**: App is in transition between storage systems

### 2. XP System Complexity
- **Multiple XP Sources**: XPManager, DailyAwardService, and AchievementManager all handle XP
- **Duplicate Prevention**: Complex logic to prevent double-awarding XP
- **User Scoping**: XP data needs proper user isolation for multi-user support

### 3. Relationship Modeling Issues
- **Missing Foreign Keys**: HabitData doesn't have explicit relationships to DailyAward
- **User Isolation**: SwiftData models need better user scoping
- **Completion History**: Stored as both dictionary (struct) and relationships (SwiftData)

## Detailed Model Analysis

### Core Models & Properties

#### Habit Struct (Primary Model)
```swift
struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: Color
    let habitType: HabitType
    let schedule: String
    let goal: String
    let reminder: String
    let reminders: [ReminderItem]
    let startDate: Date
    let endDate: Date?
    var isCompleted: Bool = false
    var streak: Int = 0
    let createdAt: Date
    var completionHistory: [String: Int] = [:] // "yyyy-MM-dd" -> completion count
    var completionTimestamps: [String: [Date]] = [:] // "yyyy-MM-dd" -> [completion_times]
    var difficultyHistory: [String: Int] = [:] // "yyyy-MM-dd" -> difficulty (1-10)
    
    // Habit Breaking specific
    var baseline: Int = 0
    var target: Int = 0
    var actualUsage: [String: Int] = [:] // "yyyy-MM-dd" -> usage amount
}
```

#### HabitData SwiftData Model
```swift
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data
    var habitType: String
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool // ⚠️ DENORMALIZED
    var streak: Int // ⚠️ DENORMALIZED
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
}
```

#### DailyAward SwiftData Model
```swift
@Model
public class DailyAward {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var dateKey: String
    public var xpGranted: Int
    public var createdAt: Date
}
```

#### UserProgress Model
```swift
struct UserProgress: Codable, Identifiable {
    let id: UUID
    var userId: String?
    var totalXP: Int = 0
    var currentLevel: Int = 1
    var xpForCurrentLevel: Int = 0
    var xpForNextLevel: Int = 300
    var dailyXP: Int = 0
    var lastCompletedDate: Date?
    var streakDays: Int = 0
    var achievements: [Achievement] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
```

## Critical Issues & Missing Relationships

### 1. **Missing Foreign Key Relationships**
- **Issue**: `DailyAward` has no explicit relationship to `HabitData`
- **Problem**: Cannot query "which habits contributed to this daily award"
- **Impact**: Difficult to track XP attribution and debugging
- **Fix**: Add `@Relationship var habits: [HabitData]` to DailyAward

### 2. **Denormalized Field Inconsistency**
- **Issue**: `isCompleted` and `streak` in HabitData are cached/denormalized
- **Problem**: These can become inconsistent with actual completion history
- **Impact**: UI shows incorrect completion status, streaks are wrong
- **Fix**: Remove denormalized fields or implement automatic sync

### 3. **Dual Storage Data Divergence**
- **Issue**: Same habit data stored in both UserDefaults (Habit struct) and SwiftData (HabitData)
- **Problem**: Data can become inconsistent between storage systems
- **Impact**: Migration issues, data loss, inconsistent behavior
- **Fix**: Complete migration to SwiftData, remove UserDefaults storage

### 4. **User Isolation Problems**
- **Issue**: Not all models properly implement user scoping
- **Problem**: Data mixing between users, security issues
- **Impact**: User data leakage, incorrect XP attribution
- **Fix**: Add `userId` to all models, implement proper user filtering

### 5. **XP System Complexity**
- **Issue**: Multiple XP management systems (XPManager, DailyAwardService, AchievementManager)
- **Problem**: Duplicate XP awards, complex state management
- **Impact**: Users getting incorrect XP, level progression issues
- **Fix**: Centralize through DailyAwardService only

### 6. **Completion History Duplication**
- **Issue**: Completion data stored as both dictionary (Habit) and relationships (HabitData)
- **Problem**: Data synchronization issues, performance problems
- **Impact**: Inconsistent completion tracking, migration difficulties
- **Fix**: Use only relationship-based storage

### 7. **Missing Validation Rules**
- **Issue**: No comprehensive data validation
- **Problem**: Invalid data can be stored (negative streaks, impossible XP values)
- **Impact**: App crashes, incorrect calculations
- **Fix**: Implement comprehensive validation in DataValidationService

### 8. **Achievement Progress Tracking**
- **Issue**: Achievement progress not properly linked to habit completion
- **Problem**: Achievements may not trigger correctly
- **Impact**: Users don't get achievement rewards
- **Fix**: Add proper relationships between Achievement and HabitData

## Habit Completion Data Flow

### Current Flow:
1. **UI**: `CompletionSheet` → `HomeViewState.toggleHabitCompletion()`
2. **Repository**: `HabitRepository` → `HabitStore.updateProgress()`
3. **Storage**: Updates `completionHistory` in Habit struct
4. **Streak**: `updateStreakWithReset()` recalculates streak
5. **XP**: `DailyAwardService.grantIfAllComplete()` checks if all habits complete
6. **Award**: Creates `DailyAward` record with 50 XP
7. **Update**: `XPManager.updateXPFromDailyAward()` updates UserProgress
8. **Achievement**: `AchievementManager.trackHabitCompletion()` updates achievements

### Issues in Current Flow:
- **Step 3**: Updates struct but not SwiftData relationships
- **Step 5**: Checks struct data, not SwiftData relationships
- **Step 6**: Creates award without linking to specific habits
- **Step 7**: Updates UserDefaults, not SwiftData

## Recommendations

### 1. **Immediate Fixes**
- Add explicit relationships between `HabitData` and `DailyAward`
- Implement automatic sync for denormalized fields
- Add comprehensive data validation rules
- Fix user isolation across all models

### 2. **Architecture Improvements**
- Complete migration to SwiftData as primary storage
- Remove UserDefaults storage for habit data
- Centralize XP management through DailyAwardService
- Implement proper data consistency checks

### 3. **Performance Optimizations**
- Remove dual storage to eliminate sync overhead
- Use SwiftData relationships instead of dictionary lookups
- Implement proper caching for expensive operations
- Add background processing for streak calculations

### 4. **Data Integrity**
- Add runtime consistency validation
- Implement data repair utilities
- Add comprehensive error handling
- Create data migration scripts
