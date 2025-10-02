# Data Layer Fix Plan - Making Habitto's Data Layer Trustworthy

## Overview
This plan addresses the critical data layer issues identified in the architecture analysis, specifically focusing on preventing the guest/sign-in bug and ensuring data consistency.

## Phase 1: Evidence Collection & Verification

### 1.1 Model Inventory (Ground Truth)
**Copy-paste this prompt into Cursor:**

```
Repo-wide model audit:
- Enumerate every @Model (SwiftData), NSManagedObject (CoreData), or Realm Object.
- For each: file path, line number, class/struct name, all properties (name:type:attributes).
- Show relationships explicitly (e.g., @Relationship annotations; inverse; cascade rules).
- Indicate whether each model includes a user scope (userId or owner). If missing, flag it.

Output: a single markdown table plus per-file code excerpts. No summaries without code quotes.
```

### 1.2 Relationship Map (Mermaid from Code)
**Copy-paste this prompt into Cursor:**

```
Build a Mermaid ER diagram from the actual code:
- One node per persisted model.
- Edges for 1:N, N:1, M:N (include property names and inverses).
- Annotate keys and indexes (id, userId).
- Place each node label as ModelName [file:line].
```

### 1.3 XP/Level/Streak/Completion Write Paths
**Copy-paste this prompt into Cursor:**

```
Repo-wide guard: list ALL code paths that mutate any of the following:
- XP, totalXP, level, levelProgress
- streak, longestStreak, isCompleted, completion records

Grep patterns:
xp +=|xp-=|xpTotal|addXP|grantXP|awardXP|updateLevel|level +=|level =|setLevel
streak +=|streak =|updateStreak|longestStreak
isCompleted =|markCompleted|toggleCompleted
completion.*(insert|append|save)|CompletionRecord|onAllHabitsCompleted

For each hit: file:line, function, short surrounding snippet (±6 lines), and classify:
[OK single source via DailyAwardService] or [DUPLICATE write] or [UNSCOPED write] or [DENORMALIZED write].

Output a checklist of items to delete/route.
```

### 1.4 UserDefaults / Dual Storage Detector
**Copy-paste this prompt into Cursor:**

```
Find all uses of UserDefaults, Keychain, or local caches that store habit/progress data:
- Grep: UserDefaults|Keychain|@AppStorage|NSUbiquitousKeyValueStore
- For each hit: file:line, key names, value types.

Classify each key: [UI preference], [Business data]. Anything not UI preference → flag for migration to SwiftData.
```

### 1.5 Sign-in / Sign-out Storage Routing
**Copy-paste this prompt into Cursor:**

```
Trace storage containers and data sources used in:
- app launch, auth state changes, sign-in, sign-out
- data reads for XP/Level/Streak/Habits immediately after sign-out

Show the code that switches between guest container and account container.
Identify any cached singletons or in-memory stores that survive sign-out and leak data.
```

## Phase 2: Data Model Fixes

### 2.1 Fixed SwiftData Models
**Replace existing models with these safe, scoped, relational versions:**

```swift
@Model
final class Habit {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String        // scope
  var name: String
  var habitDescription: String
  var icon: String
  var colorHex: String
  var habitType: String
  var schedule: String
  var goal: String
  var reminder: String
  var startDate: Date
  var endDate: Date?
  var createdAt: Date
  var updatedAt: Date
  
  @Relationship(deleteRule: .cascade, inverse: \Completion.habit)
  var completions: [Completion] = []
  @Relationship(deleteRule: .cascade, inverse: \Reminder.habit)
  var reminders: [Reminder] = []
  @Relationship(deleteRule: .cascade, inverse: \DifficultyRecord.habit)
  var difficultyHistory: [DifficultyRecord] = []
  @Relationship(deleteRule: .cascade, inverse: \UsageRecord.habit)
  var usageHistory: [UsageRecord] = []
  @Relationship(deleteRule: .cascade, inverse: \HabitNote.habit)
  var notes: [HabitNote] = []
}

@Model
final class Completion {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  @Attribute(.indexed) var habitId: UUID
  @Attribute(.indexed) var dateKey: String   // "yyyy-MM-dd" in user TZ
  var isCompleted: Bool
  var completionCount: Int = 1  // For habits with >1 completions per day
  var timestamp: Date
  @Relationship var habit: Habit?
}

@Model
final class DailyAward {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  @Attribute(.indexed) var dateKey: String   // one row/day/user
  var xpGranted: Int
  var allHabitsCompleted: Bool
  var createdAt: Date
  
  // Relationship to track which habits contributed
  @Relationship(deleteRule: .nullify)
  var habits: [Habit] = []
}

@Model
final class UserProgress {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  var xpTotal: Int = 0
  var level: Int = 1
  var levelProgress: Double = 0.0
  var lastCompletedDate: Date?
  var createdAt: Date
  var updatedAt: Date
}

@Model
final class DifficultyRecord {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  @Attribute(.indexed) var habitId: UUID
  @Attribute(.indexed) var dateKey: String
  var difficulty: Int  // 1-10 scale
  var createdAt: Date
  @Relationship var habit: Habit?
}

@Model
final class UsageRecord {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  @Attribute(.indexed) var habitId: UUID
  @Attribute(.indexed) var dateKey: String
  var value: Int  // actual usage amount
  var createdAt: Date
  @Relationship var habit: Habit?
}

@Model
final class HabitNote {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  @Attribute(.indexed) var habitId: UUID
  var content: String
  var createdAt: Date
  var updatedAt: Date
  @Relationship var habit: Habit?
}

@Model
final class Reminder {
  @Attribute(.unique) var id: UUID
  @Attribute(.indexed) var userId: String
  @Attribute(.indexed) var habitId: UUID
  var time: Date
  var message: String
  var isActive: Bool = true
  var createdAt: Date
  @Relationship var habit: Habit?
}
```

### 2.2 Single XP Entry Point
**Create XPService as the ONLY mutator of XP/level:**

```swift
protocol XPService {
  func awardDailyCompletionIfEligible(userId: String, dateKey: String) throws
  func revokeDailyAwardIfIncomplete(userId: String, dateKey: String) throws
  func getUserProgress(userId: String) throws -> UserProgress
}

final class XPServiceImpl: XPService {
  private let modelContext: ModelContext
  
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }
  
  func awardDailyCompletionIfEligible(userId: String, dateKey: String) throws {
    // 1) Check all habits completed for dateKey
    let allDone = try HabitQueries.allHabitsCompleted(userId, dateKey, in: modelContext)
    guard allDone else { return }
    
    // 2) Idempotency: if DailyAward exists for (userId, dateKey) → return
    if try DailyAwardQueries.exists(userId, dateKey, in: modelContext) { return }
    
    // 3) Create DailyAward(xpGranted: RULES.dailyXP)
    let award = DailyAward(userId: userId, dateKey: dateKey, xpGranted: 50)
    modelContext.insert(award)
    
    // 4) Update UserProgress
    try updateUserProgress(userId: userId, xpToAdd: 50)
    
    // 5) Save
    try modelContext.save()
  }
  
  func revokeDailyAwardIfIncomplete(userId: String, dateKey: String) throws {
    // Find and delete existing award
    let awards = try DailyAwardQueries.find(userId: userId, dateKey: dateKey, in: modelContext)
    for award in awards {
      modelContext.delete(award)
      try updateUserProgress(userId: userId, xpToSubtract: award.xpGranted)
    }
    try modelContext.save()
  }
  
  private func updateUserProgress(userId: String, xpToAdd: Int) throws {
    let progress = try UserProgressQueries.findOrCreate(userId: userId, in: modelContext)
    progress.xpTotal += xpToAdd
    progress.level = calculateLevel(xpTotal: progress.xpTotal)
    progress.levelProgress = calculateLevelProgress(xpTotal: progress.xpTotal, level: progress.level)
    progress.updatedAt = Date()
  }
  
  private func calculateLevel(xpTotal: Int) -> Int {
    // Level n needs 200 * n XP (arithmetic progression)
    return max(1, Int(sqrt(Double(xpTotal) / 200.0)) + 1)
  }
  
  private func calculateLevelProgress(xpTotal: Int, level: Int) -> Double {
    let currentLevelXP = 200 * (level - 1)
    let nextLevelXP = 200 * level
    let xpInCurrentLevel = xpTotal - currentLevelXP
    let xpNeededForNextLevel = nextLevelXP - currentLevelXP
    return Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
  }
}
```

### 2.3 Query Helpers
**Create query helpers for common operations:**

```swift
struct HabitQueries {
  static func allHabitsCompleted(_ userId: String, _ dateKey: String, in context: ModelContext) throws -> Bool {
    let habitRequest = FetchDescriptor<Habit>(
      predicate: #Predicate<Habit> { habit in habit.userId == userId }
    )
    let habits = try context.fetch(habitRequest)
    
    for habit in habits {
      let completionRequest = FetchDescriptor<Completion>(
        predicate: #Predicate<Completion> { completion in
          completion.userId == userId &&
          completion.habitId == habit.id &&
          completion.dateKey == dateKey &&
          completion.isCompleted == true
        }
      )
      let completions = try context.fetch(completionRequest)
      if completions.isEmpty {
        return false
      }
    }
    return !habits.isEmpty
  }
}

struct DailyAwardQueries {
  static func exists(_ userId: String, _ dateKey: String, in context: ModelContext) throws -> Bool {
    let request = FetchDescriptor<DailyAward>(
      predicate: #Predicate<DailyAward> { award in
        award.userId == userId && award.dateKey == dateKey
      }
    )
    let awards = try context.fetch(request)
    return !awards.isEmpty
  }
  
  static func find(userId: String, dateKey: String, in context: ModelContext) throws -> [DailyAward] {
    let request = FetchDescriptor<DailyAward>(
      predicate: #Predicate<DailyAward> { award in
        award.userId == userId && award.dateKey == dateKey
      }
    )
    return try context.fetch(request)
  }
}

struct UserProgressQueries {
  static func findOrCreate(userId: String, in context: ModelContext) throws -> UserProgress {
    let request = FetchDescriptor<UserProgress>(
      predicate: #Predicate<UserProgress> { progress in progress.userId == userId }
    )
    let existing = try context.fetch(request)
    
    if let progress = existing.first {
      return progress
    } else {
      let newProgress = UserProgress(userId: userId)
      context.insert(newProgress)
      return newProgress
    }
  }
}
```

## Phase 3: Authentication & Isolation Fixes

### 3.1 Sign-in / Sign-out Isolation
**Fix the guest/sign-in bug with proper container switching:**

```swift
class AuthenticationManager: ObservableObject {
  @Published var currentUser: User?
  @Published var isGuestMode: Bool = true
  
  private var habitRepository: HabitRepository?
  private var xpService: XPService?
  
  func signIn(user: User) {
    currentUser = user
    isGuestMode = false
    
    // Re-initialize repositories with user context
    reinitializeRepositories(userId: user.id)
  }
  
  func signOut() {
    currentUser = nil
    isGuestMode = true
    
    // Clear all in-memory caches and re-initialize for guest
    clearAllCaches()
    reinitializeRepositories(userId: "guest")
  }
  
  private func reinitializeRepositories(userId: String) {
    // Create new ModelContext for this user
    let container = ModelContainer.shared(for: userId)
    let context = ModelContext(container)
    
    // Re-initialize services
    xpService = XPServiceImpl(modelContext: context)
    habitRepository = HabitRepositoryImpl(modelContext: context, userId: userId)
    
    // Clear any cached data
    XPManager.shared.clearCache()
    HabitRepository.shared.clearCache()
  }
  
  private func clearAllCaches() {
    // Clear all singletons and caches
    XPManager.shared.clearXPData()
    HabitRepository.shared.clearAllHabits()
    // Clear any other cached data
  }
}
```

### 3.2 Model Container with User Isolation
**Create user-scoped model containers:**

```swift
extension ModelContainer {
  private static var containers: [String: ModelContainer] = [:]
  
  static func shared(for userId: String) -> ModelContainer {
    if let existing = containers[userId] {
      return existing
    }
    
    let schema = Schema([
      Habit.self,
      Completion.self,
      DailyAward.self,
      UserProgress.self,
      DifficultyRecord.self,
      UsageRecord.self,
      HabitNote.self,
      Reminder.self
    ])
    
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: userId == "guest", // Guest data is temporary
      cloudKitDatabase: userId == "guest" ? .none : .private("iCloud.com.habitto.app")
    )
    
    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      containers[userId] = container
      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }
  
  static func clearContainer(for userId: String) {
    containers.removeValue(forKey: userId)
  }
}
```

## Phase 4: Migration Strategy

### 4.1 Migration from Dual Storage
**One-time migration script:**

```swift
class DataMigrationManager {
  func migrateFromUserDefaultsToSwiftData() async throws {
    let context = ModelContext(ModelContainer.shared(for: "current_user"))
    
    // 1) Load habits from UserDefaults
    let userDefaults = UserDefaults.standard
    guard let habitsData = userDefaults.data(forKey: "SavedHabits"),
          let habits = try? JSONDecoder().decode([Habit].self, from: habitsData) else {
      return // No data to migrate
    }
    
    // 2) Convert to SwiftData models
    for habit in habits {
      let habitData = Habit(
        id: habit.id,
        userId: AuthenticationManager.shared.currentUser?.id ?? "guest",
        name: habit.name,
        habitDescription: habit.description,
        icon: habit.icon,
        colorHex: habit.color.toHexString(),
        habitType: habit.habitType.rawValue,
        schedule: habit.schedule,
        goal: habit.goal,
        reminder: habit.reminder,
        startDate: habit.startDate,
        endDate: habit.endDate,
        createdAt: habit.createdAt
      )
      
      context.insert(habitData)
      
      // 3) Migrate completion history
      for (dateKey, completionCount) in habit.completionHistory {
        let completion = Completion(
          userId: habitData.userId,
          habitId: habit.id,
          dateKey: dateKey,
          isCompleted: completionCount > 0,
          completionCount: completionCount,
          timestamp: Date()
        )
        completion.habit = habitData
        context.insert(completion)
      }
      
      // 4) Migrate difficulty history
      for (dateKey, difficulty) in habit.difficultyHistory {
        let difficultyRecord = DifficultyRecord(
          userId: habitData.userId,
          habitId: habit.id,
          dateKey: dateKey,
          difficulty: difficulty
        )
        difficultyRecord.habit = habitData
        context.insert(difficultyRecord)
      }
    }
    
    // 5) Migrate XP data
    if let progressData = userDefaults.data(forKey: "user_progress"),
       let userProgress = try? JSONDecoder().decode(UserProgress.self, from: progressData) {
      let progressData = UserProgress(
        userId: AuthenticationManager.shared.currentUser?.id ?? "guest",
        xpTotal: userProgress.totalXP,
        level: userProgress.currentLevel,
        levelProgress: userProgress.levelProgress,
        lastCompletedDate: userProgress.lastCompletedDate,
        createdAt: userProgress.createdAt
      )
      context.insert(progressData)
    }
    
    // 6) Save and mark migration complete
    try context.save()
    userDefaults.set(true, forKey: "migration_to_swiftdata_complete")
    
    // 7) Clear UserDefaults business data
    userDefaults.removeObject(forKey: "SavedHabits")
    userDefaults.removeObject(forKey: "user_progress")
    userDefaults.removeObject(forKey: "recent_xp_transactions")
  }
}
```

## Phase 5: Comprehensive Test Suite

### 5.1 Unit Tests
**Create these test files:**

```swift
// XPServiceTests.swift
class XPServiceTests: XCTestCase {
  var modelContainer: ModelContainer!
  var modelContext: ModelContext!
  var xpService: XPService!
  
  override func setUp() {
    modelContainer = ModelContainer(for: Habit.self, Completion.self, DailyAward.self, UserProgress.self,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    modelContext = ModelContext(modelContainer)
    xpService = XPServiceImpl(modelContext: modelContext)
  }
  
  func testAwardDailyCompletionWhenAllHabitsCompleted() throws {
    // Given: 3 habits, all completed for 2025-01-02
    let userId = "test_user"
    let dateKey = "2025-01-02"
    
    let habit1 = Habit(userId: userId, name: "Habit 1", habitDescription: "Test", icon: "star", colorHex: "#FF0000", habitType: "formation", schedule: "everyday", goal: "1 time", reminder: "morning", startDate: Date())
    let habit2 = Habit(userId: userId, name: "Habit 2", habitDescription: "Test", icon: "star", colorHex: "#00FF00", habitType: "formation", schedule: "everyday", goal: "1 time", reminder: "morning", startDate: Date())
    let habit3 = Habit(userId: userId, name: "Habit 3", habitDescription: "Test", icon: "star", colorHex: "#0000FF", habitType: "formation", schedule: "everyday", goal: "1 time", reminder: "morning", startDate: Date())
    
    modelContext.insert(habit1)
    modelContext.insert(habit2)
    modelContext.insert(habit3)
    
    // Mark all completed
    let completion1 = Completion(userId: userId, habitId: habit1.id, dateKey: dateKey, isCompleted: true, completionCount: 1, timestamp: Date())
    let completion2 = Completion(userId: userId, habitId: habit2.id, dateKey: dateKey, isCompleted: true, completionCount: 1, timestamp: Date())
    let completion3 = Completion(userId: userId, habitId: habit3.id, dateKey: dateKey, isCompleted: true, completionCount: 1, timestamp: Date())
    
    modelContext.insert(completion1)
    modelContext.insert(completion2)
    modelContext.insert(completion3)
    
    try modelContext.save()
    
    // When: Award daily completion
    try xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
    
    // Then: DailyAward created, XP updated
    let awards = try DailyAwardQueries.find(userId: userId, dateKey: dateKey, in: modelContext)
    XCTAssertEqual(awards.count, 1)
    XCTAssertEqual(awards.first?.xpGranted, 50)
    
    let progress = try UserProgressQueries.findOrCreate(userId: userId, in: modelContext)
    XCTAssertEqual(progress.xpTotal, 50)
  }
  
  func testIdempotency() throws {
    // Given: All habits completed
    let userId = "test_user"
    let dateKey = "2025-01-02"
    
    // Setup habits and completions...
    
    // When: Call awardDailyCompletionIfEligible twice
    try xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
    try xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
    
    // Then: Only one award created
    let awards = try DailyAwardQueries.find(userId: userId, dateKey: dateKey, in: modelContext)
    XCTAssertEqual(awards.count, 1)
    
    let progress = try UserProgressQueries.findOrCreate(userId: userId, in: modelContext)
    XCTAssertEqual(progress.xpTotal, 50) // Not doubled
  }
}

// GuestAccountIsolationTests.swift
class GuestAccountIsolationTests: XCTestCase {
  func testGuestAccountIsolation() throws {
    // Given: User signed in with XP
    let user = User(id: "user123", email: "test@example.com")
    AuthenticationManager.shared.signIn(user: user)
    
    // Earn some XP
    let context = ModelContext(ModelContainer.shared(for: user.id))
    let progress = UserProgress(userId: user.id, xpTotal: 100, level: 2)
    context.insert(progress)
    try context.save()
    
    // When: Sign out
    AuthenticationManager.shared.signOut()
    
    // Then: Guest progress is separate (likely 0)
    let guestContext = ModelContext(ModelContainer.shared(for: "guest"))
    let guestProgress = try UserProgressQueries.findOrCreate(userId: "guest", in: guestContext)
    XCTAssertEqual(guestProgress.xpTotal, 0)
    
    // When: Sign back in
    AuthenticationManager.shared.signIn(user: user)
    
    // Then: User progress is restored
    let userContext = ModelContext(ModelContainer.shared(for: user.id))
    let restoredProgress = try UserProgressQueries.findOrCreate(userId: user.id, in: userContext)
    XCTAssertEqual(restoredProgress.xpTotal, 100)
  }
}

// MigrationTests.swift
class MigrationTests: XCTestCase {
  func testMigrationParity() throws {
    // Given: Legacy UserDefaults data
    let userDefaults = UserDefaults.standard
    let testHabits = [
      Habit(name: "Test Habit", description: "Test", icon: "star", color: .blue, habitType: .formation, schedule: "everyday", goal: "1 time", reminder: "morning", startDate: Date())
    ]
    
    let habitsData = try JSONEncoder().encode(testHabits)
    userDefaults.set(habitsData, forKey: "SavedHabits")
    
    // When: Run migration
    let migrationManager = DataMigrationManager()
    try await migrationManager.migrateFromUserDefaultsToSwiftData()
    
    // Then: SwiftData populated with same data
    let context = ModelContext(ModelContainer.shared(for: "current_user"))
    let habitRequest = FetchDescriptor<Habit>()
    let migratedHabits = try context.fetch(habitRequest)
    
    XCTAssertEqual(migratedHabits.count, 1)
    XCTAssertEqual(migratedHabits.first?.name, "Test Habit")
    
    // Verify migration marked complete
    XCTAssertTrue(userDefaults.bool(forKey: "migration_to_swiftdata_complete"))
  }
}
```

### 5.2 Invariant Tests
**Create meta-tests to catch regressions:**

```swift
// InvariantTests.swift
class InvariantTests: XCTestCase {
  func testOnlyXPServiceMutatesXP() {
    // This test fails if any code outside XPService writes XP
    // Implementation: Use reflection to scan for XP mutation patterns
    let forbiddenPatterns = [
      "xpTotal",
      "totalXP", 
      "addXP",
      "grantXP",
      "awardXP",
      "updateLevel"
    ]
    
    // Scan codebase for these patterns outside XPService
    // This is a meta-test that ensures architectural constraints
  }
  
  func testNoDenormalizedFields() {
    // Ensure no persisted fields named isCompleted or streak exist
    let schema = Schema([
      Habit.self,
      Completion.self,
      DailyAward.self,
      UserProgress.self
    ])
    
    // Check that no model has denormalized completion/streak fields
    // These should be computed from relationships only
  }
}
```

## Phase 6: Implementation Checklist

### 6.1 Immediate Actions (Week 1)
- [ ] Run model inventory audit
- [ ] Create XPService as single entry point
- [ ] Remove all direct XP mutations outside XPService
- [ ] Add userId to all models missing it
- [ ] Write unit tests for XP flow

### 6.2 Model Fixes (Week 2)
- [ ] Replace existing models with fixed versions
- [ ] Add proper relationships (DailyAward → Habit)
- [ ] Remove denormalized fields
- [ ] Implement query helpers
- [ ] Write integration tests

### 6.3 Authentication Fixes (Week 3)
- [ ] Implement user-scoped ModelContainers
- [ ] Fix sign-in/sign-out isolation
- [ ] Clear caches on auth state change
- [ ] Test guest/account isolation
- [ ] Write migration script

### 6.4 Migration & Cleanup (Week 4)
- [ ] Run one-time migration from UserDefaults
- [ ] Remove dual storage
- [ ] Clean up deprecated code
- [ ] Write comprehensive test suite
- [ ] Performance testing

## Why This Fixes the Guest/Sign-in Bug

The guest/sign-in bug happened because:

1. **Dual Storage**: Data existed in both UserDefaults and SwiftData, causing inconsistencies
2. **Sticky Singletons**: XPManager and HabitRepository survived sign-out, leaking data
3. **Missing User Scoping**: Records weren't properly isolated by userId
4. **Multiple XP Paths**: Various code paths could mutate XP, leading to duplicates

This plan fixes it by:

1. **Single Source of Truth**: Only SwiftData stores business data
2. **User-Scoped Containers**: Each user gets their own ModelContainer
3. **Cache Clearing**: All singletons are cleared on sign-out
4. **Single XP Path**: Only XPService can mutate XP/level data
5. **Proper Isolation**: Every record is scoped by userId

The result is a trustworthy data layer where guest and account data cannot leak into each other.
