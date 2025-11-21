# CloudKit Uniqueness Manager - Integration Code

## Overview

This document provides exact code changes to integrate `CloudKitUniquenessManager` into your existing codebase. Each change includes file path, line numbers, before/after code, and explanations.

---

## Integration 1: Habit Creation

### Location 1: SwiftDataStorage.saveHabits() - New Habit Creation

**File:** `Core/Data/SwiftData/SwiftDataStorage.swift`  
**Line:** ~154 (in `saveHabits` method, when creating new habit)

**Before:**
```swift
} else {
  // Create new habit with user ID
  let habitData = await HabitData(
    id: habit.id,
    userId: getCurrentUserId() ?? "", // Use current user ID or empty string for guest
    name: habit.name,
    habitDescription: habit.description,
    icon: habit.icon,
    color: habit.color.color,
    habitType: habit.habitType,
    schedule: habit.schedule,
    goal: habit.goal,
    reminder: habit.reminder,
    startDate: habit.startDate,
    endDate: habit.endDate,
    baseline: habit.baseline,
    target: habit.target,
    goalHistory: habit.goalHistory)
```

**After:**
```swift
} else {
  // ✅ CLOUDKIT: Check for duplicate habit before creating
  do {
    if let existingHabit = try await MainActor.run {
      try CloudKitUniquenessManager.shared.ensureUniqueHabit(
        id: habit.id,
        in: container.modelContext
      )
    } {
      logger.info("ℹ️ Habit with id \(habit.id.uuidString) already exists, updating existing instead of creating duplicate")
      // Update existing habit instead of creating duplicate
      await existingHabit.updateFromHabit(habit)
      return // Exit early, habit already exists
    }
  } catch {
    logger.warning("⚠️ Failed to check for duplicate habit: \(error.localizedDescription)")
    // Continue with creation if check fails (better to create than skip)
  }
  
  // Create new habit with user ID
  let habitData = await HabitData(
    id: habit.id,
    userId: getCurrentUserId() ?? "", // Use current user ID or empty string for guest
    name: habit.name,
    habitDescription: habit.description,
    icon: habit.icon,
    color: habit.color.color,
    habitType: habit.habitType,
    schedule: habit.schedule,
    goal: habit.goal,
    reminder: habit.reminder,
    startDate: habit.startDate,
    endDate: habit.endDate,
    baseline: habit.baseline,
    target: habit.target,
    goalHistory: habit.goalHistory)
```

**What this does:**
- Checks if a habit with the same ID already exists before creating
- If duplicate found, updates existing instead of creating new
- Prevents duplicate habits during CloudKit sync

---

### Location 2: SwiftDataStorage.saveHabit() - New Habit Creation

**File:** `Core/Data/SwiftData/SwiftDataStorage.swift`  
**Line:** ~551 (in `saveHabit` method, when creating new habit)

**Before:**
```swift
} else {
  // Create new habit
  let habitData = await HabitData(
    id: habit.id,
    userId: getCurrentUserId() ?? "", // Use current user ID or empty string for guest
    name: habit.name,
    habitDescription: habit.description,
    icon: habit.icon,
    color: habit.color.color,
    habitType: habit.habitType,
    schedule: habit.schedule,
    goal: habit.goal,
    reminder: habit.reminder,
    startDate: habit.startDate,
    endDate: habit.endDate,
    baseline: habit.baseline,
    target: habit.target,
    goalHistory: habit.goalHistory)
```

**After:**
```swift
} else {
  // ✅ CLOUDKIT: Check for duplicate habit before creating
  do {
    if let existingHabit = try await MainActor.run {
      try CloudKitUniquenessManager.shared.ensureUniqueHabit(
        id: habit.id,
        in: container.modelContext
      )
    } {
      logger.info("ℹ️ Habit with id \(habit.id.uuidString) already exists, updating existing instead of creating duplicate")
      // Update existing habit instead of creating duplicate
      await existingHabit.updateFromHabit(habit)
      try container.modelContext.save()
      return // Exit early, habit already exists
    }
  } catch {
    logger.warning("⚠️ Failed to check for duplicate habit: \(error.localizedDescription)")
    // Continue with creation if check fails (better to create than skip)
  }
  
  // Create new habit
  let habitData = await HabitData(
    id: habit.id,
    userId: getCurrentUserId() ?? "", // Use current user ID or empty string for guest
    name: habit.name,
    habitDescription: habit.description,
    icon: habit.icon,
    color: habit.color.color,
    habitType: habit.habitType,
    schedule: habit.schedule,
    goal: habit.goal,
    reminder: habit.reminder,
    startDate: habit.startDate,
    endDate: habit.endDate,
    baseline: habit.baseline,
    target: habit.target,
    goalHistory: habit.goalHistory)
```

**What this does:**
- Same as Location 1, but for single habit save
- Prevents duplicates when saving individual habits

---

## Integration 2: Completion Record Creation

### Location 1: createCompletionRecordIfNeeded() - Update Existing Method

**File:** `Core/Data/SwiftData/HabitDataModel.swift`  
**Line:** ~536 (in `createCompletionRecordIfNeeded` static method)

**Before:**
```swift
static func createCompletionRecordIfNeeded(
  userId: String,
  habitId: UUID,
  date: Date,
  isCompleted: Bool,
  progress: Int = 0,  // ✅ NEW: Accept progress parameter
  modelContext: ModelContext) -> Bool
{
  let dateKey = DateUtils.dateKey(for: date)
  let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"

  do {
    // Check if record already exists
    let predicate = #Predicate<CompletionRecord> { record in
      record.userIdHabitIdDateKey == uniqueKey
    }
    let request = FetchDescriptor<CompletionRecord>(predicate: predicate)
    let existingRecords = try modelContext.fetch(request)

    if existingRecords.isEmpty {
      // Create new record
      let record = CompletionRecord(
        userId: userId,
        habitId: habitId,
        date: date,
        dateKey: dateKey,
        isCompleted: isCompleted,
        progress: progress)  // ✅ NEW: Store progress
      modelContext.insert(record)
      try modelContext.save()
      return true
    } else {
      // Update existing record
      if let existingRecord = existingRecords.first {
        existingRecord.isCompleted = isCompleted
        existingRecord.progress = progress  // ✅ NEW: Update progress
        try modelContext.save()
        return true
      }
    }
  } catch {
    print("❌ CompletionRecord creation failed: \(error)")
    // ✅ FALLBACK: If database is corrupted, return false but don't crash
    return false
  }

  return false
}
```

**After:**
```swift
static func createCompletionRecordIfNeeded(
  userId: String,
  habitId: UUID,
  date: Date,
  isCompleted: Bool,
  progress: Int = 0,  // ✅ NEW: Accept progress parameter
  modelContext: ModelContext) -> Bool
{
  let dateKey = DateUtils.dateKey(for: date)
  
  // ✅ CLOUDKIT: Use uniqueness manager to check for duplicates
  do {
    if let existingRecord = try CloudKitUniquenessManager.shared.ensureUniqueCompletion(
      userId: userId,
      habitId: habitId,
      dateKey: dateKey,
      in: modelContext
    ) {
      // Update existing record instead of creating duplicate
      existingRecord.isCompleted = isCompleted
      existingRecord.progress = progress
      try modelContext.save()
      return true
    }
    
    // No duplicate found, create new record
    let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
    let record = CompletionRecord(
      userId: userId,
      habitId: habitId,
      date: date,
      dateKey: dateKey,
      isCompleted: isCompleted,
      progress: progress)
    record.userIdHabitIdDateKey = uniqueKey
    modelContext.insert(record)
    try modelContext.save()
    return true
  } catch {
    print("❌ CompletionRecord creation failed: \(error)")
    // ✅ FALLBACK: If database is corrupted, return false but don't crash
    return false
  }
}
```

**What this does:**
- Uses `CloudKitUniquenessManager` instead of manual predicate check
- More consistent with other uniqueness checks
- Better logging and error handling

---

### Location 2: SwiftDataStorage.saveHabits() - Completion Record Creation

**File:** `Core/Data/SwiftData/SwiftDataStorage.swift`  
**Line:** ~184 (when creating CompletionRecords from habit.completionHistory)

**Before:**
```swift
for (dateString, progress) in habit.completionHistory {
  if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
    let dateKey = Habit.dateKey(for: date)
    let recordedStatus = habit.completionStatus[dateKey]
    let goalInt = Int(habit.goal) ?? 1
    let isCompleted = recordedStatus ?? (progress >= goalInt)
    
    let completionRecord = CompletionRecord(
      userId: await getCurrentUserId() ?? "",
      habitId: habitData.id,
      date: date,
      dateKey: dateKey,
      isCompleted: isCompleted,
      progress: progress)  // Store actual progress too
    
    habitData.completionHistory.append(completionRecord)
    
    logger.info("  📝 Created CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
  }
}
```

**After:**
```swift
for (dateString, progress) in habit.completionHistory {
  if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
    let dateKey = Habit.dateKey(for: date)
    let recordedStatus = habit.completionStatus[dateKey]
    let goalInt = Int(habit.goal) ?? 1
    let isCompleted = recordedStatus ?? (progress >= goalInt)
    
    // ✅ CLOUDKIT: Check for duplicate before creating
    let userId = await getCurrentUserId() ?? ""
    do {
      if let existingRecord = try await MainActor.run {
        try CloudKitUniquenessManager.shared.ensureUniqueCompletion(
          userId: userId,
          habitId: habitData.id,
          dateKey: dateKey,
          in: container.modelContext
        )
      } {
        // Update existing record instead of creating duplicate
        existingRecord.isCompleted = isCompleted
        existingRecord.progress = progress
        if !habitData.completionHistory.contains(where: { $0.id == existingRecord.id }) {
          habitData.completionHistory.append(existingRecord)
        }
        logger.info("  📝 Updated existing CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
        continue
      }
    } catch {
      logger.warning("⚠️ Failed to check for duplicate completion: \(error.localizedDescription)")
      // Continue with creation if check fails
    }
    
    // No duplicate found, create new record
    let completionRecord = CompletionRecord(
      userId: userId,
      habitId: habitData.id,
      date: date,
      dateKey: dateKey,
      isCompleted: isCompleted,
      progress: progress)  // Store actual progress too
    
    habitData.completionHistory.append(completionRecord)
    
    logger.info("  📝 Created CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
  }
}
```

**What this does:**
- Checks for duplicate completion records before creating
- Updates existing if found, creates new if not
- Prevents duplicates during habit save/migration

---

## Integration 3: Daily Award Creation

### Location: SyncEngine.importDailyAwards() - Award Creation

**File:** `Core/Data/Sync/SyncEngine.swift`  
**Line:** ~1282 (in `importDailyAwards` method)

**Before:**
```swift
let modelContext = SwiftDataContainer.shared.modelContext

let award = DailyAward(
    userId: userId,
    dateKey: dateKey,
    xpGranted: xpGranted,
    allHabitsCompleted: data["allHabitsCompleted"] as? Bool ?? true
)

if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
    award.createdAt = createdAt
}

modelContext.insert(award)
try? modelContext.save()
logger.info("✅ Imported DailyAward for \(dateKey) (\(xpGranted) XP)")
```

**After:**
```swift
let modelContext = SwiftDataContainer.shared.modelContext

// ✅ CLOUDKIT: Check for duplicate before creating
do {
  if let existingAward = try await MainActor.run {
    try CloudKitUniquenessManager.shared.ensureUniqueDailyAward(
      userId: userId,
      dateKey: dateKey,
      in: modelContext
    )
  } {
    // Update existing award if new one has more XP (or keep existing if same/less)
    if xpGranted > existingAward.xpGranted {
      existingAward.xpGranted = xpGranted
      existingAward.allHabitsCompleted = data["allHabitsCompleted"] as? Bool ?? true
      if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
        existingAward.createdAt = createdAt
      }
      try modelContext.save()
      logger.info("✅ Updated existing DailyAward for \(dateKey) (new XP: \(xpGranted))")
    } else {
      logger.info("ℹ️ DailyAward for \(dateKey) already exists with equal or higher XP (\(existingAward.xpGranted)), keeping existing")
    }
    return // Exit early, award already exists
  }
} catch {
  logger.warning("⚠️ Failed to check for duplicate DailyAward: \(error.localizedDescription)")
  // Continue with creation if check fails
}

// No duplicate found, create new award
let award = DailyAward(
    userId: userId,
    dateKey: dateKey,
    xpGranted: xpGranted,
    allHabitsCompleted: data["allHabitsCompleted"] as? Bool ?? true
)

if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
    award.createdAt = createdAt
}

modelContext.insert(award)
try? modelContext.save()
logger.info("✅ Imported DailyAward for \(dateKey) (\(xpGranted) XP)")
```

**What this does:**
- Checks for duplicate daily awards before creating
- Updates if new award has more XP, keeps existing if same/less
- Prevents duplicate awards during sync

---

## Integration 4: Post-Sync Deduplication

### Location 1: SwiftDataContainer Initialization - Add Sync Observer

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`  
**Line:** ~290 (after container initialization, before the end of `init()`)

**Before:**
```swift
// Test if we can access the CompletionRecord table
let testRequest = FetchDescriptor<CompletionRecord>()
let testCount = (try? modelContext.fetchCount(testRequest)) ?? -1
logger.info("🔧 SwiftData: CompletionRecord table test - count: \(testCount)")

// ✅ CRITICAL FIX: DO NOT perform health check on startup
```

**After:**
```swift
// Test if we can access the CompletionRecord table
let testRequest = FetchDescriptor<CompletionRecord>()
let testCount = (try? modelContext.fetchCount(testRequest)) ?? -1
logger.info("🔧 SwiftData: CompletionRecord table test - count: \(testCount)")

// ✅ CLOUDKIT: Set up post-sync deduplication observer
// This runs deduplication after CloudKit sync completes
setupCloudKitDeduplicationObserver()

// ✅ CRITICAL FIX: DO NOT perform health check on startup
```

**Then add this new method to SwiftDataContainer class:**

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`  
**Location:** Add after the `init()` method, around line ~300

**Add this method:**
```swift
// MARK: - CloudKit Deduplication

/// Sets up observer for CloudKit sync completion to run deduplication
private func setupCloudKitDeduplicationObserver() {
  // Observe CloudKit remote changes (sync completion)
  NotificationCenter.default.addObserver(
    forName: .NSPersistentStoreRemoteChange,
    object: modelContainer,
    queue: .main
  ) { [weak self] _ in
    guard let self = self else { return }
    
    Task { @MainActor in
      // Run deduplication after CloudKit sync
      do {
        logger.info("🔄 CloudKit sync detected, running deduplication check...")
        try CloudKitUniquenessManager.shared.deduplicateAll(in: self.modelContext)
        logger.info("✅ Deduplication check completed")
      } catch {
        logger.error("❌ Deduplication failed: \(error.localizedDescription)")
      }
    }
  }
  
  logger.info("✅ CloudKit deduplication observer set up")
}
```

**What this does:**
- Observes CloudKit sync completion events
- Automatically runs deduplication after sync
- Catches any duplicates that slip through

---

### Location 2: Periodic Deduplication (Optional but Recommended)

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`  
**Location:** Add after `setupCloudKitDeduplicationObserver()` method

**Add this method:**
```swift
/// Runs periodic deduplication check (daily)
/// This is a safety net in case sync observer misses any duplicates
private func schedulePeriodicDeduplication() {
  // Run deduplication check once per day
  let lastCheckKey = "CloudKitDeduplicationLastCheck"
  let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? Date.distantPast
  let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
  
  // Only run if last check was more than 24 hours ago
  guard lastCheck < oneDayAgo else {
    logger.info("ℹ️ Deduplication check skipped (last check: \(lastCheck))")
    return
  }
  
  Task { @MainActor in
    do {
      logger.info("🔄 Running periodic deduplication check...")
      try CloudKitUniquenessManager.shared.deduplicateAll(in: modelContext)
      UserDefaults.standard.set(Date(), forKey: lastCheckKey)
      logger.info("✅ Periodic deduplication completed")
    } catch {
      logger.error("❌ Periodic deduplication failed: \(error.localizedDescription)")
    }
  }
}
```

**Then call it in `init()` after setupCloudKitDeduplicationObserver():**

```swift
// ✅ CLOUDKIT: Set up post-sync deduplication observer
setupCloudKitDeduplicationObserver()

// ✅ CLOUDKIT: Schedule periodic deduplication (daily safety net)
schedulePeriodicDeduplication()
```

**What this does:**
- Runs deduplication check once per day
- Safety net in case sync observer misses duplicates
- Prevents accumulation of duplicates over time

---

## Integration 5: Monitoring & Statistics

### Location: Add Monitoring Method to SwiftDataContainer

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`  
**Location:** Add after `schedulePeriodicDeduplication()` method

**Add this method:**
```swift
/// Gets duplicate statistics for monitoring
/// Call this periodically to track if duplicates are occurring
func getDuplicateStatistics() -> [String: Int] {
  do {
    return try CloudKitUniquenessManager.shared.getDuplicateStatistics(in: modelContext)
  } catch {
    logger.error("❌ Failed to get duplicate statistics: \(error.localizedDescription)")
    return [:]
  }
}

/// Logs duplicate statistics (for debugging/monitoring)
func logDuplicateStatistics() {
  let stats = getDuplicateStatistics()
  
  if stats.values.allSatisfy({ $0 == 0 }) {
    logger.info("✅ No duplicates detected - all checks passed")
  } else {
    logger.warning("⚠️ Duplicates detected:")
    if let habits = stats["duplicateHabits"], habits > 0 {
      logger.warning("   - \(habits) duplicate habit groups")
    }
    if let completions = stats["duplicateCompletions"], completions > 0 {
      logger.warning("   - \(completions) duplicate completion groups")
    }
    if let awards = stats["duplicateAwards"], awards > 0 {
      logger.warning("   - \(awards) duplicate award groups")
    }
  }
}
```

**Then add periodic logging (optional):**

**File:** `Core/Data/SwiftData/SwiftDataContainer.swift`  
**Location:** In `init()`, after `schedulePeriodicDeduplication()`

**Add:**
```swift
// ✅ CLOUDKIT: Log duplicate statistics on startup (for monitoring)
Task {
  try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds after init
  logDuplicateStatistics()
}
```

**What this does:**
- Provides statistics about potential duplicates
- Logs results for monitoring
- Helps track if duplicates are occurring

---

## Summary of Changes

### Files Modified:

1. **`Core/Data/SwiftData/SwiftDataStorage.swift`**
   - Line ~154: Add uniqueness check in `saveHabits()` (new habit)
   - Line ~184: Add uniqueness check for CompletionRecord creation
   - Line ~551: Add uniqueness check in `saveHabit()` (new habit)

2. **`Core/Data/SwiftData/HabitDataModel.swift`**
   - Line ~536: Update `createCompletionRecordIfNeeded()` to use uniqueness manager

3. **`Core/Data/Sync/SyncEngine.swift`**
   - Line ~1282: Add uniqueness check for DailyAward creation

4. **`Core/Data/SwiftData/SwiftDataContainer.swift`**
   - Line ~290: Add sync observer setup
   - Add `setupCloudKitDeduplicationObserver()` method
   - Add `schedulePeriodicDeduplication()` method
   - Add `getDuplicateStatistics()` method
   - Add `logDuplicateStatistics()` method

### Import Statement Needed:

**Add to top of files that use CloudKitUniquenessManager:**

```swift
// Already imported via SwiftData, but ensure it's accessible
// CloudKitUniquenessManager is in Core/Data/CloudKit/CloudKitUniquenessManager.swift
```

---

## Testing Checklist

After integration:

- [ ] Test habit creation (should check for duplicates)
- [ ] Test completion record creation (should check for duplicates)
- [ ] Test daily award creation (should check for duplicates)
- [ ] Test CloudKit sync (deduplication should run after sync)
- [ ] Test simultaneous creation on 2 devices
- [ ] Monitor logs for duplicate statistics
- [ ] Verify no duplicates appear in database

---

## Potential Issues & Solutions

### Issue 1: MainActor Isolation

**Problem:** `CloudKitUniquenessManager` is `@MainActor`, but some code runs on background threads.

**Solution:** Use `await MainActor.run { }` wrapper (already included in code above).

### Issue 2: Performance Impact

**Problem:** Uniqueness checks add overhead to every creation.

**Solution:** 
- Checks are fast (single predicate fetch)
- Only runs on creation (not reads)
- Acceptable trade-off for data integrity

### Issue 3: Error Handling

**Problem:** What if uniqueness check fails?

**Solution:** 
- Log warning and continue with creation
- Better to create than skip
- Deduplication will catch any duplicates later

---

## Next Steps

1. Apply all code changes above
2. Build and test
3. Test on 2 devices with CloudKit enabled
4. Monitor logs for duplicates
5. Enable CloudKit in production if tests pass

---

**All integration code is ready! Apply these changes and test thoroughly before enabling CloudKit.**

