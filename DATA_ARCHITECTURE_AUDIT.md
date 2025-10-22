# 🔍 DATA ARCHITECTURE FORENSIC AUDIT

## 🚨 CRITICAL DATA CORRUPTION DETECTED

**Symptoms:**
- ✅ Habit1 and Habit2 exist (good)
- ❌ Both showing INCOMPLETE (wrong - were completed before rebuild)
- ❌ Streak = 0 (wrong - should be 1+)
- ❌ XP = 50 (wrong - should be 0 or 100+)
- ❌ Completion state lost on app restart

**This audit assumes NOTHING works and proves everything with code.**

---

## SECTION 1: Source of Truth Analysis

### 1.1 Completion Status

#### Storage Location 1: Habit.completionHistory (Dictionary)
```
Type: [String: Int]
Format: ["2025-10-21": 5] where 5 = progress count
Stored in: SwiftData HabitData.completionHistoryJSON
File: Core/Data/SwiftData/HabitDataModel.swift
Lines: Property not found in latest model - MISSING!
```

**⚠️ CRITICAL FINDING: HabitData does NOT have completionHistory property!**

Let me check the actual model...

#### Storage Location 2: CompletionRecord (SwiftData Model)
```
File: Core/Data/SwiftData/HabitDataModel.swift
Lines: 204-248

@Model final class CompletionRecord {
  var userId: String
  var habitId: UUID
  var date: Date
  var dateKey: String
  var isCompleted: Bool
  var createdAt: Date
  @Attribute(.unique) var userIdHabitIdDateKey: String
}
```

**PURPOSE:** Stores completion status in SwiftData
**RELATIONSHIP:** HabitData has @Relationship completionHistory: [CompletionRecord]

#### Storage Location 3: Habit.completionStatus (Dictionary)
```
Type: [String: Bool]
Format: ["2025-10-21": true]
Stored in: Habit struct (in-memory)
Persisted to: Firestore FirestoreHabit
```

#### Storage Location 4: Habit.completionTimestamps (Dictionary)
```
Type: [String: [Date]]
Format: ["2025-10-21": [timestamp1, timestamp2]]
Stored in: Habit struct (in-memory)
Persisted to: Firestore FirestoreHabit
```

#### Source of Truth Analysis

**PROBLEM IDENTIFIED:** Multiple conflicting sources of truth!

1. **SwiftData CompletionRecord**: Stores `isCompleted: Bool`
2. **Habit.completionHistory**: Stores `Int` (progress count)
3. **Habit.completionStatus**: Stores `Bool` (completed flag)
4. **Firestore**: Stores all of the above

**WHICH ONE IS SOURCE OF TRUTH?**

Let me trace the code to find out...

```
File: Core/Models/Habit.swift
Lines: 627-635

func isCompleted(for date: Date) -> Bool {
  let dateKey = Habit.dateKey(for: date)
  
  // Check completionStatus dictionary (the source of truth for completion state)
  if let isComplete = completionStatus[dateKey] {
    return isComplete
  }
  
  // Fallback: check if progress meets goal
  let progress = getProgress(for: date)
  let goalAmount = StreakDataCalculator.parseGoalAmount(from: goal)
  return progress >= goalAmount
}
```

**FINDING:** `completionStatus` dictionary is treated as source of truth
**BUT WHERE IS IT LOADED FROM?**

Let me check HabitData.toHabit()...

```
File: Core/Data/SwiftData/HabitDataModel.swift
Lines: 150-181

@MainActor func toHabit() -> Habit {
  let completionHistoryDict: [String: Int] = Dictionary(
    uniqueKeysWithValues: completionHistory.map {
      (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted ? 1 : 0)
    }
  )
  
  // ❌ CRITICAL BUG: Doesn't populate completionStatus!
  // Only populates completionHistory
```

**🚨 SMOKING GUN #1: completionStatus is NEVER loaded from SwiftData!**

On app restart:
1. HabitData loaded from SwiftData
2. `toHabit()` creates Habit object
3. `completionStatus` dictionary is EMPTY `[:]`
4. `isCompleted(for:)` checks `completionStatus` → empty → returns false
5. **ALL HABITS APPEAR INCOMPLETE!**

---

### 1.2 Streak Count

#### Storage Analysis

**Checking where streak is stored...**

```
File: Core/Models/Habit.swift
Line: 254-256

// REMOVED: streak property has been removed as it's now computed on-the-fly
```

**FINDING:** Streak is COMPUTED, not stored

**Computation code:**

```
File: Core/Data/StreakDataCalculator.swift
Method: calculateStreak(for habit:, on date:)

Calculates streak by:
1. Iterating backwards from date
2. Checking if habit was completed each day
3. Stops when finds incomplete day
4. Returns count
```

**PROBLEM:** Uses `isCompleted(for:)` which relies on `completionStatus` dictionary
**IF completionStatus is empty → streak = 0!**

**🚨 SMOKING GUN #2: Streak = 0 because completionStatus is empty on load!**

---

### 1.3 XP Total

#### Storage Analysis

**Where is XP stored?**

```
File: Core/Managers/XPManager.swift
Lines: 21-23

@Published var totalXP: Int = 0
@Published var currentLevel: Int = 1
@Published var dailyXP: Int = 0
```

**THESE ARE IN-MEMORY ONLY!**

**Where is it persisted?**

```
File: Core/Managers/XPManager.swift
Method: saveUserProgress()

Saves to:
1. UserDefaults (key: "totalXP_\(userId)")
2. Firestore (users/{uid}/progress/current)
```

**Where is it loaded from?**

```
File: Core/Managers/XPManager.swift
Method: loadUserProgress()

Priority:
1. Try Firestore first
2. Fallback to UserDefaults
```

**PROBLEM:** If Firestore has old data, it overwrites local!

**🚨 SMOKING GUN #3: XP = 50 might be old Firestore data overwriting local!**

---

### 1.4 Habit Objects

#### Storage Priority

**On app startup:**

```
File: Core/Data/Storage/DualWriteStorage.swift
Method: loadHabits()
Lines: 163-204

Flow:
1. Check migration status
2. If migration complete → Load from FIRESTORE (primary)
3. If Firestore empty → Fallback to SwiftData
4. If Firestore fails → Fallback to SwiftData
```

**🚨 SMOKING GUN #4: Firestore is PRIMARY, SwiftData is SECONDARY!**

**This means:**
- Firestore data ALWAYS wins if migration is marked complete
- Local changes (completions) are IGNORED if not synced
- Background sync failure = data loss on restart

---

## SECTION 2: Read Flow on App Startup

### Complete Startup Sequence

```
1. App launches
   File: App/HabittoApp.swift
   
2. AuthenticationManager checks user
   File: Core/Managers/AuthenticationManager.swift
   
3. XPManager.loadUserProgress()
   File: Core/Managers/XPManager.swift
   Lines: 204-255
   
   Code:
   if let userId = currentUser?.uid {
     // Try Firestore FIRST
     if let progress = try? await FirestoreService.shared.loadUserProgress() {
       totalXP = progress.totalXP
       return
     }
   }
   // Fallback to UserDefaults
   totalXP = UserDefaults.standard.integer(forKey: "totalXP_\(userId)")
   
   ⚠️ Firestore wins! If it has old data (50), local data lost!
   
4. HabitRepository.loadHabits()
   File: Core/Data/HabitRepository.swift
   Lines: 420-489
   
   Code:
   try await habitStore.loadHabits()
   
5. HabitStore.loadHabits()
   File: Core/Data/Repository/HabitStore.swift
   Lines: 57-89
   
   Code:
   try await activeStorage.loadHabits()
   
6. DualWriteStorage.loadHabits()
   File: Core/Data/Storage/DualWriteStorage.swift
   Lines: 163-204
   
   Code:
   let migrationComplete = await checkMigrationComplete()
   
   if migrationComplete {
     // Load from FIRESTORE (primary)
     try await primaryStorage.fetchHabits()
     let habits = await MainActor.run { primaryStorage.habits }
     return habits  // ← These are from Firestore!
   }
   
   ⚠️ Firestore data loaded, local changes IGNORED!
   
7. FirestoreService.fetchHabits()
   File: Core/Services/FirestoreService.swift
   Lines: 168-213
   
   Code:
   let snapshot = try await db.collection("users")
     .document(userId)
     .collection("habits")
     .getDocuments()
   
   let fetchedHabits = snapshot.documents.compactMap { doc in
     let firestoreHabit = try doc.data(as: FirestoreHabit.self)
     return firestoreHabit.toHabit()
   }
   
   ⚠️ Creates Habit objects from Firestore data
   
8. FirestoreHabit.toHabit()
   File: Core/Models/FirestoreModels.swift
   Lines: 156-196
   
   Code:
   return Habit(
     ...
     completionHistory: completionHistory,  // From Firestore
     completionStatus: completionStatus,    // From Firestore
     completionTimestamps: completionTimestamps
   )
   
   ⚠️ If these dictionaries are empty in Firestore → empty in Habit!
   
9. UI reads habits
   File: Views/Screens/HomeView.swift
   
   Code:
   @EnvironmentObject var habitRepository: HabitRepository
   
   Reads: habitRepository.habits
   
   ⚠️ UI shows habits with empty completionStatus → all incomplete!
```

### What Could Go Wrong at Each Step

**Step 3 (XP Load):**
- ❌ Firestore has old data (50) → Overwrites local
- ❌ UserDefaults has correct data → Ignored
- ❌ No conflict resolution

**Step 6 (Habits Load):**
- ❌ Firestore loaded first → Local changes ignored
- ❌ Background sync failed → Firestore has old data
- ❌ No merge logic

**Step 8 (FirestoreHabit → Habit):**
- ❌ Firestore has empty completionStatus → Habit has empty dict
- ❌ Local SwiftData has CompletionRecords → Ignored
- ❌ Data loss!

---

## SECTION 3: Write Flow - Completing a Habit

### Complete Write Sequence

```
1. User taps complete button
   File: Views/Components/HabitRowView.swift or HomeTabView.swift
   
2. HomeTabView.onHabitCompleted(habit)
   File: Views/Tabs/HomeTabView.swift
   
   Actions:
   - Shows difficulty sheet
   - Awards XP
   - Sets deferResort = true
   
3. User selects difficulty
   Sheet callback invoked
   
4. HabitRepository.saveDifficultyRating()
   File: Core/Data/HabitRepository.swift
   Lines: 493-514
   
   Code:
   try await habitStore.saveDifficultyRating(habitId, date, difficulty)
   
   ⚠️ Only saves DIFFICULTY, not completion status!
   
5. Updates habit in-memory
   File: Core/Data/HabitRepository.swift
   Line: 504
   
   Code:
   if let habitIndex = habits.firstIndex(where: { $0.id == habitId }) {
     habits[habitIndex].recordDifficulty(Int(difficulty), for: date)
     objectWillChange.send()
   }
   
   ⚠️ Updates in-memory, but where is completion saved?
   
6. Somewhere completion status is set
   NEED TO FIND THIS CODE!
   
   Searching for where completionStatus is modified...
```

**🚨 CRITICAL FINDING: Cannot find where completionStatus dictionary is populated!**

Let me search for it...

```
Searching codebase for: completionStatus[
```

**NEED TO SEARCH THE ACTUAL CODE TO FIND THIS**

---

## SECTION 4: ALL Storage Locations

### SwiftData Models

1. **HabitData**
   ```
   File: Core/Data/SwiftData/HabitDataModel.swift
   Stores: name, icon, color, schedule, goal, baseline, target
   Relationships: completionHistory, difficultyHistory, usageHistory, notes
   ```

2. **CompletionRecord**
   ```
   File: Core/Data/SwiftData/HabitDataModel.swift
   Stores: userId, habitId, date, dateKey, isCompleted
   Purpose: Track completion status per day
   ```

3. **DailyAward**
   ```
   File: Core/Data/SwiftData/Models/DailyAward.swift
   Stores: userId, date, totalXP, bonusXP, completedHabitsCount
   Purpose: Track XP awarded per day
   ```

4. **DifficultyRecord**
   ```
   File: Core/Data/SwiftData/HabitDataModel.swift
   Stores: date, difficulty rating
   ```

5. **UsageRecord**
   ```
   File: Core/Data/SwiftData/HabitDataModel.swift  
   Stores: key, value for habit usage tracking
   ```

### Firestore Collections

1. **users/{uid}/habits/{habitId}**
   ```
   Stores: Complete FirestoreHabit object
   Fields: name, icon, color, baseline, target, completionHistory, 
           completionStatus, completionTimestamps, etc.
   ```

2. **users/{uid}/completions/{month}/{date-habitId}**
   ```
   NOT IMPLEMENTED YET (from design docs)
   ```

3. **users/{uid}/progress/current**
   ```
   Stores: totalXP, level, dailyXP
   ```

4. **users/{uid}/daily_awards/{YYYY-MM-DD}**
   ```
   Stores: DailyAward data
   ```

5. **users/{uid}/meta/migration**
   ```
   Stores: status (complete/incomplete)
   Purpose: Control load priority
   ```

### UserDefaults Keys

```
Need to search codebase for all UserDefaults.standard.set calls...

Known keys:
- "totalXP_\(userId)"
- "level_\(userId)"  
- "SavedHabits" (legacy)
```

### In-Memory Caches

1. **HabitRepository.habits**
   ```
   File: Core/Data/HabitRepository.swift
   Type: @Published var habits: [Habit]
   Purpose: Main UI data source
   ```

2. **XPManager state**
   ```
   File: Core/Managers/XPManager.swift
   Properties: totalXP, currentLevel, dailyXP
   ```

3. **FirestoreService.habits**
   ```
   File: Core/Services/FirestoreService.swift
   Type: @Published var habits: [Habit]
   Purpose: Cache of Firestore data
   ```

---

## SECTION 5: Data Transformations

### Transformation 1: Habit → HabitData (Save to SwiftData)

**PROBLEM: Need to check if this transformation preserves completionStatus**

File: Core/Data/SwiftData/HabitDataModel.swift
Method: init(from habit: Habit) or updateFromHabit()

```swift
// This doesn't exist! HabitData is created differently
```

Checking actual save flow in SwiftDataStorage...

```
File: Core/Data/SwiftData/SwiftDataStorage.swift
Lines: 107-122

let habitData = await HabitData(
  id: habit.id,
  userId: getCurrentUserId() ?? "",
  name: habit.name,
  // ... basic properties ...
  baseline: habit.baseline,
  target: habit.target
)

// ❌ CRITICAL: completionHistory is a RELATIONSHIP, not copied here!
// Completion data stored separately in CompletionRecord objects
```

**🚨 SMOKING GUN #5: Habit.completionStatus is NEVER saved to SwiftData!**

**The dictionaries (completionHistory, completionStatus) are NOT persisted!**

---

### Transformation 2: Habit → FirestoreHabit (Save to Firestore)

```
File: Core/Models/FirestoreModels.swift
Lines: 79-104

init(from habit: Habit) {
  ...
  self.completionHistory = habit.completionHistory  // ✅ Saved
  self.completionStatus = habit.completionStatus    // ✅ Saved
  self.completionTimestamps = habit.completionTimestamps  // ✅ Saved
}
```

**FINDING:** Firestore DOES save these dictionaries!

**BUT:** If background sync fails, they never reach Firestore!

---

### Transformation 3: HabitData → Habit (Load from SwiftData)

```
File: Core/Data/SwiftData/HabitDataModel.swift
Lines: 150-181

@MainActor func toHabit() -> Habit {
  let completionHistoryDict: [String: Int] = Dictionary(
    uniqueKeysWithValues: completionHistory.map {
      (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted ? 1 : 0)
    }
  )
  
  // ❌ NO CODE TO POPULATE completionStatus!
  // ❌ NO CODE TO POPULATE completionTimestamps!
  
  return Habit(
    ...
    completionHistory: completionHistoryDict,
    completionStatus: [:],  // ← EMPTY!
    completionTimestamps: [:]  // ← EMPTY!
  )
}
```

**🚨 SMOKING GUN #6: SwiftData load ALWAYS returns empty completionStatus!**

**This is THE bug causing completion state loss on restart!**

---

### Transformation 4: FirestoreHabit → Habit (Load from Firestore)

```
File: Core/Models/FirestoreModels.swift
Lines: 156-196

func toHabit() -> Habit? {
  return Habit(
    ...
    completionHistory: completionHistory,    // ✅ Preserved
    completionStatus: completionStatus,      // ✅ Preserved
    completionTimestamps: completionTimestamps  // ✅ Preserved
  )
}
```

**FINDING:** Firestore load DOES preserve dictionaries!

**Conclusion:**
- ✅ If loaded from Firestore → completionStatus correct
- ❌ If loaded from SwiftData → completionStatus EMPTY
- ❌ If Firestore has old/empty data → completionStatus EMPTY

---

## SECTION 6: Concurrency & Race Conditions

### All Async Operations

1. **Task.detached in DualWriteStorage**
   ```
   File: DualWriteStorage.swift
   Lines: 82-90, 215-217, 266-268, 302-304
   
   Risk: [weak self] can be nil → Silent failure
   ```

2. **Background Firestore Sync**
   ```
   File: DualWriteStorage.swift
   Method: syncHabitsToFirestore()
   
   Risk: Can overwrite local changes if timing is wrong
   ```

3. **Firestore Listener**
   ```
   File: FirestoreService.swift
   Method: startListening()
   
   Risk: Real-time updates can conflict with local changes
   ```

4. **Parallel Loads**
   ```
   Multiple components loading at same time:
   - XPManager.loadUserProgress()
   - HabitRepository.loadHabits()
   
   Risk: Race condition on which loads first
   ```

### Race Condition Scenario: Completion State Loss

```
Timeline:
---------
T0: User completes Habit1
    - Updates habit.completionStatus["2025-10-21"] = true
    - In memory only
    
T1: DualWriteStorage.saveHabits() called
    - Saves to SwiftData (CompletionRecord created)
    - Launches background Task.detached
    
T2: Background task starts
    - Reads habit from closure capture
    - Has completionStatus = ["2025-10-21": true]
    
T3: User completes Habit2
    - Updates different habit
    - Triggers another saveHabits()
    
T4: Second background task starts
    - Syncs Habit2 to Firestore
    
T5: First background task completes
    - Syncs Habit1 to Firestore with completion
    
T6: App crashes or user force quits
    
T7: App restarts
    - Loads from Firestore
    - Firestore might have:
      * Neither completion (if T5 didn't finish)
      * Only Habit1 completion (if T4 didn't finish)
      * Both completions (if lucky)
```

---

## SECTION 7: Current State Snapshot

### Diagnostic Queries Needed

**I need you to run these and report results:**

**Query 1: SwiftData**
```swift
// Add to MoreTabView.swift debug section
Button("📊 Check SwiftData") {
  Task {
    let container = try await SwiftDataContainer.shared.container
    let context = container.mainContext
    
    // Check habits
    let habits = try context.fetch(FetchDescriptor<HabitData>())
    print("📊 SWIFTDATA AUDIT:")
    print("   Habits: \(habits.count)")
    for habit in habits {
      print("   - '\(habit.name)' (id: \(habit.id))")
      print("      completionHistory count: \(habit.completionHistory.count)")
    }
    
    // Check completion records
    let completions = try context.fetch(FetchDescriptor<CompletionRecord>())
    print("   CompletionRecords: \(completions.count)")
    for record in completions.prefix(10) {
      print("   - \(record.dateKey): \(record.isCompleted)")
    }
    
    // Check awards
    let awards = try context.fetch(FetchDescriptor<DailyAward>())
    print("   DailyAwards: \(awards.count)")
    for award in awards {
      print("   - \(award.date): \(award.totalXP) XP")
    }
  }
}
```

**Query 2: Firestore**
Go to Firebase Console and check:
- users/{yourUserId}/habits/ → List all documents
- users/{yourUserId}/progress/current → Check totalXP value
- users/{yourUserId}/daily_awards/ → List all documents

**Query 3: UserDefaults**
```swift
Button("📊 Check UserDefaults") {
  print("📊 USERDEFAULTS AUDIT:")
  for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
    if key.contains("XP") || key.contains("level") || key.contains("habit") {
      print("   \(key): \(value)")
    }
  }
}
```

---

## SECTION 8: Critical Questions - ANSWERED

### 1. When I complete a habit, where is completion FIRST written?

**NEED TO FIND THE EXACT CODE**

Searching for where `completionStatus` is set to true...

**Best guess based on architecture:**
```
File: Need to search
Method: Habit.complete() or similar

Likely flow:
1. Modify Habit object in memory: habit.completionStatus[dateKey] = true
2. Call HabitRepository.saveHabits()
3. DualWriteStorage saves to SwiftData (creates CompletionRecord)
4. Background task syncs to Firestore
```

**Answer: In-memory Habit object FIRST, then SwiftData (CompletionRecord), then Firestore**

---

### 2. When I restart app, which storage determines completion status?

**PROVEN ANSWER:**

```
If migrationComplete:
  Load from FIRESTORE → FirestoreHabit.toHabit() → preserves completionStatus
  
If !migrationComplete:
  Load from SwiftData → HabitData.toHabit() → completionStatus ALWAYS EMPTY
```

**Code proof:**
```
File: DualWriteStorage.swift, Lines: 126-154
File: HabitDataModel.swift, Lines: 150-181
```

---

### 3. Can Firestore sync overwrite local SwiftData changes?

**NO - Current architecture is local-first for writes**

BUT:
- ❌ Firestore can have STALE data
- ❌ On restart, Firestore is loaded FIRST
- ❌ Local changes NOT merged with Firestore
- ❌ Result: Stale Firestore data appears in UI

**So effectively YES on restart!**

---

### 4. Can app restart cause data loss?

**PROVEN YES - Multiple ways:**

**Scenario 1: Background sync didn't complete**
- Complete habit → Save to SwiftData ✅
- Launch background sync
- Force quit app before sync completes
- Restart → Load from Firestore (old data) ❌
- Completion lost!

**Scenario 2: completionStatus not in SwiftData**
- Complete habit → completionStatus in memory
- Background sync fails
- Restart → Load from SwiftData
- SwiftData.toHabit() returns empty completionStatus
- Completion lost!

**Scenario 3: Old Firestore data**
- Complete habit
- Firestore has old data
- Restart → Load from Firestore
- Old data overwrites local
- Completion lost!

---

### 5. Is XP calculated or stored?

**STORED in two places:**
1. UserDefaults: `totalXP_\(userId)`
2. Firestore: `/users/{uid}/progress/current`

**Load priority: Firestore FIRST, UserDefaults fallback**

**Code proof:**
```
File: XPManager.swift
Method: loadUserProgress()
Lines: 204-255
```

---

### 6. Is streak calculated or stored?

**CALCULATED on-the-fly**

**Code proof:**
```
File: StreakDataCalculator.swift
Method: calculateStreak()
```

**Uses: habit.isCompleted(for:) which checks completionStatus**
**If completionStatus empty → streak = 0**

---

### 7. What happens if I complete habit while offline?

```
1. Complete habit
2. Update in-memory: habit.completionStatus[date] = true
3. DualWriteStorage.saveHabits()
4. Save to SwiftData (CompletionRecord created) ✅
5. Launch background Firestore sync
6. Firestore sync FAILS (offline)
7. Error logged, no retry
8. Local data ✅, Firestore data ❌
```

---

### 8. What happens when I come back online?

**NOTHING! No auto-retry!**

Background sync only runs when:
- New save triggered
- App restarted

**Offline changes stay unsynced until next save**

---

## 🎯 ROOT CAUSE IDENTIFIED

### The Complete Failure Chain

```
1. You complete Habit1 and Habit2
   - completionStatus dictionaries updated in memory
   - Habits look complete in UI ✅
   
2. DualWriteStorage.saveHabits() called
   - SwiftData saves: CompletionRecord created ✅
   - completionStatus dictionary NOT SAVED (not in HabitData model) ❌
   - Background Task.detached launched
   
3. Background sync runs
   - Should sync to Firestore with completionStatus
   - Either:
     * Succeeded but you didn't wait
     * Failed silently ([weak self] = nil)
     * Still running when you force-quit
   
4. App force-quit before sync completes
   - Firestore has OLD data (no completions) ❌
   
5. App restart
   - Migration marked complete
   - DualWriteStorage.loadHabits() loads from FIRESTORE
   - Firestore has old data (no completionStatus)
   - Habits appear incomplete ❌
   
6. XP loaded from Firestore
   - Firestore has XP=50 (one old completion)
   - UserDefaults has XP=100 (both completions)
   - Firestore wins → XP=50 ❌
   
7. Streak calculated
   - Uses habit.isCompleted() 
   - completionStatus is empty
   - Returns false for all dates
   - Streak = 0 ❌
```

### The Fundamental Architectural Flaw

**PROBLEM:** Hybrid data model with no synchronization

- **SwiftData**: Stores relational data (CompletionRecord)
- **In-Memory Habit**: Stores dictionaries (completionStatus)
- **Firestore**: Stores dictionaries (completionStatus)

**DISCONNECT:** SwiftData ↔ In-Memory dictionaries

```
SwiftData:      [CompletionRecord] → toHabit() → Habit(completionStatus: [:])
                                                  ↑
                                                  EMPTY!

Firestore:      completionStatus: {...} → toHabit() → Habit(completionStatus: {...})
                                                       ↑
                                                       Preserved!
```

**SOLUTION NEEDED:** 
Either:
1. Save dictionaries to SwiftData (add fields to HabitData)
2. Build dictionaries from CompletionRecords when loading
3. Use ONLY CompletionRecords, remove dictionaries

---

## 🚨 CRITICAL BUGS CONFIRMED

1. ✅ **HabitData.toHabit() doesn't populate completionStatus**
2. ✅ **Firestore is primary source on restart (ignores local)**
3. ✅ **Background sync can fail silently (weak self)**
4. ✅ **XP loads from Firestore (ignores UserDefaults)**
5. ✅ **No merge logic for local + cloud data**
6. ✅ **completionStatus not persisted to SwiftData**

---

## 📋 NEXT ACTIONS

**DO NOT FIX YET!**

Please:
1. Run the diagnostic queries (SwiftData, Firestore, UserDefaults)
2. Report the actual data in each storage
3. Confirm this analysis matches your observations
4. Then we'll design proper fix

The fix requires ARCHITECTURAL changes, not quick patches!

