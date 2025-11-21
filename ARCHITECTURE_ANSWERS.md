# 🎯 Habitto Architecture - Comprehensive Answers

This document provides detailed answers to all architecture questions about Habitto's current data management system.

---

## 📋 Table of Contents

1. [Priority 1: Understanding Current Architecture](#priority-1-understanding-current-architecture)
   - [1. Data Storage](#1-data-storage)
   - [2. Repository Pattern](#2-repository-pattern)
   - [3. Current User ID System](#3-current-user-id-system)
   - [4. Habit Model Structure](#4-habit-model-structure)
2. [Priority 2: Understanding Data Flow](#priority-2-understanding-data-flow)
   - [5. Create Habit Flow](#5-create-habit-flow)
   - [6. Complete Habit Flow](#6-complete-habit-flow)
   - [7. Data Loading](#7-data-loading)
3. [Priority 3: Understanding Dependencies](#priority-3-understanding-dependencies)
   - [8. Firebase Status](#8-firebase-status)
   - [9. Swift Concurrency](#9-swift-concurrency)
   - [10. SwiftData Context](#10-swiftdata-context)
4. [Priority 4: Understanding Current Limitations](#priority-4-understanding-current-limitations)
   - [11. Multi-Device Awareness](#11-multi-device-awareness)
   - [12. Data Migration](#12-data-migration)
5. [Summary Document](#summary-document)

---

## Priority 1: Understanding Current Architecture

### 1. Data Storage

**How is habit data currently stored in Habitto?**

Habitto uses **SwiftData** as the primary persistence layer, with an offline-first architecture.

**What database/persistence layer are we using?**

- **Primary**: SwiftData (SQLite backend)
- **Legacy**: UserDefaults (for migration scenarios)
- **Security**: Keychain (for auth tokens)
- **Planned**: CloudKit (infrastructure ready but disabled)

**Storage Location:**
- SwiftData stores data in: `~/Library/Application Support/default.store` (SQLite database)
- UserDefaults: Standard iOS UserDefaults
- Keychain: iOS Keychain Services

**Main Models/Entities:**

#### HabitData (SwiftData Model)
**File:** `Core/Data/SwiftData/HabitDataModel.swift`

```swift
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String // User isolation key
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data // Color stored as Data
    var habitType: String // Enum stored as String
    var schedule: String
    var goal: String
    var reminder: String
    var goalHistoryJSON: String = "{}"
    var startDate: Date
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var baseline: Int = 0
    var target: Int = 1
    
    // Relationships (cascade delete)
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
}
```

#### CompletionRecord (SwiftData Model)
**File:** `Core/Data/SwiftData/HabitDataModel.swift:482-584`

```swift
@Model
final class CompletionRecord {
    var userId: String
    var habitId: UUID
    var date: Date
    var dateKey: String // "yyyy-MM-dd" format for queries
    var isCompleted: Bool
    var progress: Int = 0 // Actual progress count
    var createdAt: Date
    var updatedAt: Date?
    
    // Composite unique constraint
    @Attribute(.unique) var userIdHabitIdDateKey: String
    
    @Relationship(inverse: \HabitData.completionHistory) var habit: HabitData?
}
```

#### DailyAward (SwiftData Model)
**File:** `Core/Models/DailyAward.swift`

```swift
@Model
public final class DailyAward {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var dateKey: String
    public var xpGranted: Int
    public var allHabitsCompleted: Bool
    public var createdAt: Date
    
    // Unique constraint on (userId, dateKey)
    @Attribute(.unique) public var userIdDateKey: String
}
```

**Where is the data actually saved on the device?**

- **SwiftData**: `~/Library/Application Support/default.store` (SQLite database)
- **UserDefaults**: Standard iOS UserDefaults plist files
- **Keychain**: iOS Keychain Services (encrypted, device-only access)

---

### 2. Repository Pattern

**Do we have a HabitRepository or similar data management class?**

Yes! Habitto uses a **multi-layered repository pattern**:

1. **HabitRepository** (`@MainActor`) - UI-facing facade
2. **HabitStore** (Actor) - Background data operations
3. **SwiftDataStorage** - Direct SwiftData access

**Main Class Responsible for CRUD Operations:**

#### HabitRepository (Main Actor)
**File:** `Core/Data/HabitRepository.swift`

```swift
@MainActor
class HabitRepository: ObservableObject {
    @Published var habits: [Habit] = []
    
    // CRUD Operations
    func createHabit(_ habit: Habit) async
    func updateHabit(_ habit: Habit) async
    func deleteHabit(_ habit: Habit) async
    func loadHabits(force: Bool = false) async
    
    // Progress tracking
    func setProgress(for habit: Habit, date: Date, progress: Int) async throws
}
```

#### HabitStore (Actor - Background Operations)
**File:** `Core/Data/Repository/HabitStore.swift`

```swift
final actor HabitStore {
    static let shared = HabitStore()
    
    // All data operations happen here (off main thread)
    func loadHabits() async throws -> [Habit]
    func saveHabits(_ habits: [Habit]) async throws
    func createHabit(_ habit: Habit) async throws
    func updateHabit(_ habit: Habit) async throws
    func deleteHabit(_ habit: Habit) async throws
    func setProgress(for habit: Habit, date: Date, progress: Int) async throws
}
```

**How does this repository interact with the persistence layer?**

```
UI Layer → HabitRepository (@MainActor) → HabitStore (Actor) → SwiftDataStorage → SQLite
```

1. **UI calls** `HabitRepository` methods (on MainActor)
2. **HabitRepository** delegates to `HabitStore` (background actor)
3. **HabitStore** uses `SwiftDataStorage` to access SwiftData
4. **SwiftDataStorage** performs ModelContext operations
5. **Data is persisted** to SQLite via SwiftData

**Concurrency Patterns:**

- **@MainActor**: HabitRepository (UI thread)
- **Actor**: HabitStore (background thread)
- **async/await**: All data operations are async
- **Thread Safety**: Actor isolation ensures thread-safe data operations

---

### 3. Current User ID System

**How do we currently identify users?**

Habitto uses a **userId-based isolation system**:

- **Authenticated users**: Firebase UID (e.g., `"abc123xyz"`)
- **Guest users**: Empty string `""`

**Is there a userId field in our Habit model?**

Yes! Both `HabitData` and `CompletionRecord` have `userId` fields:

```swift
@Model
final class HabitData {
    var userId: String // User isolation key
    // ... other fields
}

@Model
final class CompletionRecord {
    var userId: String
    // ... other fields
}
```

**How are we handling "guest mode"?**

**File:** `Core/Models/CurrentUser.swift`

```swift
struct CurrentUser {
    static let guestId = ""
    
    var id: String {
        get async {
            await MainActor.run {
                if let user = AuthenticationManager.shared.currentUser {
                    return user.uid
                }
                return Self.guestId // Returns "" for guests
            }
        }
    }
    
    var isGuest: Bool {
        get async {
            await !isAuthenticated
        }
    }
}
```

**Where is userId stored?**

- **In SwiftData models**: `HabitData.userId`, `CompletionRecord.userId`, `DailyAward.userId`
- **Query scoping**: All queries filter by `userId` to ensure data isolation
- **Guest data**: Stored with `userId = ""`
- **Authenticated data**: Stored with `userId = Firebase UID`

**Example Query Scoping:**

```swift
// ✅ Correct - always scoped to current user
let currentUserId = await CurrentUser().idOrGuest
let descriptor = FetchDescriptor<HabitData>(
    predicate: #Predicate<HabitData> { habit in
        habit.userId == currentUserId
    }
)
```

---

### 4. Habit Model Structure

**Show me the complete Habit model/struct definition**

There are **two** Habit models:

1. **Habit** (struct) - UI/domain model
2. **HabitData** (SwiftData @Model) - Persistence model

#### Habit (Domain Model)
**File:** `Core/Models/Habit.swift:107-898`

```swift
struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: CodableColor
    let habitType: HabitType
    let schedule: String
    let goal: String
    let reminder: String
    let reminders: [ReminderItem]
    let startDate: Date
    let endDate: Date?
    let createdAt: Date
    
    // Progress tracking (materialized views)
    var completionHistory: [String: Int] = [:] // "yyyy-MM-dd" -> progress count
    var completionStatus: [String: Bool] = [:] // "yyyy-MM-dd" -> isCompleted
    var completionTimestamps: [String: [Date]] = [:] // "yyyy-MM-dd" -> [timestamps]
    var difficultyHistory: [String: Int] = [:] // "yyyy-MM-dd" -> difficulty (1-10)
    var goalHistory: [String: String] = [:] // "yyyy-MM-dd" -> goal string
    
    // Habit Breaking specific
    var baseline: Int = 0
    var target: Int = 0
    var actualUsage: [String: Int] = [:] // "yyyy-MM-dd" -> usage amount
    
    // Sync metadata
    var lastSyncedAt: Date?
    var syncStatus: FirestoreSyncStatus = .pending
}
```

**What properties does it have?**

See above. Key properties:
- Identity: `id`, `name`, `description`, `icon`, `color`
- Configuration: `habitType`, `schedule`, `goal`, `reminder`, `reminders`
- Dates: `startDate`, `endDate`, `createdAt`
- Progress: `completionHistory`, `completionStatus`, `completionTimestamps`
- Breaking habits: `baseline`, `target`, `actualUsage`
- Sync: `lastSyncedAt`, `syncStatus`

**How is it saved to the database?**

The `Habit` struct is converted to `HabitData` (SwiftData model) for persistence:

```swift
// Conversion happens in SwiftDataStorage.saveHabit()
let habitData = HabitData(
    id: habit.id,
    userId: currentUserId,
    name: habit.name,
    // ... other fields
)
container.modelContext.insert(habitData)
try container.modelContext.save()
```

**Serialization Methods:**

The `Habit` struct is `Codable`, so it has automatic JSON encoding/decoding:

```swift
// Encoding
let jsonData = try JSONEncoder().encode(habit)

// Decoding
let habit = try JSONDecoder().decode(Habit.self, from: jsonData)
```

---

## Priority 2: Understanding Data Flow

### 5. Create Habit Flow

**Walk me through what happens when a user creates a new habit:**

**File:** `Views/Screens/HomeView.swift:253-296`

1. **UI calls** `HomeViewState.createHabit(habit: Habit)`
2. **HomeViewState** calls `habitRepository.createHabit(habit)`
3. **HabitRepository** (`@MainActor`) delegates to `HabitStore`:

```swift
// HabitRepository.createHabit()
func createHabit(_ habit: Habit) async {
    do {
        try await habitStore.createHabit(habit)
        await loadHabits() // Refresh UI
    } catch {
        // Handle error
    }
}
```

4. **HabitStore** (actor) processes the creation:

```swift
// HabitStore.createHabit()
func createHabit(_ habit: Habit) async throws {
    // 1. Validate habit
    let validationResult = validationService.validateHabits([habit])
    
    // 2. Load current habits
    var currentHabits = try await loadHabits()
    
    // 3. Add new habit
    currentHabits.append(habit)
    
    // 4. Save to storage
    try await saveHabits(currentHabits)
}
```

5. **SwiftDataStorage** saves to SwiftData:

```swift
// SwiftDataStorage.saveHabit()
func saveHabit(_ habit: Habit) async throws {
    let userId = await getCurrentUserId()
    
    // Convert Habit to HabitData
    let habitData = HabitData(
        id: habit.id,
        userId: userId ?? "",
        name: habit.name,
        // ... other fields
    )
    
    // Insert and save
    container.modelContext.insert(habitData)
    try container.modelContext.save()
}
```

**Are there any async operations?**

Yes! All operations are async:
- `createHabit()` is `async`
- `saveHabits()` is `async throws`
- `loadHabits()` is `async throws`
- All SwiftData operations are async

**Show me the code for creating a habit:**

See above flow. Key files:
- `Views/Screens/HomeView.swift:253-296` - UI entry point
- `Core/Data/HabitRepository.swift` - Repository facade
- `Core/Data/Repository/HabitStore.swift:250-344` - Business logic
- `Core/Data/SwiftData/SwiftDataStorage.swift:508-558` - Persistence

---

### 6. Complete Habit Flow

**Walk me through what happens when a user completes a habit:**

**File:** `Core/Data/Repository/HabitStore.swift:387-530`

1. **UI calls** `HabitRepository.setProgress(for:date:progress:)`
2. **HabitRepository** delegates to `HabitStore.setProgress()`
3. **HabitStore** processes the completion:

```swift
func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let dateKey = DateUtils.dateKey(for: date)
    
    // 1. Load current habits
    var currentHabits = try await loadHabits()
    
    // 2. Find habit and update progress
    if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
        let oldProgress = currentHabits[index].completionHistory[dateKey] ?? 0
        let goalAmount = currentHabits[index].goalAmount(for: date)
        
        // 3. Create ProgressEvent (event sourcing)
        if progress != oldProgress {
            let event = try await ProgressEventService.shared.createEvent(
                habitId: habit.id,
                date: date,
                dateKey: dateKey,
                eventType: eventTypeForProgressChange(...),
                progressDelta: progress - oldProgress,
                userId: userId
            )
        }
        
        // 4. Update completion history
        currentHabits[index].completionHistory[dateKey] = progress
        currentHabits[index].completionStatus[dateKey] = (progress >= goalAmount)
        
        // 5. Create CompletionRecord for SwiftData
        await createCompletionRecordIfNeeded(
            habit: currentHabits[index],
            date: date,
            dateKey: dateKey,
            progress: progress
        )
        
        // 6. Save habits
        try await saveHabits(currentHabits)
        
        // 7. Check daily completion and award XP
        try await checkDailyCompletionAndAwardXP(dateKey: dateKey, userId: userId)
    }
}
```

**How is progress tracked?**

Progress is tracked in multiple places:

1. **Habit.completionHistory** - Dictionary: `["yyyy-MM-dd": progress_count]`
2. **CompletionRecord** - SwiftData entity with `progress: Int`
3. **ProgressEvent** - Event sourcing (source of truth)

**How are XP and streaks calculated?**

**XP Calculation:**
- **File:** `Core/Services/DailyAwardService.swift`
- XP is awarded when **all habits** are completed for a day
- Awarded via `DailyAward` records (ledger-based)
- XP integrity is checked: `sum(DailyAward.xpGranted) == UserProgressData.totalXP`

**Streak Calculation:**
- **File:** `Core/Data/SwiftData/HabitDataModel.swift:300-322`
- Calculated from `CompletionRecord` history
- Counts consecutive completed days backwards from today
- Uses `calculateTrueStreak()` method

```swift
func calculateTrueStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var streak = 0
    var currentDate = today
    
    while isCompletedForDate(currentDate) {
        streak += 1
        currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        if currentDate < startDate { break }
    }
    
    return streak
}
```

**Show me the code for marking a habit complete:**

See `Core/Data/Repository/HabitStore.swift:387-530` above.

---

### 7. Data Loading

**How does the app load habits when it starts?**

**File:** `App/HabittoApp.swift:355-390`

1. **App Launch**: `HabittoApp.onAppear()` is called
2. **Load Habits**: `habitRepository.loadHabits()` is called after a short delay
3. **HabitRepository** delegates to `HabitStore.loadHabits()`

**Which function loads all habits?**

**File:** `Core/Data/Repository/HabitStore.swift:29-103`

```swift
func loadHabits() async throws -> [Habit] {
    // 1. Check if migration is needed
    let migrationMgr = await migrationManager
    if await migrationMgr.needsMigration() {
        try await migrationMgr.executeMigrations()
    }
    
    // 2. Run data retention cleanup (once per session)
    if !Self.hasRunCleanupThisSession {
        // ... cleanup logic
    }
    
    // 3. Load from active storage (SwiftData)
    var habits = try await activeStorage.loadHabits()
    
    // 4. If no habits found, check UserDefaults (migration scenario)
    if habits.isEmpty {
        let legacyHabits = try await checkForLegacyHabits()
        if !legacyHabits.isEmpty {
            habits = legacyHabits
            try await activeStorage.saveHabits(legacyHabits, immediate: true)
        }
    }
    
    return habits
}
```

**When is this called?**

- **App launch**: `HabittoApp.onAppear()` → `habitRepository.loadHabits()`
- **App becomes active**: Notification observer triggers reload
- **After habit creation/update**: `loadHabits()` is called to refresh UI

**Is the data cached in memory?**

Yes! `HabitRepository` maintains an in-memory cache:

```swift
@MainActor
class HabitRepository: ObservableObject {
    @Published var habits: [Habit] = [] // In-memory cache
    
    func loadHabits(force: Bool = false) async {
        // Cache check
        if !force, !habits.isEmpty, lastLoadTime != nil {
            return // Use cached data
        }
        
        // Load from storage and update cache
        let loadedHabits = try await habitStore.loadHabits()
        self.habits = loadedHabits
    }
}
```

---

## Priority 3: Understanding Dependencies

### 8. Firebase Status

**Is Firebase already integrated in the project?**

**YES!** Firebase is integrated but **partially disabled** for guest mode.

**Check if FirebaseCore, FirebaseAuth, or FirebaseFirestore are in dependencies:**

**File:** `App/HabittoApp.swift:1-11`

```swift
import FirebaseCore
import FirebaseCrashlytics
import FirebaseRemoteConfig
import GoogleSignIn
```

**Are there any Firebase imports in the codebase?**

Yes! Found **94 files** with Firebase imports:
- `Core/Services/FirestoreService.swift`
- `Core/Data/Storage/FirestoreStorage.swift`
- `Core/Managers/AuthenticationManager.swift`
- `Core/Models/FirestoreModels.swift`
- And many more...

**Is there a GoogleService-Info.plist file?**

Yes! `GoogleService-Info.plist` exists in the project root.

**Firebase Status Summary:**

- ✅ **FirebaseCore**: Integrated
- ✅ **FirebaseAuth**: Integrated (used for authentication)
- ✅ **FirebaseFirestore**: Integrated (infrastructure ready, but sync is feature-flagged)
- ✅ **FirebaseCrashlytics**: Integrated
- ✅ **FirebaseRemoteConfig**: Integrated
- ⚠️ **Firestore Sync**: Infrastructure ready but **disabled by default** (guest mode works offline-only)

---

### 9. Swift Concurrency

**What concurrency approach are we using?**

Habitto uses **modern Swift concurrency**:

1. **async/await**: All data operations
2. **Actors**: `HabitStore` is an actor for thread-safe data operations
3. **@MainActor**: UI-facing classes run on main thread

**Are we using async/await?**

Yes! All data operations are async:

```swift
// Example from HabitRepository
func createHabit(_ habit: Habit) async {
    try await habitStore.createHabit(habit)
    await loadHabits()
}

// Example from HabitStore
func loadHabits() async throws -> [Habit] {
    var habits = try await activeStorage.loadHabits()
    return habits
}
```

**Do we have any actors?**

Yes! `HabitStore` is an actor:

```swift
final actor HabitStore {
    static let shared = HabitStore()
    
    // All methods are actor-isolated (thread-safe)
    func loadHabits() async throws -> [Habit] { ... }
    func saveHabits(_ habits: [Habit]) async throws { ... }
}
```

**Show me examples of how asynchronous operations are handled:**

**Example 1: Creating a Habit**
```swift
// UI (MainActor)
Task {
    await habitRepository.createHabit(habit)
}

// Repository (MainActor)
func createHabit(_ habit: Habit) async {
    try await habitStore.createHabit(habit) // Actor hop
    await loadHabits()
}

// Store (Actor)
func createHabit(_ habit: Habit) async throws {
    // Thread-safe operations here
}
```

**Example 2: Loading Habits**
```swift
// UI (MainActor)
Task {
    await habitRepository.loadHabits()
}

// Repository (MainActor)
func loadHabits() async {
    let habits = try await habitStore.loadHabits() // Actor hop
    self.habits = habits // Update UI
}
```

---

### 10. SwiftData Context

**How is the SwiftData ModelContext managed?**

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`

Habitto uses a **singleton ModelContainer** pattern:

```swift
@MainActor
final class SwiftDataContainer: ObservableObject {
    static let shared = SwiftDataContainer()
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private init() {
        // Create ModelContainer with schema and migration plan
        let schema = Schema(versionedSchema: HabittoSchemaV1.self)
        let migrationPlan = HabittoMigrationPlan.self
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // CloudKit disabled
        )
        
        modelContainer = try! ModelContainer(
            for: schema,
            migrationPlan: migrationPlan,
            configurations: [modelConfiguration]
        )
        
        modelContext = ModelContext(modelContainer)
    }
}
```

**Where is it created and passed down?**

**File:** `App/HabittoApp.swift:327`

```swift
@main
struct HabittoApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .modelContainer(SwiftDataContainer.shared.modelContainer)
                // ... other environment objects
        }
    }
}
```

**How do views access the model context?**

Views access the context via:
1. **Environment**: `.modelContainer()` modifier
2. **Direct access**: `SwiftDataContainer.shared.modelContext`
3. **Through Repository**: All data operations go through `HabitRepository` → `HabitStore` → `SwiftDataStorage`

**Example:**
```swift
// In a view
@Environment(\.modelContext) private var modelContext

// Or direct access
let context = SwiftDataContainer.shared.modelContext
```

---

## Priority 4: Understanding Current Limitations

### 11. Multi-Device Awareness

**Is there any code that handles multiple devices or sync?**

**YES!** Infrastructure exists but is **feature-flagged off**:

**File:** `Core/Data/Sync/SyncEngine.swift`
- Sync engine exists but is disabled
- CloudKit infrastructure is ready but not active

**Search for "sync", "cloud", "iCloud" in the codebase:**

Found:
- `Core/Data/Sync/SyncEngine.swift` - Sync engine
- `Core/Data/CloudKit/CloudKitSyncManager.swift` - CloudKit manager
- `Core/Data/CloudKit/CloudKitUniquenessManager.swift` - Uniqueness handling
- Multiple CloudKit-related files

**Are there any network calls being made?**

**Currently**: No (guest mode is offline-only)
**When authenticated**: Firestore sync can be enabled via feature flag

**Is there any code that handles data conflicts?**

**File:** `Core/Data/CloudKit/CloudKitUniquenessManager.swift`

Conflict resolution infrastructure exists:
- Field-level conflict resolution
- Day-level conflict units
- Last-write-wins strategy (planned)

**Current Status:**
- ✅ Infrastructure ready
- ⚠️ **Disabled** for guest mode (offline-only)
- 🔄 Can be enabled for authenticated users via feature flag

---

### 12. Data Migration

**Have we implemented any data migration logic?**

**YES!** Comprehensive migration system exists:

**File:** `Core/Data/Repository/HabitStore.swift:33-37`

```swift
func loadHabits() async throws -> [Habit] {
    // Check if migration is needed
    let migrationMgr = await migrationManager
    if await migrationMgr.needsMigration() {
        try await migrationMgr.executeMigrations()
    }
    // ... rest of load logic
}
```

**Are there version checks for the data model?**

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift:19-26`

```swift
// ✅ MIGRATION SYSTEM: Use versioned schema with migration plan
let migrationPlan = HabittoMigrationPlan.self
let schema = Schema(versionedSchema: HabittoSchemaV1.self)
```

**How do we handle updates to the Habit structure?**

Migration system handles schema changes:
1. **Versioned Schema**: `HabittoSchemaV1.self`
2. **Migration Plan**: `HabittoMigrationPlan.self`
3. **Automatic Migration**: Runs on app launch if needed

**Migration Files:**
- `Core/Data/Migration/` - Multiple migration services
- `Core/Data/Migration/GuestDataMigration.swift` - Guest → Auth migration
- `Core/Data/Migration/MigrateCompletionsToEvents.swift` - Event sourcing migration

---

## Summary Document

### Current Data Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    📱 UI LAYER                              │
│  HomeView │ CreateHabitView │ ProfileView │ MoreTabView     │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│           🎛️ MANAGER LAYER (@MainActor)                     │
│  HabitRepository │ AuthenticationManager │ XPManager         │
│  • UI Facade     │ • Firebase Auth      │ • XP Calculation  │
│  • User Scoping  │ • Keychain Tokens     │ • Level Progress │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│           ⚡ ACTOR LAYER (Background)                     │
│                    HabitStore (Actor)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Validation   │  │ Migration    │  │ Retention    │     │
│  │ • Input      │  │ • Schema     │  │ • 365-day    │     │
│  │ • Integrity  │  │ • Version     │  │ • Cleanup    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              💾 STORAGE LAYER                               │
│  SwiftData (Primary) │ UserDefaults │ Keychain │ CloudKit*  │
│  • HabitData         │ • Settings   │ • Tokens │ (Disabled) │
│  • CompletionRecord  │ • Flags      │ • Secrets│            │
│  • DailyAward        │ • Cache      │          │            │
└─────────────────────────────────────────────────────────────┘
```

### List of All Data Models and Their Properties

#### SwiftData Models

1. **HabitData**
   - Properties: `id`, `userId`, `name`, `habitDescription`, `icon`, `colorData`, `habitType`, `schedule`, `goal`, `reminder`, `startDate`, `endDate`, `createdAt`, `updatedAt`, `baseline`, `target`
   - Relationships: `completionHistory`, `difficultyHistory`, `usageHistory`, `notes`

2. **CompletionRecord**
   - Properties: `userId`, `habitId`, `date`, `dateKey`, `isCompleted`, `progress`, `createdAt`, `updatedAt`, `userIdHabitIdDateKey` (unique)
   - Relationships: `habit` (inverse)

3. **DailyAward**
   - Properties: `id`, `userId`, `dateKey`, `xpGranted`, `allHabitsCompleted`, `createdAt`, `userIdDateKey` (unique)

4. **DifficultyRecord**
   - Properties: `dateKey`, `date`, `difficulty`, `createdAt`
   - Relationships: `habit` (inverse)

5. **UsageRecord**
   - Properties: `key`, `value`, `createdAt`
   - Relationships: `habit` (inverse)

6. **HabitNote**
   - Properties: `content`, `createdAt`, `updatedAt`
   - Relationships: `habit` (inverse)

7. **UserProgressData**
   - Properties: `id`, `userId`, `xpTotal`, `level`, `xpForCurrentLevel`, `xpForNextLevel`, `dailyXP`, `lastCompletedDate`, `streakDays`, `createdAt`, `updatedAt`
   - Relationships: `achievements`

#### Domain Models

1. **Habit** (struct)
   - See section 4 above for complete structure

### Key Functions for CRUD Operations

#### Create
- `HabitRepository.createHabit(_:)` → `HabitStore.createHabit(_:)` → `SwiftDataStorage.saveHabit(_:)`

#### Read
- `HabitRepository.loadHabits()` → `HabitStore.loadHabits()` → `SwiftDataStorage.loadHabits()`

#### Update
- `HabitRepository.updateHabit(_:)` → `HabitStore.updateHabit(_:)` → `SwiftDataStorage.saveHabit(_:)`

#### Delete
- `HabitRepository.deleteHabit(_:)` → `HabitStore.deleteHabit(_:)` → `SwiftDataStorage.deleteHabit(id:)`

#### Progress Tracking
- `HabitRepository.setProgress(for:date:progress:)` → `HabitStore.setProgress(for:date:progress:)` → Creates `CompletionRecord` and `ProgressEvent`

### Current Concurrency Approach

- **@MainActor**: UI-facing classes (`HabitRepository`, views)
- **Actor**: Background data operations (`HabitStore`)
- **async/await**: All data operations
- **Thread Safety**: Actor isolation ensures safe concurrent access

### Existing Cloud/Sync Infrastructure

- ✅ **CloudKit**: Infrastructure ready but disabled
- ✅ **Firestore**: Infrastructure ready, feature-flagged
- ✅ **SyncEngine**: Exists but not active for guests
- ✅ **Conflict Resolution**: Field-level resolution ready
- ⚠️ **Status**: Offline-first, sync can be enabled for authenticated users

### File Paths for Main Data Management Code

1. **Repository**: `Core/Data/HabitRepository.swift`
2. **Store**: `Core/Data/Repository/HabitStore.swift`
3. **Storage**: `Core/Data/SwiftData/SwiftDataStorage.swift`
4. **Container**: `Core/Data/SwiftData/SwiftDataContainer.swift`
5. **Models**: `Core/Data/SwiftData/HabitDataModel.swift`
6. **Domain Model**: `Core/Models/Habit.swift`
7. **User Management**: `Core/Models/CurrentUser.swift`
8. **App Entry**: `App/HabittoApp.swift`

---

## 🎁 Must-Have Files Summary

1. ✅ **Habit model definition**: `Core/Models/Habit.swift` (struct) + `Core/Data/SwiftData/HabitDataModel.swift` (@Model)
2. ✅ **HabitRepository code**: `Core/Data/HabitRepository.swift`
3. ✅ **How habits are saved**: `Core/Data/SwiftData/SwiftDataStorage.swift:508-558`
4. ✅ **How habits are loaded**: `Core/Data/SwiftData/SwiftDataStorage.swift:342-500`
5. ✅ **Firebase status**: **YES** - Integrated but feature-flagged for guest mode

---

## 📝 Additional Notes

- **Guest Mode**: Works completely offline, no Firebase required
- **Authenticated Mode**: Can enable Firestore sync via feature flag
- **Data Isolation**: All queries are scoped by `userId`
- **Event Sourcing**: Progress tracking uses event sourcing (ProgressEvent)
- **XP System**: Ledger-based with integrity checks
- **Migration**: Automatic schema migrations on app launch

---

**Document Generated**: 2024
**Last Updated**: Based on current codebase analysis

