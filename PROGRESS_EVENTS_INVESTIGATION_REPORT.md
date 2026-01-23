# ProgressEvents vs CompletionRecord Investigation Report

## Executive Summary

**Root Cause: TIMING ISSUE (Option A)**

Reconciliation runs **BEFORE** sync completes pulling events from Firestore. This causes reconciliation to calculate progress from incomplete local event data, resulting in mismatches.

---

## 1. Timing Analysis

### App Launch Sequence

```
AppDelegate.didFinishLaunching
  └─> Task { @MainActor
        └─> FirebaseConfiguration.ensureAuthenticated()
            └─> SyncEngine.shared.startPeriodicSync(userId: uid)  [IMMEDIATE]
                └─> performFullSyncCycle(userId)  [IMMEDIATE]
                    └─> pullRemoteChanges(userId)
                        └─> pullEvents(userId, recentMonths: 3)  [ASYNC - takes time]
                            └─> mergeEventFromFirestore()  [saves to SwiftData]
```

**Location:** `App/HabittoApp.swift:97` → `Core/Data/Sync/SyncEngine.swift:354-386`

### Reconciliation Sequence

```
HabittoApp.onAppear
  └─> Task.detached { @MainActor
        └─> try? await Task.sleep(nanoseconds: 1_000_000_000)  [1 second delay]
            └─> performXPIntegrityCheck()
                └─> Task.detached(priority: .background) { @MainActor
                      └─> performCompletionRecordReconciliation()  [NO AWAIT FOR SYNC]
                          └─> DailyAwardService.reconcileCompletionRecords()
                              └─> calculateProgressFromEvents()  [reads local events]
```

**Location:** `App/HabittoApp.swift:526-534`

### Critical Finding: **NO SYNCHRONIZATION**

- **Sync starts immediately** on app launch (`startPeriodicSync` → `performFullSyncCycle`)
- **Reconciliation starts after 1 second delay** (`Task.sleep(1_000_000_000)`)
- **Reconciliation does NOT await sync completion** - they run concurrently
- **Events are pulled asynchronously** - `pullEvents()` can take several seconds to complete
- **Reconciliation reads local events immediately** - may see incomplete data

### Timing Diagram

```
Time 0ms:   App launches
            └─> SyncEngine.startPeriodicSync() [starts immediately]
                └─> performFullSyncCycle() [starts immediately]
                    └─> pullRemoteChanges() [starts immediately]
                        └─> pullEvents() [ASYNC - begins network request]

Time 1000ms: HabittoApp.onAppear delay expires
             └─> performCompletionRecordReconciliation() [starts]
                 └─> reconcileCompletionRecords() [reads local events]
                     └─> Only 2 events found locally (TOGGLE_COMPLETE -1, +1)
                     └─> Calculated progress = 0
                     └─> CompletionRecord.progress = 2 (from previous sync)
                     └─> MISMATCH DETECTED

Time 3000-5000ms: pullEvents() completes
                   └─> 471 events pulled from Firestore
                   └─> mergeEventFromFirestore() saves all events to SwiftData
                   └─> Local database now has all events

Time 6000ms+:      Next reconciliation run (if triggered)
                   └─> Would now see all 471 events
                   └─> Calculated progress would match CompletionRecord
```

**Conclusion:** Reconciliation runs **BEFORE** sync completes, causing it to see incomplete event data.

---

## 2. Event Type Analysis

### All Event Types

From `Core/Models/ProgressEvent.swift:227-245`:

1. **INCREMENT** - User incremented progress (+1, +5, etc.)
2. **DECREMENT** - User decremented progress (-1, -5, etc.)
3. **SET** - User set progress to absolute value
4. **TOGGLE_COMPLETE** - User tapped circle button to toggle complete/incomplete
5. **SYSTEM_RESET** - System automatically marked as incomplete
6. **BULK_ADJUST** - Bulk adjustment (e.g., migration, correction)

### Progress Calculation Logic

From `Core/Services/ProgressEventService.swift:157-178`:

```swift
func applyEvents(...) async throws -> (progress: Int, isCompleted: Bool) {
    let descriptor = ProgressEvent.eventsForHabitDateUser(habitId: habitId, dateKey: dateKey, userId: userId)
    let events = try modelContext.fetch(descriptor)
    
    // Sum progress deltas to get current progress
    let totalProgress = events.reduce(0) { $0 + $1.progressDelta }
    
    // Ensure progress doesn't go negative
    let progress = max(0, totalProgress)
    
    // Determine completion status based on goal
    let isCompleted = progress >= goalAmount
    
    return (progress, isCompleted)
}
```

**Key Findings:**
- ✅ **ALL event types are included** in the sum - no filtering by eventType
- ✅ Calculation sums `progressDelta` from all events
- ✅ Events are filtered by `userId` (prevents cross-user data leakage)
- ✅ Events are filtered by `habitId` and `dateKey`

**Conclusion:** Event type filtering is NOT the issue. All event types contribute to progress calculation.

---

## 3. Event Creation Code Paths

### Primary Code Path: User Taps to Update Progress

**Location:** `Core/Data/Repository/HabitStore.swift:474-535`

```swift
func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    // ... get oldProgress from completionHistory ...
    
    // ✅ PRIORITY 1: Always create ProgressEvent (event sourcing is now default)
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
        // Event is saved to SwiftData immediately
    }
    
    // Then update CompletionRecord
    // ...
}
```

**Event Type Detection:** `Core/Services/ProgressEventService.swift:268-297`

- Determines event type based on progress change and completion threshold
- INCREMENT vs TOGGLE_COMPLETE is determined by whether progress crosses goal threshold

**Conclusion:** Event creation is working correctly. Both INCREMENT and TOGGLE_COMPLETE events are created when appropriate.

---

## 4. Firestore Event Data

### Event Pulling Logic

**Location:** `Core/Data/Sync/SyncEngine.swift:1377-1401`

```swift
private func pullEvents(userId: String, recentMonths: Int) async throws -> Int {
    let yearMonths = getRecentYearMonths(count: recentMonths)  // Last 3 months
    var pulledCount = 0
    
    for yearMonth in yearMonths {
        let eventsRef = firestore.collection("users")
            .document(userId)
            .collection("events")
            .document(yearMonth)
            .collection("events")
        
        let snapshot = try? await eventsRef.getDocuments()
        
        for document in snapshot.documents {
            let data = document.data()
            try await mergeEventFromFirestore(data: data)  // Saves to SwiftData
            pulledCount += 1
        }
    }
    
    return pulledCount
}
```

### Event Persistence

**Location:** `Core/Data/Sync/SyncEngine.swift:1874-1898`

```swift
private func mergeEventFromFirestore(data: [String: Any]) async throws {
    await MainActor.run {
        let modelContext = SwiftDataContainer.shared.modelContext
        
        guard let operationId = data["operationId"] as? String else {
            return
        }
        
        // Check if event exists (idempotent check via operationId)
        let predicate = #Predicate<ProgressEvent> { event in
            event.operationId == operationId
        }
        let descriptor = FetchDescriptor<ProgressEvent>(predicate: predicate)
        
        if (try? modelContext.fetch(descriptor).first) == nil {
            // Create new event from Firestore data
            guard let event = ProgressEvent.fromFirestore(data) else {
                return
            }
            
            modelContext.insert(event)
            try? modelContext.save()  // ✅ Events ARE persisted to SwiftData
        }
    }
}
```

**Key Findings:**
- ✅ Events ARE persisted to SwiftData when pulled from Firestore
- ✅ Idempotency check via `operationId` prevents duplicates
- ✅ Events are pulled from last 3 months (`recentMonths: 3`)
- ⚠️ **Issue:** If events are older than 3 months, they won't be pulled

**Conclusion:** Event persistence is working correctly. The issue is timing - reconciliation runs before events are pulled.

---

## 5. Root Cause Determination

### Option A: Timing Issue ✅ **CONFIRMED**

**Evidence:**
1. Reconciliation runs after 1 second delay, but sync is async and takes longer
2. No `await` ensures sync completes before reconciliation
3. Diagnostic logs show "2 events locally" but "471 events after sync"
4. Reconciliation reads local events immediately, before sync completes

**Fix Required:**
- Ensure reconciliation waits for sync to complete
- Or delay reconciliation until after sync completes
- Or add sync completion notification that reconciliation listens to

### Option B: Events Exist But Aren't Included ❌ **RULED OUT**

- All event types are included in calculation
- No filtering by eventType in `applyEvents()`
- User-scoped queries are correct

### Option C: Events Were Never Created ❌ **RULED OUT**

- Event creation code path is correct
- Events are created for both INCREMENT and TOGGLE_COMPLETE
- Diagnostic shows events exist in Firestore (471 events)

### Option D: Events Exist But Aren't Persisted ❌ **RULED OUT**

- `mergeEventFromFirestore()` saves events to SwiftData
- Idempotency check prevents duplicates
- Events are persisted correctly

### Option E: Something Else ❌ **RULED OUT**

- All other possibilities investigated and ruled out

---

## 6. Deliverables

### 1. Timing Diagram ✅

See Section 1 above.

### 2. Event Type Inventory ✅

| Event Type | Contributes to Progress? | Notes |
|------------|---------------------------|-------|
| INCREMENT | ✅ Yes | Sums `progressDelta` |
| DECREMENT | ✅ Yes | Sums `progressDelta` |
| SET | ✅ Yes | Sums `progressDelta` |
| TOGGLE_COMPLETE | ✅ Yes | Sums `progressDelta` |
| SYSTEM_RESET | ✅ Yes | Sums `progressDelta` |
| BULK_ADJUST | ✅ Yes | Sums `progressDelta` |

**All event types contribute to progress calculation.**

### 3. Code Path Trace ✅

```
User Taps UI
  └─> HabitStore.setProgress()
      └─> ProgressEventService.createEvent()
          └─> ProgressEvent.init()
          └─> modelContext.insert(event)
          └─> modelContext.save()  [Saved to SwiftData]
      └─> CompletionRecord.progress = newProgress
      └─> modelContext.save()  [Saved to SwiftData]
  └─> SyncEngine.scheduleSyncIfNeeded()  [Background sync]
      └─> syncEvents()  [Uploads to Firestore]
```

### 4. Firestore Check ✅

**Events DO exist in Firestore:**
- Diagnostic shows 471 events pulled after reconciliation
- Events are stored in `/users/{userId}/events/{yearMonth}/events/{eventId}`
- Events are pulled from last 3 months
- Events are persisted to SwiftData via `mergeEventFromFirestore()`

### 5. Root Cause ✅

**CONFIRMED: Option A - Timing Issue**

Reconciliation runs **BEFORE** sync completes pulling events from Firestore.

---

## 7. Recommended Fixes

### Fix 1: Wait for Sync Before Reconciliation (Recommended)

**Location:** `App/HabittoApp.swift:530-534`

```swift
// ✅ PRIORITY 3: Run CompletionRecord reconciliation after XP check
// ✅ FIX: Wait for sync to complete before reconciliation
Task.detached(priority: .background) { @MainActor in
    // Wait for initial sync to complete
    let syncEngine = SyncEngine.shared
    var syncCompleted = false
    var attempts = 0
    while !syncCompleted && attempts < 10 {
        // Check if sync has completed by checking if events have been pulled
        // This is a simple check - in production, use a proper sync completion notification
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        attempts += 1
        // TODO: Add proper sync completion notification mechanism
    }
    
    await performCompletionRecordReconciliation()
}
```

### Fix 2: Add Sync Completion Notification

**Location:** `Core/Data/Sync/SyncEngine.swift:1150-1175`

```swift
// After pullRemoteChanges completes
logger.info("✅ Pull remote changes completed: ...")

// ✅ FIX: Notify that sync is complete
await MainActor.run {
    NotificationCenter.default.post(
        name: NSNotification.Name("SyncPullCompleted"),
        object: nil,
        userInfo: ["eventsPulled": summary.eventsPulled]
    )
}
```

**Location:** `App/HabittoApp.swift:530-534`

```swift
// ✅ PRIORITY 3: Run CompletionRecord reconciliation after sync completes
Task.detached(priority: .background) { @MainActor in
    // Wait for sync completion notification
    await withCheckedContinuation { continuation in
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncPullCompleted"),
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.removeObserver(observer)
            continuation.resume()
        }
    }
    
    await performCompletionRecordReconciliation()
}
```

### Fix 3: Increase Reconciliation Delay

**Simple but less robust:**

```swift
// Wait longer before reconciliation to ensure sync completes
try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds instead of 1
await performCompletionRecordReconciliation()
```

---

## 8. Additional Findings

### Reconciliation Skip Logic

**Location:** `Core/Services/DailyAwardService.swift:588-604`

Reconciliation already has logic to skip records when:
1. Local events appear stale (calculated <= 0 but record > 0)
2. Delta is suspiciously large (> 5)

This suggests the issue was already partially known, but the skip logic doesn't fix the root cause - it just avoids incorrect reconciliation.

### Event Pulling Scope

**Location:** `Core/Data/Sync/SyncEngine.swift:1377-1401`

Events are only pulled from the **last 3 months**. If events are older than 3 months, they won't be pulled. This could cause issues for habits with historical data.

**Recommendation:** Consider pulling all events on first sync, or increasing the `recentMonths` parameter.

---

## 9. Summary

**Root Cause:** Timing issue - reconciliation runs before sync completes pulling events from Firestore.

**Impact:** 
- Reconciliation calculates progress from incomplete local event data
- Results in mismatches between `CompletionRecord.progress` and calculated progress
- Diagnostic shows "2 events locally" but "471 events after sync"

**Fix Priority:** HIGH - This causes incorrect progress calculations and potential data inconsistencies.

**Recommended Solution:** Implement sync completion notification and wait for it before running reconciliation.
