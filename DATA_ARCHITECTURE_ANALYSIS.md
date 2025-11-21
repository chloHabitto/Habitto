# Data Architecture Analysis

**Date:** Generated from current codebase  
**Status:** Comprehensive investigation of current implementation

---

## 1. Current User ID Handling

### **Guest User ID: Empty String (`""`)**

The app uses **empty string (`""`)** as the guest user identifier, consistent across the codebase:

**Location:** `Core/Models/CurrentUser.swift`

```swift
struct CurrentUser {
    /// Guest user identifier - consistent across the app
    static let guestId = ""
    
    /// Get the current user ID, or guest identifier if not authenticated
    var id: String {
        get async {
            await MainActor.run {
                if let resolvedId = resolveUserId(from: AuthenticationManager.shared.currentUser) {
                    return resolvedId
                }
                
                // ✅ FALLBACK: Auth.auth().currentUser is available before AuthenticationManager finishes setup
                if let authUser = Auth.auth().currentUser,
                   let fallbackId = resolveUserId(from: authUser)
                {
                    return fallbackId
                }
                
                return Self.guestId  // Returns "" for guest
            }
        }
    }
    
    /// Check if a user ID represents a guest user
    static func isGuestId(_ userId: String) -> Bool {
        userId.isEmpty || userId == guestId
    }
}
```

### **How userId is Assigned**

1. **Guest Mode:** `userId = ""` (empty string)
2. **Authenticated User:** `userId = Auth.auth().currentUser?.uid` (Firebase UID)
3. **Anonymous Firebase User:** Treated as guest → `userId = ""`

### **Where userId is Used**

- **SwiftData Models:** All models have `userId: String` field
  - `HabitData.userId`
  - `CompletionRecord.userId`
  - `DailyAward.userId`
  - `UserProgressData.userId`
  - `ProgressEvent.userId`

- **Data Queries:** All queries filter by `userId`:
  ```swift
  let predicate = #Predicate<HabitData> { habit in
      habit.userId == userId  // Empty string for guest
  }
  ```

- **Data Isolation:** Each user's data is isolated via `userId` filtering

### **Key Files:**

- `Core/Models/CurrentUser.swift` - User ID management
- `Core/Data/SwiftData/SwiftDataContainer.swift` - `getCurrentUserId()` helper
- `Core/Data/Repository/HabitStore.swift` - Uses `await CurrentUser().idOrGuest`

---

## 2. SwiftData Model Definitions

### **HabitData** (`Core/Data/SwiftData/HabitDataModel.swift`)

✅ **Matches Architecture:** Has `userId` field for data isolation

```swift
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String // User ID for data isolation
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data
    var habitType: String
    var schedule: String
    var goal: String
    var reminder: String
    var goalHistoryJSON: String = "{}"
    var startDate: Date
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Breaking habit fields
    var baseline: Int = 0
    var target: Int = 1
    
    // Relationships
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
}
```

**Key Points:**
- ✅ Has `userId` field for data isolation
- ✅ Has `completionHistory` relationship (materialized view)
- ✅ Stores `goalHistoryJSON` as JSON string

---

### **CompletionRecord** (Materialized View)

**Location:** `Core/Data/SwiftData/HabitDataModel.swift`

```swift
@Model
final class CompletionRecord {
    @Attribute(.unique) var id: UUID
    var userId: String
    var habitId: UUID
    var date: Date
    var dateKey: String  // "yyyy-MM-dd"
    var isCompleted: Bool
    var progress: Int = 0  // ✅ NEW: Stores actual progress count
    var createdAt: Date
    var updatedAt: Date
    
    /// Composite unique constraint: (userId, habitId, dateKey)
    @Attribute(.unique) var userIdHabitIdDateKey: String
}
```

**Key Points:**
- ✅ Materialized view (not source of truth)
- ✅ Unique constraint on `(userId, habitId, dateKey)`
- ✅ Stores `progress` for queries (e.g., "completed habits today")

---

### **DailyAward** (XP Ledger Entry)

**Location:** `Core/Models/DailyAward.swift`

✅ **Matches Architecture:** Immutable ledger entry

```swift
@Model
public final class DailyAward {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var dateKey: String  // "yyyy-MM-dd"
    public var xpGranted: Int
    public var allHabitsCompleted: Bool
    public var createdAt: Date
    
    /// Unique constraint on (userId, dateKey)
    @Attribute(.unique) public var userIdDateKey: String
}
```

**Key Points:**
- ✅ **Immutable ledger entry** (source of truth for XP)
- ✅ Unique constraint on `(userId, dateKey)` prevents duplicates
- ✅ Used to calculate `UserProgressData.totalXP = sum(DailyAward.xpGranted)`

---

### **ProgressEvent** (Event-Sourcing Model)

**Location:** `Core/Models/ProgressEvent.swift`

✅ **Event-Sourcing Implemented:** Full model exists

```swift
@Model
public final class ProgressEvent {
    /// Deterministic ID: "evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}"
    @Attribute(.unique) public var id: String
    
    public var habitId: UUID
    public var dateKey: String  // "yyyy-MM-dd"
    public var eventType: String  // ProgressEventType enum stored as string
    public var progressDelta: Int
    
    public var createdAt: Date
    public var occurredAt: Date
    public var utcDayStart: Date
    public var utcDayEnd: Date
    
    public var deviceId: String  // "iOS_{deviceModel}_{uuid}"
    public var userId: String
    public var timezoneIdentifier: String
    
    @Attribute(.unique) public var operationId: String  // For idempotency
    public var synced: Bool
    public var lastSyncedAt: Date?
    public var syncVersion: Int
    public var isRemote: Bool
    public var deletedAt: Date?
    
    public var note: String?
    public var metadata: String?
}
```

**Key Points:**
- ✅ **Full event-sourcing model** exists
- ✅ Deterministic ID for idempotency
- ✅ Device and timezone info for conflict resolution
- ✅ Sync metadata (though sync is currently disabled)

---

### **UserProgressData** (XP State)

**Location:** `Core/Models/UserProgressData.swift`

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
    
    @Relationship(deleteRule: .cascade) var achievements: [AchievementData]
    
    /// Updates XP and recalculates level automatically
    func updateXP(_ newXP: Int) {
        xpTotal = newXP
        level = calculateLevel(from: newXP)
        // Recalculates level progress fields
    }
}
```

**Key Points:**
- ✅ **Materialized view** - derived from `sum(DailyAward.xpGranted)`
- ✅ Level calculated automatically from XP
- ✅ One record per user (`userId` unique constraint)

---

### **❌ Missing: XPTransaction Model**

**Architecture mentions:** `XPTransaction` model for audit trail  
**Status:** Not found in codebase

**What exists instead:**
- `DailyAward` records serve as the ledger (XP awarded per day)
- `UserProgressData` stores aggregated state

---

## 3. Data Initialization Flow

### **App Launch → HabitRepository Creation**

**Location:** `Core/Data/Repository/HabitRepositoryImpl.swift`

```swift
@MainActor
class HabitRepositoryImpl: HabitRepositoryProtocol, ObservableObject {
    @Published var habitList: [Habit] = []
    
    private let habitStore: HabitStore
    
    init() {
        self.habitStore = HabitStore.shared
        loadHabitsOnInit()
    }
    
    private func loadHabitsOnInit() {
        Task {
            do {
                let habits = try await habitStore.loadHabits()
                await MainActor.run {
                    self.habitList = habits
                }
            } catch {
                // Handle error
            }
        }
    }
}
```

### **HabitStore Initialization**

**Location:** `Core/Data/Repository/HabitStore.swift`

```swift
final actor HabitStore {
    static let shared = HabitStore()
    
    private init() {
        // Singleton initialization
    }
    
    func loadHabits() async throws -> [Habit] {
        // Loads from activeStorage (currently SwiftDataStorage)
        let userId = await CurrentUser().idOrGuest  // Gets "" for guest
        return try await activeStorage.loadHabits(userId: userId)
    }
}
```

### **SwiftData Container Initialization**

**Location:** `Core/Data/SwiftData/SwiftDataContainer.swift`

```swift
final class SwiftDataContainer {
    static let shared = SwiftDataContainer()
    
    private init() {
        let schema = Schema([
            HabitData.self,
            CompletionRecord.self,
            ProgressEvent.self,  // ✅ Event-sourcing model included
            DailyAward.self,
            UserProgressData.self,
            // ... other models
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none)  // ✅ CloudKit sync DISABLED
        
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration])
        
        self.modelContext = ModelContext(modelContainer)
    }
    
    private func getCurrentUserId() -> String {
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            return ""  // ✅ Guest = empty string
        }
        
        if let firebaseUser = currentUser as? User, firebaseUser.isAnonymous {
            return ""  // ✅ Anonymous = guest
        }
        
        return currentUser.uid  // ✅ Authenticated user
    }
}
```

### **Key Initialization Points:**

1. **App Launch:** `HabitRepositoryImpl.init()` → creates `HabitStore.shared`
2. **First Data Access:** `HabitStore.loadHabits()` → calls `CurrentUser().idOrGuest`
3. **Guest Mode:** Returns `""` (empty string) if not authenticated
4. **Data Isolation:** All queries filter by `userId == ""` for guest

---

## 4. Guest Mode Implementation

### **How Habits are Saved Without Authentication**

**Location:** `Core/Data/Repository/HabitStore.swift`

```swift
func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let userId = await CurrentUser().idOrGuest  // Gets "" for guest
    
    // Creates ProgressEvent with userId = ""
    let event = try await ProgressEventService.shared.createEvent(
        habitId: habit.id,
        date: date,
        dateKey: dateKey,
        eventType: eventType,
        progressDelta: progressDelta,
        userId: userId  // Empty string for guest
    )
    
    // Creates CompletionRecord with userId = ""
    await createCompletionRecordIfNeeded(
        habit: habit,
        date: date,
        dateKey: dateKey,
        progress: progress
    )
    
    // Saves to SwiftData with userId = ""
    try await saveHabits(currentHabits)
}
```

### **What userId Value is Used for Guest Users**

**Answer:** Empty string (`""`)

**Evidence:**
- `CurrentUser.guestId = ""`
- `CurrentUser().idOrGuest` returns `""` if not authenticated
- All SwiftData queries work with `userId == ""` for guest

### **Migration Logic from Guest to Authenticated**

**Location:** `Core/Data/Migration/GuestDataMigration.swift`

```swift
func migrateGuestDataIfNeeded() async throws {
    let context = SwiftDataContainer.shared.modelContext
    
    // Check for habits with empty userId or "guest" userId
    let allHabits = try context.fetch(FetchDescriptor<HabitData>())
    
    let guestHabits = allHabits.filter { habitData in
        // Guest userIds: "" or "guest"
        let isGuestId = habitData.userId.isEmpty || habitData.userId == "guest"
        
        // If user is authenticated, detect habits that don't belong to current user
        if let currentUserId = AuthenticationManager.shared.currentUser?.uid,
           !currentUserId.isEmpty {
            // Migrate guest habits to authenticated user
            return isGuestId
        }
        
        return isGuestId
    }
    
    if !guestHabits.isEmpty {
        // Migrate: Update userId from "" to authenticated userId
        for habit in guestHabits {
            habit.userId = currentUserId
        }
        try context.save()
    }
}
```

**Key Points:**
- ✅ Migration logic exists
- ✅ Migrates `userId` from `""` to authenticated `uid`
- ✅ Migrates habits, completion records, daily awards, etc.

---

## 5. Event Sourcing Status

### **✅ Event-Sourcing IS Implemented**

**Status:** Fully implemented and **ACTIVE** (no feature flag)

**Location:** `Core/Data/Repository/HabitStore.swift`

```swift
func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    // ✅ PRIORITY 1: Always create ProgressEvent (event sourcing is now default)
    // This is the source of truth for all progress changes
    
    let userId = await CurrentUser().idOrGuest
    let eventType = eventTypeForProgressChange(...)
    let progressDelta = progress - oldProgress
    
    // Always create event if there's an actual change
    if progressDelta != 0 {
        let event = try await ProgressEventService.shared.createEvent(
            habitId: habit.id,
            date: date,
            dateKey: dateKey,
            eventType: eventType,
            progressDelta: progressDelta,
            userId: userId
        )
        logger.info("✅ setProgress: Created ProgressEvent successfully")
    }
    
    // ⚠️ DEPRECATED: Direct state update - kept for backward compatibility
    // TODO: Remove this once all code paths use event replay
    currentHabits[index].completionHistory[dateKey] = progress
}
```

### **How Habit Completion Works Currently**

**Complete Flow (UI → Data):**

1. **UI Tap:** `ScheduledHabitItem` → `onProgressChange(habit, date, newProgress)`
2. **View:** `HomeTabView` → `onSetProgress(habit, date, progress)`
3. **Repository:** `HabitRepositoryImpl` → `habitStore.setProgress(habit, date, progress)`
4. **Store:** `HabitStore.setProgress()`:
   - ✅ Creates `ProgressEvent` (event-sourcing, source of truth)
   - ⚠️ Updates `completionHistory` directly (deprecated, backward compat)
   - ✅ Creates `CompletionRecord` (materialized view for queries)
   - ✅ Checks daily completion → awards XP via `DailyAwardService`
5. **Storage:** Saves to SwiftData

**Evidence:**
- ✅ `ProgressEventService.shared.createEvent()` is called on every progress change
- ✅ Events have deterministic IDs: `"evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}"`
- ✅ `getProgress()` uses `ProgressEventService.calculateProgressFromEvents()` (event replay)

---

## 6. XP Award Logic

### **✅ Deterministic IDs and Atomic Transactions**

**Location:** `Core/Services/DailyAwardService.swift`

**Current Implementation:**

```swift
func awardXP(delta: Int, dateKey: String, reason: String) async throws {
    let userId = await CurrentUser().idOrGuest  // Gets "" for guest
    
    // ✅ STEP 1: Create or delete DailyAward record (immutable ledger entry)
    if delta > 0 {
        // Award XP: Create DailyAward record
        let award = DailyAward(
            userId: userId,
            dateKey: dateKey,
            xpGranted: delta,
            allHabitsCompleted: true
        )
        // Unique constraint on (userId, dateKey) prevents duplicates
        modelContext.insert(award)
    } else if delta < 0 {
        // Reverse XP: Delete DailyAward record(s)
        // ... delete logic
    }
    
    try modelContext.save()  // ✅ Atomic transaction
    
    // ✅ STEP 2: Recalculate UserProgressData.totalXP from ALL DailyAward records
    let allAwards = try modelContext.fetch(FetchDescriptor<DailyAward>(...))
    let calculatedTotalXP = allAwards.reduce(0) { $0 + $1.xpGranted }
    
    // ✅ STEP 3: Update UserProgressData from calculated value
    userProgress.updateXP(calculatedTotalXP)
    try modelContext.save()
    
    // ✅ STEP 4: Update xpState for UI reactivity
    await refreshXPState()
}
```

**Key Points:**
- ✅ **DailyAward is source of truth** (immutable ledger)
- ✅ **Unique constraint** on `(userId, dateKey)` prevents duplicates
- ✅ **Atomic transactions** via SwiftData `save()`
- ✅ **Derived state:** `UserProgressData.totalXP = sum(DailyAward.xpGranted)`

**Deterministic IDs:**
- ✅ `DailyAward.userIdDateKey = "\(userId)#\(dateKey)"` (unique constraint)
- ✅ Prevents duplicate awards for same user/date

---

## 7. Firebase Sync State

### **❌ Cloud Sync is DISABLED**

**Status:** Firestore sync is disabled for guest-only mode

**Evidence:**

1. **SwiftDataContainer:** CloudKit sync disabled
   ```swift
   let modelConfiguration = ModelConfiguration(
       schema: schema,
       isStoredInMemoryOnly: false,
       cloudKitDatabase: .none)  // ✅ DISABLED
   ```

2. **HabitStore:** Uses `SwiftDataStorage` only (not `DualWriteStorage`)
   ```swift
   private var activeStorage: HabitStorageProtocol {
       SwiftDataStorage.shared  // ✅ Local only
   }
   ```

3. **SyncEngine:** Initialization commented out in AppDelegate

4. **ProgressEventService:** Sync calls removed

**What Still Exists (but unused):**
- `SyncEngine` class exists (sync logic is there)
- `FirestoreRepository` exists (Firestore integration is there)
- `ProgressEvent.synced` field exists (but sync never runs)

**Current Flow:**
- ✅ All data stored locally in SwiftData
- ✅ No network calls
- ✅ No Firestore writes
- ✅ Works completely offline

---

## 8. Data Queries

### **How the App Queries Habits for Display**

**Location:** `Core/Data/Repository/HabitStore.swift`

```swift
func loadHabits() async throws -> [Habit] {
    let userId = await CurrentUser().idOrGuest  // Gets "" for guest
    return try await activeStorage.loadHabits(userId: userId)
}
```

**SwiftData Query (in SwiftDataStorage):**

```swift
func loadHabits(userId: String) async throws -> [Habit] {
    let modelContext = SwiftDataContainer.shared.modelContext
    
    // ✅ Query filtered by userId ("" for guest)
    let predicate = #Predicate<HabitData> { habit in
        habit.userId == userId
    }
    let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
    let habitDataArray = try modelContext.fetch(descriptor)
    
    return habitDataArray.map { $0.toHabit() }
}
```

**Completion Queries:**

```swift
func createCompletionRecordIfNeeded(...) async {
    let userId = await CurrentUser().idOrGuest  // Gets "" for guest
    
    let predicate = #Predicate<CompletionRecord> { record in
        record.userId == userId &&  // ✅ Filter by userId
        record.habitId == habit.id &&
        record.dateKey == dateKey
    }
    // ... query and create/update
}
```

**Key Points:**
- ✅ **All queries filter by `userId`** (data isolation)
- ✅ **Guest queries use `userId == ""`**
- ✅ **No cross-user data leakage**

---

## Summary

### **Current Architecture Status:**

1. **✅ User ID Handling:** Empty string (`""`) for guest, Firebase UID for authenticated
2. **✅ SwiftData Models:** Match architecture (have `userId` fields)
3. **✅ Event-Sourcing:** Fully implemented and active
4. **✅ XP Awards:** Deterministic IDs, atomic transactions, ledger-based
5. **✅ Guest Mode:** Fully functional (works offline)
6. **❌ Cloud Sync:** Disabled (intentional for guest-only mode)
7. **✅ Data Isolation:** All queries filter by `userId`

### **Phase Assessment:**

**The app is at Phase 3-4 (Full Architecture with Event-Sourcing):**
- ✅ Event-sourcing implemented
- ✅ ProgressEvent model exists and is used
- ✅ DailyAward ledger system implemented
- ✅ Data isolation via userId
- ⚠️ Sync disabled (by design for guest mode)

### **Architecture Compliance:**

**Matches Architecture Document:**
- ✅ DailyAward is source of truth (ledger)
- ✅ UserProgressData is derived (materialized view)
- ✅ ProgressEvent is source of truth (event-sourcing)
- ✅ CompletionRecord is materialized view (for queries)

**Ready for:**
- ✅ Guest-only operation (offline)
- ✅ Event replay for progress calculation
- ✅ XP integrity checks
- ⚠️ Sync (disabled but code exists)

---

**Generated from codebase analysis on current implementation**

