# Missing Habit Diagnosis Report

**Date:** Generated from codebase analysis  
**Purpose:** Answer 7 diagnostic questions about a missing habit

---

## Executive Summary

Based on codebase analysis, the most likely cause of the missing habit is a **filtering mismatch**:
- **Firebase queries** filter by `isActive == true` 
- **SwiftData queries** filter only by `userId` (no `isActive` filtering)
- **UI filtering** uses `endDate` to determine active/inactive status

If a habit has `isActive == false` in Firebase but exists in SwiftData, it will appear locally but not from Firebase.

---

## Question 1: Identify the Missing Habit

### Firebase Habits Query (FirestoreService.swift:168)
```swift
let snapshot = try await db.collection("users")
  .document(userId)
  .collection("habits")
  .whereField("isActive", isEqualTo: true)  // ⚠️ FILTER: Only active habits
  .getDocuments()
```

**Key Finding:** Firebase only returns habits where `isActive == true`.

### SwiftData Habits Query (SwiftDataStorage.swift:417-419)
```swift
descriptor.predicate = #Predicate<HabitData> { habitData in
  habitData.userId == userId  // ✅ FILTER: Only userId (no isActive filter)
}
```

**Key Finding:** SwiftData queries filter ONLY by `userId` - no `isActive`, `isDeleted`, or `isArchived` filtering.

### Answer to Question 1:

**To identify the missing habit, you need to:**
1. **Query Firebase WITHOUT the `isActive` filter** to see all 3 habits
2. **Query SwiftData with `userId` filter** to see the 2 habits showing locally
3. **Compare the results** - the habit that exists in Firebase but NOT in local SwiftData is the missing one

**Diagnostic Query (Firebase):**
```swift
// Remove the isActive filter to see ALL habits
let snapshot = try await db.collection("users")
  .document(userId)
  .collection("habits")
  // .whereField("isActive", isEqualTo: true)  // ⚠️ REMOVED
  .getDocuments()
```

**Diagnostic Query (SwiftData):**
```swift
// Query ALL habits (no predicate) to see raw data
let descriptor = FetchDescriptor<HabitData>()
let allHabits = try modelContext.fetch(descriptor)
```

---

## Question 2: Check the Missing Habit's Properties in Firebase

### FirestoreHabit Model Structure (FirestoreModels.swift:16-41)

The `FirestoreHabit` model has these fields:
- `id: String?`
- `name: String`
- `description: String`
- `icon: String`
- `color: String`
- `habitType: String`
- `schedule: String`
- `goal: String`
- `reminder: String`
- `startDate: Date`
- `endDate: Date?`
- `createdAt: Date`
- `reminders: [String]`
- `baseline: Int`
- `target: Int`
- `completionHistory: [String: Int]`
- `completionStatus: [String: Bool]`
- `completionTimestamps: [String: [Date]]`
- `difficultyHistory: [String: Int]`
- `actualUsage: [String: Int]`
- **`isActive: Bool`** ✅ **THIS IS THE KEY FIELD**
- `lastSyncedAt: Date?`
- `syncStatus: String?`

**Important Notes:**
- ❌ **NO `isDeleted` field** - the model doesn't have this
- ❌ **NO `isArchived` field** - the model doesn't have this
- ✅ **`isActive: Bool`** - this is used for filtering

### Answer to Question 2:

**For the missing habit in Firebase, check these fields:**

```swift
// Diagnostic code to fetch ALL habits (including inactive)
let snapshot = try await db.collection("users")
  .document(userId)
  .collection("habits")
  .getDocuments()  // No filter - get ALL habits

for doc in snapshot.documents {
  let data = doc.data()
  print("Habit ID: \(doc.documentID)")
  print("  Name: \(data["name"] ?? "N/A")")
  print("  isActive: \(data["isActive"] ?? "N/A")")  // ⚠️ KEY FIELD
  print("  userId: \(userId)")  // Check if matches current user
  print("  createdAt: \(data["createdAt"] ?? "N/A")")
  print("  endDate: \(data["endDate"] ?? "nil")")
  // Note: isDeleted and isArchived don't exist in FirestoreHabit
}
```

**Most likely finding:** The missing habit has `isActive == false` in Firebase.

---

## Question 3: Check Local Database State

### SwiftData HabitData Model (HabitDataModel.swift:56-87)

The `HabitData` model has these fields:
- `id: UUID`
- `userId: String` ✅ **Filtered by this**
- `name: String`
- `habitDescription: String`
- `icon: String`
- `colorData: Data`
- `habitType: String`
- `schedule: String`
- `goal: String`
- `reminder: String`
- `startDate: Date`
- `endDate: Date?`
- `createdAt: Date`
- `updatedAt: Date`
- `baseline: Int`
- `target: Int`
- `bestStreakEver: Int`

**Important Notes:**
- ❌ **NO `isDeleted` field** - the model doesn't have this
- ❌ **NO `isArchived` field** - the model doesn't have this  
- ❌ **NO `isActive` field** - the model doesn't have this
- ✅ **`userId: String`** - this is the ONLY filter applied in queries

### Answer to Question 3:

**To check if the missing habit exists in SwiftData at all:**

```swift
// Query ALL habits without any predicates/filters
let descriptor = FetchDescriptor<HabitData>()  // No predicate = all habits
let allHabits = try modelContext.fetch(descriptor)

print("Total habits in SwiftData: \(allHabits.count)")
for habit in allHabits {
  print("  ID: \(habit.id.uuidString)")
  print("  Name: \(habit.name)")
  print("  userId: '\(habit.userId)'")
  print("  createdAt: \(habit.createdAt)")
  print("  endDate: \(habit.endDate?.description ?? "nil")")
}
```

**Expected finding:**
- If the habit exists in SwiftData, it will appear in this query
- If it doesn't appear, it was never synced from Firebase or was deleted locally

---

## Question 4: Investigate Filtering Logic

### Filtering in Firebase (FirestoreService.swift:168)
```swift
.whereField("isActive", isEqualTo: true)  // ⚠️ Only active habits returned
```

### Filtering in SwiftData (SwiftDataStorage.swift:417-419)
```swift
descriptor.predicate = #Predicate<HabitData> { habitData in
  habitData.userId == userId  // ✅ Only userId filter (no isActive, isDeleted, isArchived)
}
```

### Filtering in UI (HabitsTabView.swift:179-194)
```swift
// Active tab - filters by endDate
return uniqueHabits.filter { habit in
  let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
  return today <= endDate  // ✅ Active = hasn't ended yet
}

// Inactive tab - filters by endDate
return uniqueHabits.filter { habit in
  let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
  return today > endDate  // ✅ Inactive = end date has passed
}
```

### Answer to Question 4:

**Filters applied when fetching habits:**

| Source | Filters Applied |
|--------|----------------|
| **Firebase** | `isActive == true` (hard filter in query) |
| **SwiftData** | `userId == currentUserId` (no `isActive`, `isDeleted`, `isArchived` filters) |
| **UI (Active Tab)** | `endDate >= today` (computed filter) |
| **UI (Inactive Tab)** | `endDate < today` (computed filter) |

**Key Issues:**
1. **Firebase filters by `isActive`** - if `isActive == false`, the habit won't appear in Firebase queries
2. **SwiftData doesn't filter by `isActive`** - all habits with matching `userId` will appear locally
3. **No `isDeleted` or `isArchived` fields** exist in either model - these don't affect filtering
4. **UI uses `endDate`** to determine active/inactive, not `isActive`

**Most likely scenario:** A habit with `isActive == false` in Firebase but exists in SwiftData will:
- ✅ Appear in local SwiftData queries
- ❌ NOT appear in Firebase queries
- ⚠️ May or may not appear in UI depending on `endDate`

---

## Question 5: Check User ID Matching

### Current User ID Retrieval (FirestoreService.swift:161-163)
```swift
guard let userId = currentUserId else {
  throw FirestoreServiceError.notAuthenticated
}
```

Where `currentUserId` comes from `FirebaseConfiguration.currentUserId` (AppFirebase.swift:121-123):
```swift
static var currentUserId: String? {
  Auth.auth().currentUser?.uid
}
```

### Answer to Question 5:

**To check if the missing habit has the same `userId` as the currently authenticated user:**

```swift
// Get current user ID
let currentUserId = FirebaseConfiguration.currentUserId ?? ""
print("Current authenticated userId: '\(currentUserId)'")

// Check Firebase habit's userId (it's in the collection path)
let snapshot = try await db.collection("users")
  .document(currentUserId)  // ✅ This is the userId filter
  .collection("habits")
  .getDocuments()  // No filter to see all habits

// Check SwiftData habit's userId
let descriptor = FetchDescriptor<HabitData>()
let allHabits = try modelContext.fetch(descriptor)
for habit in allHabits {
  print("Habit '\(habit.name)': userId = '\(habit.userId)'")
  if habit.userId != currentUserId {
    print("  ⚠️ MISMATCH: Habit userId doesn't match current user!")
  }
}
```

**Expected finding:**
- If the habit was created under a different auth session, it would have a different `userId`
- However, Firebase queries filter by collection path (`users/{userId}/habits`), so habits with different `userId` won't appear at all
- SwiftData queries filter by `userId == currentUserId`, so habits with different `userId` won't appear locally either

**Most likely scenario:** If the habit appears in Firebase but not locally (or vice versa), it's likely a sync issue, not a `userId` mismatch.

---

## Question 6: Look for Sync/Migration Issues

### ProgressEvent Table (ProgressEvent.swift:23-63)

The `ProgressEvent` model tracks habit events:
- `habitId: UUID` - links events to habits
- `dateKey: String` - date the event applies to
- `eventType: String` - type of progress change
- `progressDelta: Int` - change in progress
- `createdAt: Date`
- `deletedAt: Date?` - soft delete flag

### Query ProgressEvents for Missing Habit (ProgressEvent.swift:286-294)
```swift
/// Fetch all events for a habit (for audit trail / debugging)
public static func allEventsForHabit(habitId: UUID) -> FetchDescriptor<ProgressEvent> {
  let predicate = #Predicate<ProgressEvent> { event in
    event.habitId == habitId
  }
  
  var descriptor = FetchDescriptor(predicate: predicate)
  descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
  return descriptor
}
```

### Answer to Question 6:

**To check if there are events for the missing habit:**

```swift
// Get the missing habit's ID (from Firebase or SwiftData diagnostic query)
let missingHabitId = UUID(...)  // Replace with actual ID

// Query ProgressEvents for this habit
let descriptor = ProgressEvent.allEventsForHabit(habitId: missingHabitId)
let events = try modelContext.fetch(descriptor)

print("ProgressEvents for missing habit: \(events.count)")
for event in events {
  print("  Event: \(event.eventType) on \(event.dateKey) - delta: \(event.progressDelta)")
}

// Also check CompletionRecords
let completionDescriptor = FetchDescriptor<CompletionRecord>(
  predicate: #Predicate<CompletionRecord> { record in
    record.habitId == missingHabitId
  }
)
let records = try modelContext.fetch(completionDescriptor)
print("CompletionRecords for missing habit: \(records.count)")
```

**Migration Issues to Check:**
1. **Guest to Authenticated Migration** (SwiftDataStorage.swift:448-477):
   - If habits were created with `userId == ""` (guest) and user later authenticated, they might need migration
   
2. **Schema Migrations** (HabittoMigrationPlan.swift):
   - Check if there were recent migrations that might have affected habit visibility

**Most likely scenario:**
- If events exist for the missing habit, it means the habit was active at some point
- If no events exist, the habit might be newly created or never had any activity
- Check migration logs to see if recent migrations affected this habit

---

## Question 7: Check for Data Validation Failures

### Validation in Firebase (FirestoreService.swift:182-192)
```swift
habits = fetchedHabits.filter { habit in
  // Skip breaking habits with invalid target/baseline (this is a real validation error)
  if habit.habitType == .breaking {
    let isValid = habit.target < habit.baseline && habit.baseline > 0
    if !isValid {
      print("⚠️ Skipping invalid breaking habit: '\(habit.name)'")
      return false
    }
  }
  return true
}
```

### Validation in SwiftData (HabitDataModel.swift:483-661)

The `toHabit()` method converts `HabitData` to `Habit` and doesn't filter invalid habits - it returns all habits that exist in SwiftData.

### Answer to Question 7:

**To check if the missing habit has any required fields that are nil or invalid:**

```swift
// For Firebase habits
let snapshot = try await db.collection("users")
  .document(userId)
  .collection("habits")
  .getDocuments()

for doc in snapshot.documents {
  let data = doc.data()
  let habitId = doc.documentID
  
  // Check required fields
  let requiredFields = [
    "name", "description", "icon", "color", "habitType", 
    "schedule", "goal", "reminder", "startDate", "createdAt",
    "isActive", "baseline", "target"
  ]
  
  for field in requiredFields {
    if data[field] == nil {
      print("⚠️ Habit \(habitId) missing required field: \(field)")
    }
  }
  
  // Check breaking habit validation
  if let habitType = data["habitType"] as? String,
     habitType == "breaking" {
    let target = data["target"] as? Int ?? 0
    let baseline = data["baseline"] as? Int ?? 0
    if !(target < baseline && baseline > 0) {
      print("⚠️ Habit \(habitId) is invalid breaking habit (target: \(target), baseline: \(baseline))")
    }
  }
}

// For SwiftData habits
let descriptor = FetchDescriptor<HabitData>()
let allHabits = try modelContext.fetch(descriptor)

for habit in allHabits {
  // Check required fields (all should be non-nil except endDate)
  if habit.name.isEmpty {
    print("⚠️ Habit \(habit.id) has empty name")
  }
  if habit.userId.isEmpty && currentUserId != nil {
    print("⚠️ Habit \(habit.id) has empty userId but user is authenticated")
  }
  
  // Check breaking habit validation
  if habit.habitTypeEnum == .breaking {
    if !(habit.target < habit.baseline && habit.baseline > 0) {
      print("⚠️ Habit \(habit.id) '\(habit.name)' is invalid breaking habit")
    }
  }
}
```

**Expected findings:**
- **Breaking habits** with `target >= baseline` or `baseline <= 0` will be **filtered out** in Firebase (but NOT in SwiftData)
- **Missing required fields** would cause decode failures, not filtering
- **Empty `userId`** would cause the habit to not appear in SwiftData queries (but might appear in Firebase if it's in the correct collection)

**Most likely scenario:**
- If the habit is a **breaking habit with invalid `target`/`baseline`**, it will be filtered out in Firebase queries but will still appear in SwiftData
- Check logs for: `"⚠️ Skipping invalid breaking habit: '<name>'"`

---

## Recommended Diagnostic Steps

### Step 1: Query Firebase Without Filters
```swift
// Remove the isActive filter to see ALL habits
let snapshot = try await db.collection("users")
  .document(userId)
  .collection("habits")
  // .whereField("isActive", isEqualTo: true)  // REMOVED
  .getDocuments()

for doc in snapshot.documents {
  let data = doc.data()
  print("Firebase Habit:")
  print("  ID: \(doc.documentID)")
  print("  Name: \(data["name"] ?? "N/A")")
  print("  isActive: \(data["isActive"] ?? "N/A")")
}
```

### Step 2: Query SwiftData Without Filters
```swift
// Query ALL habits (no predicate)
let descriptor = FetchDescriptor<HabitData>()
let allHabits = try modelContext.fetch(descriptor)

for habit in allHabits {
  print("SwiftData Habit:")
  print("  ID: \(habit.id.uuidString)")
  print("  Name: \(habit.name)")
  print("  userId: '\(habit.userId)'")
}
```

### Step 3: Compare Results
- Habit in Firebase but NOT in SwiftData = Sync issue (habit not synced locally)
- Habit in SwiftData but NOT in Firebase = Sync issue (habit not synced to Firebase)
- Habit in Firebase with `isActive == false` but in SwiftData = **This is the missing habit**

### Step 4: Check Validation
```swift
// Check if breaking habit validation is causing filtering
if habit.habitType == "breaking" {
  let target = data["target"] as? Int ?? 0
  let baseline = data["baseline"] as? Int ?? 0
  if !(target < baseline && baseline > 0) {
    print("⚠️ INVALID BREAKING HABIT - Will be filtered in Firebase")
  }
}
```

---

## Conclusion

**Most Likely Root Cause:**
The missing habit has `isActive == false` in Firebase, causing it to be filtered out by the `.whereField("isActive", isEqualTo: true)` query, while it still exists in SwiftData (which doesn't filter by `isActive`).

**Recommended Fix:**
1. **Temporary:** Query Firebase without the `isActive` filter to confirm all 3 habits exist
2. **Permanent:** Either:
   - Sync `isActive` status from Firebase to SwiftData and filter locally, OR
   - Remove the `isActive` filter from Firebase queries and use `endDate` for filtering (consistent with UI)

---

**Generated from codebase analysis on:** `date`
**Files Analyzed:**
- `Core/Services/FirestoreService.swift`
- `Core/Data/SwiftData/SwiftDataStorage.swift`
- `Core/Models/FirestoreModels.swift`
- `Core/Data/SwiftData/HabitDataModel.swift`
- `Views/Tabs/HabitsTabView.swift`
- `Core/Models/ProgressEvent.swift`
