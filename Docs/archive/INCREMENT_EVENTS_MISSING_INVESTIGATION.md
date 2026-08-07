# Investigation: Why INCREMENT Events Are Missing

## Executive Summary

**Root Cause: SYNC OPERATIONS BYPASS EVENT CREATION**

The `mergeCompletionFromFirestore()` method in `SyncEngine` sets `CompletionRecord.progress` directly **without creating ProgressEvents**. This means any progress synced from Firestore (or from other devices) will have no corresponding events.

Additionally, there may be historical data created before event sourcing was implemented.

---

## 1. When Were These Completions Made?

### Investigation Method

To determine when the problem completions were made, we need to check the `createdAt` and `updatedAt` timestamps on the CompletionRecords:

- `habitId: F93EED74-D0BC-4051-BA09-4DCB7A3EAFD2`, `dateKey: 2026-01-21` (progress: 2)
- `habitId: B8377064-8F0B-4C48-A0EB-A30D639818F1`, `dateKey: 2026-01-21` (progress: 5)

**Action Required:** Query these CompletionRecords and check their timestamps.

**Code to add for investigation:**
```swift
// In DailyAwardService.reconcileCompletionRecords() or similar
let problemHabits = [
    UUID(uuidString: "F93EED74-D0BC-4051-BA09-4DCB7A3EAFD2")!,
    UUID(uuidString: "B8377064-8F0B-4C48-A0EB-A30D639818F1")!
]

for habitId in problemHabits {
    let predicate = #Predicate<CompletionRecord> { record in
        record.habitId == habitId && record.dateKey == "2026-01-21"
    }
    let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
    if let record = try? modelContext.fetch(descriptor).first {
        print("📅 COMPLETION_TIMESTAMP: habitId=\(habitId.uuidString.prefix(8))...")
        print("   createdAt: \(record.createdAt)")
        print("   updatedAt: \(record.updatedAt ?? record.createdAt)")
        print("   progress: \(record.progress)")
    }
}
```

---

## 2. History of ProgressEvent Creation

### When Was Event Creation Added?

**Evidence from code:**

1. **Current Implementation** (`Core/Data/Repository/HabitStore.swift:501-535`):
   - ✅ Event creation is now **always enabled** (no feature flag)
   - Comment: "✅ PRIORITY 1: Always create ProgressEvent (event sourcing is now default)"
   - Event creation happens **before** updating completionHistory

2. **Historical Implementation** (`Docs/Implementation/EVENT_SOURCING_IMPLEMENTATION_PLAN.md:242-266`):
   - Shows a **feature flag** `NewArchitectureFlags.shared.useEventSourcing`
   - Event creation was **conditional** based on this flag
   - If flag was false, events were **not created**

3. **Migration Code** (`Core/Data/Migration/MigrateCompletionsToEvents.swift`):
   - Migration exists to backfill events from CompletionRecords
   - Creates `.bulkAdjust` events for historical data
   - Suggests there was a period where events were not created

### Conclusion

**There WAS a period where progress could be set without creating events:**
- Initially, event creation was behind a feature flag
- If the flag was disabled, `setProgress()` would update progress without creating events
- The migration `MigrateCompletionsToEvents` was created to backfill this historical data

**However**, the current code **always creates events** (no feature flag check).

---

## 3. Code Path for Progress > 1

### UI Interaction → Code Path

**Location:** `Core/UI/Items/ScheduledHabitItem.swift`

#### Path 1: Swipe Right (Increment)
```swift
// Line 585-633
private func handleRightSwipe() {
    let newProgress = currentProgress + 1  // Increment by 1
    onProgressChange?(habit, selectedDate, newProgress)
    // → Calls HabitStore.setProgress()
}
```

#### Path 2: Circle Button (Toggle Complete)
```swift
// Line 477-531
private func completeHabit() {
    if currentProgress < goalAmount {
        newProgress = goalAmount  // Jump to goal
    } else {
        newProgress = 0  // Reset to 0
    }
    onProgressChange?(habit, selectedDate, newProgress)
    // → Calls HabitStore.setProgress()
}
```

### Event Creation Logic

**Location:** `Core/Data/Repository/HabitStore.swift:510-519`

```swift
let eventType = eventTypeForProgressChange(
    oldProgress: oldProgress,
    newProgress: progress,
    goalAmount: goalAmount
)

let progressDelta = progress - oldProgress

if progressDelta != 0 {
    let event = try await ProgressEventService.shared.createEvent(
        habitId: habit.id,
        date: date,
        dateKey: dateKey,
        eventType: eventType,
        progressDelta: progressDelta,
        userId: userId
    )
}
```

### Event Type Determination

**Location:** `Core/Services/ProgressEventService.swift:268-297`

```swift
func eventTypeForProgressChange(
    oldProgress: Int,
    newProgress: Int,
    goalAmount: Int
) -> ProgressEventType {
    let delta = newProgress - oldProgress
    
    let wasCompleted = oldProgress >= goalAmount
    let isCompleted = newProgress >= goalAmount
    
    if !wasCompleted && isCompleted {
        return .toggleComplete  // Crossing threshold: incomplete → complete
    } else if wasCompleted && !isCompleted {
        return .toggleComplete  // Crossing threshold: complete → incomplete
    } else if delta > 0 {
        return .increment  // Increment within same completion state
    } else {
        return .decrement  // Decrement within same completion state
    }
}
```

### Example: Progress 0 → 1 → 2 → 3 (goal: 3)

1. **0 → 1**: `delta=1`, `wasCompleted=false`, `isCompleted=false` → **INCREMENT** ✅
2. **1 → 2**: `delta=1`, `wasCompleted=false`, `isCompleted=false` → **INCREMENT** ✅
3. **2 → 3**: `delta=1`, `wasCompleted=false`, `isCompleted=true` → **TOGGLE_COMPLETE** ✅

**Conclusion:** The code path for incrementing progress **should create INCREMENT events** for each step.

---

## 4. Test Current Behavior

### Diagnostic Logging Added

**Location:** `Core/Data/Repository/HabitStore.swift:508-519`

Added temporary diagnostic logging:
```swift
print("🔬 SET_PROGRESS_DEBUG: habitId=\(habit.id.uuidString.prefix(8))..., newProgress=\(progress), oldProgress=\(oldProgress)")
print("🔬 SET_PROGRESS_DEBUG: Will create event with type=\(eventType.rawValue), delta=\(progressDelta)")
```

### Test Procedure

1. Create a NEW habit with goal "3 times per day"
2. Tap to increment progress from 0 → 1
3. Tap again to increment from 1 → 2
4. Tap again to increment from 2 → 3 (complete)

**Expected Output:**
```
🔬 SET_PROGRESS_DEBUG: habitId=..., newProgress=1, oldProgress=0
🔬 SET_PROGRESS_DEBUG: Will create event with type=INCREMENT, delta=1
✅ setProgress: Created ProgressEvent successfully
   → Event Type: INCREMENT
   → Progress Delta: 1

🔬 SET_PROGRESS_DEBUG: habitId=..., newProgress=2, oldProgress=1
🔬 SET_PROGRESS_DEBUG: Will create event with type=INCREMENT, delta=1
✅ setProgress: Created ProgressEvent successfully
   → Event Type: INCREMENT
   → Progress Delta: 1

🔬 SET_PROGRESS_DEBUG: habitId=..., newProgress=3, oldProgress=2
🔬 SET_PROGRESS_DEBUG: Will create event with type=TOGGLE_COMPLETE, delta=1
✅ setProgress: Created ProgressEvent successfully
   → Event Type: TOGGLE_COMPLETE
   → Progress Delta: 1
```

**If events are created correctly:** Current code is working, issue is historical data.

**If events are NOT created:** There's a bug in current code.

---

## 5. Alternative Code Paths That Bypass Event Creation

### ⚠️ CRITICAL FINDING: Sync Operations Bypass Event Creation

**Location:** `Core/Data/Sync/SyncEngine.swift:1550-1645`

```swift
private func mergeCompletionFromFirestore(data: [String: Any], userId: String) async throws {
    // ...
    let remoteProgress = data["progress"] as? Int ?? 0
    
    // Merge into SwiftData on MainActor
    try await MainActor.run {
        // ...
        if let existingRecord = existingRecords.first {
            // Remote is newer, update local
            existingRecord.progress = remoteProgress  // ⚠️ DIRECT ASSIGNMENT - NO EVENT CREATED
            existingRecord.updatedAt = Date()
            try modelContext.save()
        } else {
            // Create new completion record
            let newRecord = CompletionRecord(
                userId: userId,
                habitId: habitId,
                date: date,
                dateKey: dateKey,
                isCompleted: remoteIsCompleted,
                progress: remoteProgress  // ⚠️ DIRECT ASSIGNMENT - NO EVENT CREATED
            )
            modelContext.insert(newRecord)
            try modelContext.save()
        }
    }
}
```

**This is a MAJOR issue:**
- When syncing from Firestore, `CompletionRecord.progress` is set directly
- **No ProgressEvent is created**
- This means synced progress has no event history
- If progress was synced from another device, there will be no events locally

### Other Code Paths Checked

1. ✅ **HabitStore.setProgress()** - Creates events correctly
2. ❌ **SyncEngine.mergeCompletionFromFirestore()** - **BYPASSES event creation**
3. ✅ **Migration code** - Creates `.bulkAdjust` events (correct)
4. ✅ **Direct assignments** - None found (grep search confirmed)

---

## 6. Deliverables

### 1. Timeline

**When were problem completions made vs when was event creation added?**

**To determine:**
- Check `CompletionRecord.createdAt` for problem habits
- Compare with git history of when event creation was added
- Check if migration `MigrateCompletionsToEvents` has run

**Hypothesis:**
- Completions were made **before** event creation was always enabled
- OR completions were synced from Firestore (bypassing event creation)

### 2. Current Behavior Verification

**Does incrementing progress TODAY create events correctly?**

**Test:** Use diagnostic logging added to `HabitStore.setProgress()`

**Expected:** Events should be created for each increment

**If events ARE created:** Issue is historical data only
**If events are NOT created:** There's a current bug

### 3. Code Path Audit

**Are there any code paths that bypass event creation?**

**Found:**
- ❌ **SyncEngine.mergeCompletionFromFirestore()** - Sets progress directly without creating events

**This explains why:**
- Progress synced from Firestore has no events
- Multi-device sync creates CompletionRecords without events
- Historical sync data lacks event history

### 4. Conclusion

**Is this purely historical, or is there an ongoing bug?**

**Answer: BOTH**

1. **Historical Issue:**
   - Completions created before event sourcing was always enabled
   - Migration may not have covered all cases

2. **Ongoing Bug:**
   - **Sync operations bypass event creation** (`mergeCompletionFromFirestore`)
   - Any progress synced from Firestore will have no events
   - This is a **critical bug** that needs fixing

---

## 7. Recommended Fixes

### Fix 1: Create Events During Sync (CRITICAL)

**Location:** `Core/Data/Sync/SyncEngine.swift:1550-1645`

**Current Code:**
```swift
existingRecord.progress = remoteProgress  // ❌ No event created
```

**Fixed Code:**
```swift
// Calculate delta
let oldProgress = existingRecord.progress
let progressDelta = remoteProgress - oldProgress

if progressDelta != 0 {
    // Create ProgressEvent for synced progress
    let goalAmount = // ... get from HabitData
    let eventType = eventTypeForProgressChange(
        oldProgress: oldProgress,
        newProgress: remoteProgress,
        goalAmount: goalAmount
    )
    
    do {
        let event = try await ProgressEventService.shared.createEvent(
            habitId: habitId,
            date: date,
            dateKey: dateKey,
            eventType: eventType,
            progressDelta: progressDelta,
            userId: userId
        )
        logger.info("✅ Sync: Created ProgressEvent for synced progress")
    } catch {
        logger.error("❌ Sync: Failed to create ProgressEvent: \(error)")
        // Continue with progress update even if event creation fails
    }
}

existingRecord.progress = remoteProgress
```

### Fix 2: Backfill Historical Data

**Option A: Run Migration Again**
- Check if `MigrateCompletionsToEvents` can be re-run
- Ensure it covers all CompletionRecords with progress > 0

**Option B: Create Backfill Service**
- Query all CompletionRecords with progress > 0
- Check if events exist for each
- Create missing events (`.bulkAdjust` type)

### Fix 3: Add Validation

**Add check in reconciliation:**
- If `CompletionRecord.progress > 0` but no events exist
- Log warning and optionally create backfill event

---

## 8. Summary

### Root Causes Identified

1. **Historical Data:** Completions created before event sourcing was always enabled
2. **Sync Bug:** `mergeCompletionFromFirestore()` bypasses event creation
3. **Migration Gap:** Migration may not have covered all cases

### Action Items

1. ✅ **Add diagnostic logging** - DONE
2. ⏳ **Test current behavior** - Run test with new habit
3. ⏳ **Check CompletionRecord timestamps** - Determine when problem data was created
4. ⏳ **Fix sync bug** - Make `mergeCompletionFromFirestore()` create events
5. ⏳ **Backfill historical data** - Create events for existing CompletionRecords

### Next Steps

1. Run the diagnostic test (create new habit, increment progress)
2. Check logs to see if events are created correctly
3. If events ARE created: Focus on backfill + sync fix
4. If events are NOT created: Investigate why `setProgress()` isn't creating events
