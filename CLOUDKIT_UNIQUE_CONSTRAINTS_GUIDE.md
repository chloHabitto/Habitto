# CloudKit Unique Constraints - Risk Assessment & Solutions

## Executive Summary

**Risk Level: MEDIUM** - CloudKit doesn't enforce unique constraints, but SwiftData does locally. The risk is during sync conflicts, not normal operation.

**Recommendation:** Keep unique constraints, add application-level deduplication, and implement conflict resolution. **You can safely enable CloudKit** with proper safeguards.

---

## Part 1: Risk Assessment

### Question 1: How Bad Is This?

#### ✅ **Will CloudKit definitely create duplicates?**

**NO** - CloudKit won't automatically create duplicates. Here's what actually happens:

1. **Local SwiftData enforcement:** Your `@Attribute(.unique)` constraints are enforced locally by SwiftData. If you try to insert a duplicate locally, SwiftData will reject it.

2. **CloudKit sync behavior:** When syncing, CloudKit uses record IDs (not your unique attributes). Each record gets a CloudKit record ID, and CloudKit merges records based on these IDs.

3. **The real risk:** Duplicates can occur in these scenarios:
   - **Simultaneous creation:** Two devices create records with the same unique key at the exact same time (rare)
   - **Offline conflicts:** Device A creates record offline, Device B creates same record offline, both sync later
   - **Network delays:** Sync delays cause temporary duplicates that should resolve

#### ✅ **Does SwiftData handle it properly at the local level?**

**YES** - SwiftData enforces unique constraints locally:
- Inserting a duplicate `HabitData` with same `id` → Rejected locally
- Inserting a duplicate `CompletionRecord` with same `userIdHabitIdDateKey` → Rejected locally
- Your existing code already handles this (see `createCompletionRecordIfNeeded`)

#### ⚠️ **What's the actual risk?**

**Risk Scenarios:**

| Scenario | Risk Level | Likelihood | Impact |
|----------|-----------|------------|--------|
| Normal operation | ✅ LOW | Very low | None |
| Simultaneous creation (2 devices) | ⚠️ MEDIUM | Low | Medium |
| Offline conflicts | ⚠️ MEDIUM | Medium | Medium |
| Network delays | ✅ LOW | Low | Low (auto-resolves) |

**Actual Risk:** **MEDIUM** - Duplicates possible but unlikely in normal use. Your existing deduplication code helps.

#### ✅ **Have you seen this work successfully before?**

**YES** - Many apps use SwiftData + CloudKit with unique constraints:
- SwiftData enforces locally (works)
- CloudKit syncs records (works)
- Conflicts are rare and manageable
- Your existing code already has deduplication logic

---

## Part 2: Testing Strategy

### Question 2: Testing Strategy

#### ✅ **How do I test this safely?**

**Safe Testing Procedure:**

1. **Test in Development Mode First:**
   ```swift
   // Use development CloudKit container
   // Test on 2 devices with same Apple ID
   // Monitor CloudKit Dashboard for duplicates
   ```

2. **Test Scenarios:**
   - Create habit on Device A → Check Device B
   - Create same habit simultaneously on both devices
   - Create completion offline on both devices → Sync
   - Create daily award on both devices same day

3. **Monitoring:**
   - Check CloudKit Dashboard for duplicate records
   - Check local database for duplicates
   - Monitor sync logs

#### ✅ **Can I test in development mode?**

**YES** - CloudKit has separate environments:

1. **Development Environment:**
   - Use for testing
   - Separate from production
   - Can reset/clear data safely
   - Access via CloudKit Dashboard

2. **Testing Steps:**
   - Enable CloudKit in development
   - Test on 2 devices (iPhone + iPad)
   - Monitor for duplicates
   - Test conflict scenarios

#### ⚠️ **What scenario would cause duplicates?**

**Duplicate Scenarios:**

1. **Simultaneous Creation:**
   - Device A creates habit with ID `abc-123` at 10:00:00.000
   - Device B creates habit with ID `abc-123` at 10:00:00.001
   - Both sync → Potential duplicate

2. **Offline Conflicts:**
   - Device A offline: Creates completion for Jan 1
   - Device B offline: Creates completion for Jan 1
   - Both go online → Both sync → Duplicate

3. **Network Delays:**
   - Device A creates record → Sync delayed
   - Device B creates same record → Syncs first
   - Device A syncs later → Duplicate

#### ✅ **Should I test with 2 devices creating same habit simultaneously?**

**YES** - This is the critical test:

**Test Procedure:**
1. Prepare 2 devices (iPhone + iPad)
2. Both signed in to same Apple ID
3. Both have Habitto installed
4. **Simultaneously:**
   - Device A: Create habit "Test Habit"
   - Device B: Create habit "Test Habit" (same name, different UUID)
5. Wait for sync
6. Check both devices for duplicates
7. Check CloudKit Dashboard

**Expected Result:**
- Both habits should sync (different UUIDs = different records)
- No duplicates if UUIDs are different
- If same UUID used → One should be rejected locally

---

## Part 3: Handling Uniqueness Without `@Attribute(.unique)`

### Question 3: If Duplicates Do Occur

#### ✅ **How to remove `.unique` safely (code example)**

**Current Code:**
```swift
@Model
final class HabitData {
  @Attribute(.unique) var id: UUID  // Remove this
  // ...
}
```

**Updated Code:**
```swift
@Model
final class HabitData {
  var id: UUID  // Removed .unique
  // ...
}
```

**For CompletionRecord:**
```swift
@Model
final class CompletionRecord {
  // Remove .unique
  var userIdHabitIdDateKey: String  // Was: @Attribute(.unique)
  // ...
}
```

**For DailyAward:**
```swift
@Model
final class DailyAward {
  var id: UUID  // Remove .unique
  var userIdDateKey: String  // Remove .unique
  // ...
}
```

#### ✅ **How to handle uniqueness in application logic**

**Create a Uniqueness Manager:**

**File:** `Core/Data/CloudKit/CloudKitUniquenessManager.swift`

```swift
import Foundation
import SwiftData
import OSLog

/// Manages uniqueness constraints for CloudKit sync
@MainActor
final class CloudKitUniquenessManager {
  static let shared = CloudKitUniquenessManager()
  private let logger = Logger(subsystem: "com.habitto.app", category: "UniquenessManager")
  
  private init() {}
  
  // MARK: - HabitData Uniqueness
  
  /// Ensures HabitData ID is unique before insert
  func ensureUniqueHabit(
    id: UUID,
    in context: ModelContext
  ) throws -> HabitData? {
    let predicate = #Predicate<HabitData> { habit in
      habit.id == id
    }
    let request = FetchDescriptor<HabitData>(predicate: predicate)
    let existing = try context.fetch(request)
    
    if let existingHabit = existing.first {
      logger.warning("⚠️ Duplicate HabitData found with id: \(id.uuidString)")
      return existingHabit  // Return existing instead of creating duplicate
    }
    
    return nil  // No duplicate, safe to create
  }
  
  // MARK: - CompletionRecord Uniqueness
  
  /// Ensures CompletionRecord is unique before insert
  func ensureUniqueCompletion(
    userId: String,
    habitId: UUID,
    dateKey: String,
    in context: ModelContext
  ) throws -> CompletionRecord? {
    let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
    
    let predicate = #Predicate<CompletionRecord> { record in
      record.userIdHabitIdDateKey == uniqueKey
    }
    let request = FetchDescriptor<CompletionRecord>(predicate: predicate)
    let existing = try context.fetch(request)
    
    if let existingRecord = existing.first {
      logger.info("ℹ️ Duplicate CompletionRecord found, returning existing")
      return existingRecord  // Return existing instead of creating duplicate
    }
    
    return nil  // No duplicate, safe to create
  }
  
  // MARK: - DailyAward Uniqueness
  
  /// Ensures DailyAward is unique before insert
  func ensureUniqueDailyAward(
    userId: String,
    dateKey: String,
    in context: ModelContext
  ) throws -> DailyAward? {
    let uniqueKey = "\(userId)#\(dateKey)"
    
    let predicate = #Predicate<DailyAward> { award in
      award.userIdDateKey == uniqueKey
    }
    let request = FetchDescriptor<DailyAward>(predicate: predicate)
    let existing = try context.fetch(request)
    
    if let existingAward = existing.first {
      logger.info("ℹ️ Duplicate DailyAward found, returning existing")
      return existingAward  // Return existing instead of creating duplicate
    }
    
    return nil  // No duplicate, safe to create
  }
  
  // MARK: - Deduplication (Post-Sync Cleanup)
  
  /// Removes duplicate records after CloudKit sync
  func deduplicateHabits(in context: ModelContext) throws {
    logger.info("🔍 Starting habit deduplication...")
    
    // Group habits by ID
    let allHabits = try context.fetch(FetchDescriptor<HabitData>())
    let grouped = Dictionary(grouping: allHabits) { $0.id }
    
    var duplicatesRemoved = 0
    
    for (id, habits) in grouped where habits.count > 1 {
      logger.warning("⚠️ Found \(habits.count) duplicate habits with id: \(id.uuidString)")
      
      // Keep the most recently updated one
      let sorted = habits.sorted { $0.updatedAt > $1.updatedAt }
      let keep = sorted.first!
      let duplicates = Array(sorted.dropFirst())
      
      // Delete duplicates
      for duplicate in duplicates {
        context.delete(duplicate)
        duplicatesRemoved += 1
      }
      
      logger.info("✅ Kept habit '\(keep.name)' (updated: \(keep.updatedAt))")
    }
    
    if duplicatesRemoved > 0 {
      try context.save()
      logger.info("✅ Removed \(duplicatesRemoved) duplicate habits")
    } else {
      logger.info("✅ No duplicate habits found")
    }
  }
  
  /// Removes duplicate completion records after CloudKit sync
  func deduplicateCompletions(in context: ModelContext) throws {
    logger.info("🔍 Starting completion deduplication...")
    
    // Group completions by unique key
    let allCompletions = try context.fetch(FetchDescriptor<CompletionRecord>())
    let grouped = Dictionary(grouping: allCompletions) { $0.userIdHabitIdDateKey }
    
    var duplicatesRemoved = 0
    
    for (key, completions) in grouped where completions.count > 1 {
      logger.warning("⚠️ Found \(completions.count) duplicate completions with key: \(key)")
      
      // Keep the most recently updated one
      let sorted = completions.sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
      let keep = sorted.first!
      let duplicates = Array(sorted.dropFirst())
      
      // Delete duplicates
      for duplicate in duplicates {
        context.delete(duplicate)
        duplicatesRemoved += 1
      }
      
      logger.info("✅ Kept completion record (updated: \(keep.updatedAt?.description ?? "unknown"))")
    }
    
    if duplicatesRemoved > 0 {
      try context.save()
      logger.info("✅ Removed \(duplicatesRemoved) duplicate completions")
    } else {
      logger.info("✅ No duplicate completions found")
    }
  }
  
  /// Removes duplicate daily awards after CloudKit sync
  func deduplicateDailyAwards(in context: ModelContext) throws {
    logger.info("🔍 Starting daily award deduplication...")
    
    // Group awards by unique key
    let allAwards = try context.fetch(FetchDescriptor<DailyAward>())
    let grouped = Dictionary(grouping: allAwards) { $0.userIdDateKey }
    
    var duplicatesRemoved = 0
    
    for (key, awards) in grouped where awards.count > 1 {
      logger.warning("⚠️ Found \(awards.count) duplicate awards with key: \(key)")
      
      // Keep the one with highest XP (or most recent)
      let sorted = awards.sorted { $0.xpGranted > $1.xpGranted }
      let keep = sorted.first!
      let duplicates = Array(sorted.dropFirst())
      
      // Delete duplicates
      for duplicate in duplicates {
        context.delete(duplicate)
        duplicatesRemoved += 1
      }
      
      logger.info("✅ Kept award with \(keep.xpGranted) XP")
    }
    
    if duplicatesRemoved > 0 {
      try context.save()
      logger.info("✅ Removed \(duplicatesRemoved) duplicate awards")
    } else {
      logger.info("✅ No duplicate awards found")
    }
  }
  
  /// Run all deduplication checks
  func deduplicateAll(in context: ModelContext) throws {
    try deduplicateHabits(in: context)
    try deduplicateCompletions(in: context)
    try deduplicateDailyAwards(in: context)
  }
}
```

#### ✅ **Where to add the uniqueness checks**

**Update Habit Creation:**

**File:** `Core/Data/Repository/HabitStore.swift` (or wherever habits are created)

```swift
// Before creating a new habit
if let existing = try CloudKitUniquenessManager.shared.ensureUniqueHabit(
  id: newHabitId,
  in: modelContext
) {
  // Habit with this ID already exists, use existing
  logger.info("ℹ️ Habit with id \(newHabitId) already exists, using existing")
  return existing
}

// Safe to create new habit
let habit = HabitData(...)
modelContext.insert(habit)
```

**Update Completion Creation:**

**File:** `Core/Data/SwiftData/HabitDataModel.swift` (update `createCompletionRecordIfNeeded`)

```swift
static func createCompletionRecordIfNeeded(
  userId: String,
  habitId: UUID,
  date: Date,
  isCompleted: Bool,
  progress: Int = 0,
  modelContext: ModelContext) -> Bool
{
  let dateKey = DateUtils.dateKey(for: date)
  
  // ✅ Use uniqueness manager
  if let existing = try? CloudKitUniquenessManager.shared.ensureUniqueCompletion(
    userId: userId,
    habitId: habitId,
    dateKey: dateKey,
    in: modelContext
  ) {
    // Update existing record
    existing.isCompleted = isCompleted
    existing.progress = progress
    try? modelContext.save()
    return true
  }
  
  // Create new record
  let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
  let record = CompletionRecord(
    userId: userId,
    habitId: habitId,
    date: date,
    dateKey: dateKey,
    isCompleted: isCompleted,
    progress: progress
  )
  record.userIdHabitIdDateKey = uniqueKey
  modelContext.insert(record)
  try? modelContext.save()
  return true
}
```

#### ✅ **How to prevent duplicates during sync**

**Add Post-Sync Deduplication:**

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`

Add after CloudKit sync completes:

```swift
// After ModelContainer initialization, add periodic deduplication
Task {
  // Run deduplication check periodically (e.g., after sync)
  try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds after launch
  
  await MainActor.run {
    do {
      try CloudKitUniquenessManager.shared.deduplicateAll(in: modelContext)
    } catch {
      logger.error("❌ Deduplication failed: \(error)")
    }
  }
}
```

**Or add to sync completion handler:**

```swift
// In CloudKit sync completion
NotificationCenter.default.addObserver(
  forName: .NSPersistentStoreRemoteChange,
  object: nil,
  queue: .main
) { _ in
  // CloudKit sync completed, run deduplication
  Task {
    try? CloudKitUniquenessManager.shared.deduplicateAll(in: modelContext)
  }
}
```

---

## Part 4: Migration Strategy

### Question 4: Migration Strategy

#### ✅ **Does this require a new schema version (V2)?**

**YES** - Removing `@Attribute(.unique)` is a schema change:

1. **Create HabittoSchemaV2:**
   ```swift
   enum HabittoSchemaV2: VersionedSchema {
     static var versionIdentifier: Schema.Version {
       Schema.Version(2, 0, 0)
     }
     
     static var models: [any PersistentModel.Type] {
       [
         HabitData.self,  // Now without .unique
         CompletionRecord.self,  // Now without .unique
         DailyAward.self,  // Now without .unique
         // ... other models
       ]
     }
   }
   ```

2. **Add to Migration Plan:**
   ```swift
   // In HabittoMigrationPlan.swift
   static var schemas: [any VersionedSchema.Type] {
     [
       HabittoSchemaV1.self,
       HabittoSchemaV2.self  // Add V2
     ]
   }
   
   static var stages: [MigrationStage] {
     [
       .lightweight(fromVersion: HabittoSchemaV1.self, toVersion: HabittoSchemaV2.self)
     ]
   }
   ```

#### ✅ **Will existing users' data break?**

**NO** - Lightweight migration handles this:
- Removing `.unique` is a lightweight change
- No data transformation needed
- Existing data remains intact
- Migration is automatic

#### ✅ **How do I migrate safely?**

**Migration Steps:**

1. **Keep V1 models with `.unique`** (for backward compatibility)
2. **Create V2 models without `.unique`**
3. **Use lightweight migration** (automatic)
4. **Add deduplication** after migration
5. **Test thoroughly** before release

**Migration Code:**

```swift
// In HabittoSchemaV2.swift
// Models are the same, just without @Attribute(.unique)
// SwiftData handles the migration automatically

// After migration, run deduplication
Task {
  try? CloudKitUniquenessManager.shared.deduplicateAll(in: modelContext)
}
```

#### ✅ **Code example for this migration**

**Complete Migration Example:**

**File:** `Core/Data/SwiftData/Migrations/HabittoSchemaV2.swift`

```swift
import Foundation
import SwiftData

/// Schema Version 2 - Removed unique constraints for CloudKit compatibility
///
/// **Changes from V1:**
/// - Removed @Attribute(.unique) from HabitData.id
/// - Removed @Attribute(.unique) from CompletionRecord.userIdHabitIdDateKey
/// - Removed @Attribute(.unique) from DailyAward.id and userIdDateKey
///
/// **Migration Strategy:**
/// - Lightweight migration (automatic)
/// - No data loss
/// - Uniqueness enforced in application logic
enum HabittoSchemaV2: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(2, 0, 0)
  }
  
  static var models: [any PersistentModel.Type] {
    [
      // Same models as V1, but without .unique attributes
      HabitDataV2.self,  // New model without .unique
      CompletionRecordV2.self,  // New model without .unique
      DailyAwardV2.self,  // New model without .unique
      // ... other models unchanged
    ]
  }
}
```

**OR** - Simpler approach: Keep same models, just remove `.unique` in V2:

```swift
// Actually, you can keep the same model classes
// Just remove @Attribute(.unique) from the properties
// SwiftData will handle the migration automatically
```

---

## Part 5: Alternative Solutions

### Question 5: Alternative Solution

#### ✅ **Option 1: Keep Unique Constraints + Add Deduplication (RECOMMENDED)**

**Best Approach:**
- ✅ Keep `@Attribute(.unique)` for local enforcement
- ✅ Add application-level deduplication
- ✅ Add post-sync cleanup
- ✅ Minimal code changes

**Why This Works:**
- SwiftData enforces locally (prevents most duplicates)
- Application logic handles edge cases
- Post-sync cleanup catches any that slip through
- Best of both worlds

#### ✅ **Option 2: Use Deterministic IDs**

**For CompletionRecord and DailyAward:**

```swift
// Instead of UUID, use deterministic ID based on content
let completionId = "\(userId)#\(habitId)#\(dateKey)"  // Deterministic
let awardId = "\(userId)#\(dateKey)"  // Deterministic

// This ensures same content = same ID
// Reduces conflict risk
```

**Pros:**
- Reduces duplicate risk
- Same data = same ID
- Easier conflict resolution

**Cons:**
- Less flexible
- Requires careful design

#### ✅ **Option 3: Add Deduplication Logic in Sync Process**

**In CloudKit sync handler:**

```swift
// After CloudKit sync completes
func handleCloudKitSyncComplete() {
  Task {
    // Run deduplication immediately after sync
    try? CloudKitUniquenessManager.shared.deduplicateAll(in: modelContext)
  }
}
```

#### ✅ **Option 4: Use CloudKit Record Zones Differently**

**Not applicable** - SwiftData manages zones automatically. You can't control this with SwiftData's built-in CloudKit integration.

---

## Part 6: Recommended Approach

### ✅ **My Recommendation: Hybrid Approach**

**Keep unique constraints + Add safeguards:**

1. **Keep `@Attribute(.unique)`** - Local enforcement works
2. **Add uniqueness checks** - Before insert, check for existing
3. **Add deduplication** - Post-sync cleanup
4. **Monitor for duplicates** - Log and alert if found

**Implementation:**

```swift
// 1. Keep unique constraints (local enforcement)
@Attribute(.unique) var id: UUID

// 2. Add uniqueness check before insert
if let existing = try CloudKitUniquenessManager.shared.ensureUniqueHabit(
  id: newId,
  in: context
) {
  return existing  // Use existing
}

// 3. Add post-sync deduplication
// Run after CloudKit sync completes
try CloudKitUniquenessManager.shared.deduplicateAll(in: context)
```

**Why This Works:**
- ✅ Local enforcement prevents most duplicates
- ✅ Application logic handles edge cases
- ✅ Post-sync cleanup catches any that slip through
- ✅ Minimal risk, maximum protection

---

## Part 7: Testing Plan

### Safe Testing Procedure

#### Phase 1: Development Testing

1. **Enable CloudKit in development**
2. **Test on 2 devices** (iPhone + iPad)
3. **Test scenarios:**
   - Normal sync (create on A, check B)
   - Simultaneous creation
   - Offline conflicts
   - Network delays

#### Phase 2: Monitor for Duplicates

1. **Check CloudKit Dashboard** for duplicate records
2. **Check local database** for duplicates
3. **Monitor logs** for deduplication activity
4. **Verify data integrity** after sync

#### Phase 3: Production Testing

1. **Beta test** with TestFlight
2. **Monitor** for duplicate reports
3. **Verify** deduplication works
4. **Release** gradually

---

## Summary

### ✅ **Risk Assessment: MEDIUM (Manageable)**

- CloudKit doesn't enforce unique constraints
- SwiftData enforces locally (works)
- Duplicates possible but unlikely
- Your existing code helps

### ✅ **Recommended Solution: Hybrid Approach**

1. **Keep `@Attribute(.unique)`** - Local enforcement
2. **Add uniqueness checks** - Before insert
3. **Add deduplication** - Post-sync cleanup
4. **Monitor** - Log and alert

### ✅ **Implementation Steps**

1. Create `CloudKitUniquenessManager`
2. Add uniqueness checks before insert
3. Add post-sync deduplication
4. Test thoroughly
5. Enable CloudKit

### ✅ **You Can Safely Enable CloudKit**

With proper safeguards, CloudKit sync is safe. The risk is manageable with the hybrid approach.

---

**Next Steps:**
1. Review this guide
2. Implement `CloudKitUniquenessManager`
3. Test in development
4. Enable CloudKit with confidence

