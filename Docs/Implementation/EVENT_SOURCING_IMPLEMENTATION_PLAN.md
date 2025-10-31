# 🎯 Priority 1: Event Sourcing Integration - Implementation Plan

## Overview

This document outlines the detailed implementation plan for integrating event sourcing into the habit completion flow. This is the foundation for conflict-free sync and production-ready architecture.

## Answers to Your Questions

### 1. Migration Strategy: Synthetic Events vs. Forward-Only

**Recommendation: Forward-Only (No Synthetic Events)**

**Rationale:**
- ✅ Simpler implementation - no migration complexity
- ✅ Existing `CompletionRecord` data remains valid for historical queries
- ✅ Events start clean from implementation date
- ✅ Avoids potential data inconsistencies from migration
- ✅ Faster rollout - no migration script needed

**Approach:**
- Keep existing `CompletionRecord` data as-is (read-only for historical dates)
- All new completions create `ProgressEvent` + update `CompletionRecord`
- Over time, recent dates will have events; old dates won't (acceptable)
- When querying, prefer events if available, fallback to `CompletionRecord`

### 2. Implementation Approach: Incremental vs. All-at-Once

**Recommendation: Incremental with Feature Flag**

**Phase 1**: Core event creation (this PR)
- Move `ProgressEvent` out of Archive
- Create events for new completions
- Keep existing `CompletionRecord` flow working

**Phase 2**: Materialized view optimization (next PR)
- Optimize `CompletionRecord` updates from events
- Add event replay for consistency checks

**Phase 3**: Sync integration (Priority 3)
- Use events for sync
- Deprecate direct `CompletionRecord` creation

### 3. Feature Flag Strategy

**Recommendation: Use Feature Flag with Gradual Rollout**

- Add `enableEventSourcing` flag to `NewArchitectureFlags`
- Start with flag OFF (events created but not used for reads)
- Enable for test accounts first
- Monitor for issues, then full rollout
- Allows instant rollback if problems detected

---

## Implementation Steps

### Step 1: Move ProgressEvent Out of Archive

**File**: `Core/Models/Archive/ProgressEvent.swift` → `Core/Models/ProgressEvent.swift`

**Changes:**
1. Move file from `Archive/` to main `Models/` directory
2. Ensure it's included in SwiftData schema (already is - line 19 in `SwiftDataContainer.swift`)
3. Add to imports where needed

**Verification:**
```swift
// SwiftDataContainer.swift should already have:
ProgressEvent.self, // ✅ EVENT SOURCING: Added ProgressEvent model
```

---

### Step 2: Create DeviceId Helper

**New File**: `Core/Utils/DeviceIdProvider.swift`

```swift
import Foundation
import UIKit

/// Provides stable device identifier for event sourcing
@MainActor
final class DeviceIdProvider {
    static let shared = DeviceIdProvider()
    
    private let deviceId: String
    
    private init() {
        // Generate stable device ID: "iOS_{model}_{identifierForVendor}"
        let model = UIDevice.current.model
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.deviceId = "iOS_\(model)_\(vendorId)"
        
        print("🔧 DeviceIdProvider: Generated deviceId: \(deviceId)")
    }
    
    /// Get current device ID
    var currentDeviceId: String {
        deviceId
    }
}
```

**Usage:**
```swift
let deviceId = DeviceIdProvider.shared.currentDeviceId
```

---

### Step 3: Create Event Creation Service

**New File**: `Core/Services/ProgressEventService.swift`

```swift
import Foundation
import SwiftData
import OSLog

/// Service for creating and managing ProgressEvents
@MainActor
final class ProgressEventService {
    static let shared = ProgressEventService()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "ProgressEventService")
    private let deviceId: String
    private let timezoneIdentifier: String
    
    private init() {
        self.deviceId = DeviceIdProvider.shared.currentDeviceId
        self.timezoneIdentifier = TimeZone.current.identifier
    }
    
    /// Create a progress event for a habit completion change
    func createEvent(
        habitId: UUID,
        date: Date,
        dateKey: String,
        eventType: ProgressEventType,
        progressDelta: Int,
        userId: String,
        note: String? = nil,
        metadata: String? = nil
    ) async throws -> ProgressEvent {
        logger.info("Creating ProgressEvent: habitId=\(habitId), dateKey=\(dateKey), type=\(eventType.rawValue), delta=\(progressDelta)")
        
        // Calculate UTC day boundaries for timezone safety
        let calendar = Calendar.current
        let timezone = TimeZone.current
        
        // Get start and end of day in local timezone
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        // Convert to UTC for storage
        let utcDayStart = dayStart.addingTimeInterval(-TimeInterval(timezone.secondsFromGMT(for: dayStart)))
        let utcDayEnd = dayEnd.addingTimeInterval(-TimeInterval(timezone.secondsFromGMT(for: dayEnd)))
        
        // Create event
        let event = ProgressEvent(
            habitId: habitId,
            dateKey: dateKey,
            eventType: eventType,
            progressDelta: progressDelta,
            userId: userId,
            deviceId: deviceId,
            timezoneIdentifier: timezoneIdentifier,
            utcDayStart: utcDayStart,
            utcDayEnd: utcDayEnd,
            note: note,
            metadata: metadata
        )
        
        // Save to SwiftData
        let modelContext = SwiftDataContainer.shared.modelContext
        modelContext.insert(event)
        try modelContext.save()
        
        logger.info("✅ Created ProgressEvent: id=\(event.id.prefix(20))..., operationId=\(event.operationId.prefix(20))...")
        
        return event
    }
    
    /// Determine event type from progress change
    static func eventTypeForProgressChange(oldProgress: Int, newProgress: Int, goalAmount: Int) -> ProgressEventType {
        let delta = newProgress - oldProgress
        
        if delta == 0 {
            // No change - shouldn't happen, but handle gracefully
            return .increment
        }
        
        if oldProgress < goalAmount && newProgress >= goalAmount {
            // Just completed (toggle to complete)
            return .toggleComplete
        } else if oldProgress >= goalAmount && newProgress < goalAmount {
            // Just uncompleted (toggle to incomplete)
            return .toggleComplete
        } else if delta > 0 {
            // Increment
            return .increment
        } else {
            // Decrement
            return .decrement
        }
    }
}
```

---

### Step 4: Refactor HabitStore.setProgress() to Create Events

**File**: `Core/Data/Repository/HabitStore.swift`

**Changes to `setProgress()` method:**

```swift
func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let dateKey = CoreDataManager.dateKey(for: date)
    logger.info("Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
    
    // Get current user ID
    let userId = await CurrentUser().idOrGuest
    
    // Load current habits
    var currentHabits = try await loadHabits()
    
    guard let index = currentHabits.firstIndex(where: { $0.id == habit.id }) else {
        logger.error("Habit not found in storage: \(habit.name)")
        throw DataError.storage(StorageError(
            type: .fileNotFound,
            message: "Habit not found: \(habit.name)",
            severity: .error))
    }
    
    // Get old progress for event creation
    let oldProgress = currentHabits[index].completionHistory[dateKey] ?? 0
    let goalAmount = StreakDataCalculator.parseGoalAmount(from: currentHabits[index].goal)
    
    // ✅ NEW: Create ProgressEvent BEFORE updating progress
    if NewArchitectureFlags.shared.useEventSourcing {
        let eventType = ProgressEventService.eventTypeForProgressChange(
            oldProgress: oldProgress,
            newProgress: progress,
            goalAmount: goalAmount
        )
        
        let progressDelta = progress - oldProgress
        
        do {
            let event = try await ProgressEventService.shared.createEvent(
                habitId: habit.id,
                date: date,
                dateKey: dateKey,
                eventType: eventType,
                progressDelta: progressDelta,
                userId: userId
            )
            logger.info("✅ Created ProgressEvent: \(event.id)")
        } catch {
            logger.error("❌ Failed to create ProgressEvent: \(error)")
            // Don't throw - continue with existing flow for backward compatibility
        }
    }
    
    // ✅ EXISTING: Update habit progress (keep existing logic)
    currentHabits[index].completionHistory[dateKey] = progress
    let isComplete = progress >= goalAmount
    currentHabits[index].completionStatus[dateKey] = isComplete
    
    // ✅ EXISTING: Handle timestamps (keep existing logic)
    let currentTimestamp = Date()
    if progress > oldProgress {
        if currentHabits[index].completionTimestamps[dateKey] == nil {
            currentHabits[index].completionTimestamps[dateKey] = []
        }
        currentHabits[index].completionTimestamps[dateKey]?.append(currentTimestamp)
    } else if progress < oldProgress {
        if currentHabits[index].completionTimestamps[dateKey]?.isEmpty == false {
            currentHabits[index].completionTimestamps[dateKey]?.removeLast()
        }
    }
    
    // ✅ EXISTING: Create/update CompletionRecord (materialized view)
    await createCompletionRecordIfNeeded(
        habit: currentHabits[index],
        date: date,
        dateKey: dateKey,
        progress: progress)
    
    // ✅ EXISTING: Save habits
    try await saveHabits(currentHabits)
    logger.info("Successfully updated progress for habit '\(habit.name)' on \(dateKey)")
}
```

**Key Points:**
- Events created BEFORE progress update (audit trail)
- Feature flag gated (`useEventSourcing`)
- Existing `CompletionRecord` flow continues (materialized view)
- Graceful fallback if event creation fails

---

### Step 5: Add Feature Flag

**File**: `Core/Utils/FeatureFlags.swift`

**Add to `NewArchitectureFlags` class:**

```swift
/// Use event sourcing for progress tracking
@Published var useEventSourcing = false {
    didSet {
        if useEventSourcing {
            print("✅ NewArchitectureFlags: Event sourcing ENABLED")
        } else {
            print("📦 NewArchitectureFlags: Using direct progress updates")
        }
        if !useNewArchitecture {
            saveFlags()
        }
    }
}
```

**Update `enableAll()` method:**

```swift
func enableAll() {
    useNewArchitecture = true
    useEventSourcing = true  // ✅ Add this
    print("🚀 NewArchitectureFlags: All features ENABLED")
}
```

**Update `anyEnabled` computed property:**

```swift
var anyEnabled: Bool {
    return useNewArchitecture ||
           useNewProgressTracking ||
           useNewStreakCalculation ||
           useNewXPSystem ||
           useEventSourcing  // ✅ Add this
}
```

---

### Step 6: Update UI Gesture Handlers (No Changes Needed)

**Good News**: No changes required!

The current flow already works:
1. `ScheduledHabitItem` calls `onProgressChange` callback
2. `HomeTabView` calls `onSetProgress` → `HabitRepository.setProgress()`
3. `HabitRepository` calls `HabitStore.setProgress()`
4. **NEW**: `HabitStore.setProgress()` now creates events

The UI layer doesn't need to know about events - it's transparent.

---

### Step 7: Implement Event-to-Progress Calculation (Future Enhancement)

**Note**: This is optional for Phase 1. We'll keep the existing `CompletionRecord` creation flow for now.

**Future File**: `Core/Services/ProgressMaterializationService.swift` (Phase 2)

```swift
/// Materializes CompletionRecord from ProgressEvents
func materializeCompletionRecord(
    habitId: UUID,
    dateKey: String,
    userId: String,
    modelContext: ModelContext
) async throws -> CompletionRecord {
    // Fetch all events for this habit+date
    let events = try modelContext.fetch(
        ProgressEvent.eventsForHabitDate(habitId: habitId, dateKey: dateKey)
    )
    
    // Sum progress deltas
    let totalProgress = events.reduce(0) { $0 + $1.progressDelta }
    
    // Get goal to determine completion status
    // ... (fetch habit goal)
    
    // Create/update CompletionRecord
    // ...
}
```

---

## Testing Strategy

### Unit Tests

1. **Event Creation Test**
   ```swift
   func testCreateProgressEvent() async throws {
       let event = try await ProgressEventService.shared.createEvent(
           habitId: testHabitId,
           date: testDate,
           dateKey: "2025-01-15",
           eventType: .increment,
           progressDelta: 1,
           userId: "test_user"
       )
       
       XCTAssertFalse(event.id.isEmpty)
       XCTAssertFalse(event.operationId.isEmpty)
       XCTAssertEqual(event.habitId, testHabitId)
       XCTAssertEqual(event.progressDelta, 1)
   }
   ```

2. **Event Type Detection Test**
   ```swift
   func testEventTypeForToggleComplete() {
       let type = ProgressEventService.eventTypeForProgressChange(
           oldProgress: 0,
           newProgress: 5,
           goalAmount: 5
       )
       XCTAssertEqual(type, .toggleComplete)
   }
   ```

### Integration Tests

1. **End-to-End Completion Flow**
   - Complete habit → verify event created
   - Check `CompletionRecord` updated
   - Verify both in SwiftData

2. **Feature Flag Off**
   - Verify no events created when flag OFF
   - Verify existing flow still works

3. **Concurrent Completions**
   - Multiple rapid completions
   - Verify no duplicate events (operationId deduplication)

---

## Migration Checklist

- [ ] Move `ProgressEvent.swift` from Archive to Models
- [ ] Create `DeviceIdProvider.swift`
- [ ] Create `ProgressEventService.swift`
- [ ] Add `useEventSourcing` feature flag
- [ ] Refactor `HabitStore.setProgress()` to create events
- [ ] Add logging for event creation
- [ ] Test with feature flag OFF (existing flow)
- [ ] Test with feature flag ON (event creation)
- [ ] Verify events appear in SwiftData
- [ ] Verify `CompletionRecord` still created
- [ ] Update documentation

---

## Rollout Plan

### Week 1: Implementation
- Complete all implementation steps
- Internal testing with flag OFF
- Verify no regressions

### Week 2: Beta Testing
- Enable flag for test accounts only
- Monitor event creation logs
- Verify data consistency

### Week 3: Gradual Rollout
- Enable for 10% of users
- Monitor error rates
- Check event creation success rate

### Week 4: Full Rollout
- Enable for all users
- Monitor for issues
- Plan Phase 2 (materialized view optimization)

---

## Risk Mitigation

1. **Event Creation Fails**
   - ✅ Graceful fallback - existing flow continues
   - ✅ Logged but doesn't block completion

2. **Performance Impact**
   - ✅ Events are lightweight (small records)
   - ✅ Created asynchronously
   - ✅ Can be optimized with batching later

3. **Data Consistency**
   - ✅ Events created BEFORE progress update
   - ✅ `CompletionRecord` still created (dual-write)
   - ✅ Can replay events if inconsistency detected

4. **Feature Flag Rollback**
   - ✅ Instant disable via flag
   - ✅ No data migration needed
   - ✅ Existing data remains valid

---

## Success Metrics

- ✅ Events created for 100% of completions (when flag ON)
- ✅ Zero regressions in existing completion flow
- ✅ Event creation success rate > 99.9%
- ✅ No performance degradation (< 50ms overhead)

---

## Next Steps After This PR

1. **Priority 2**: Switch to Deterministic IDs
2. **Priority 3**: Implement SyncEngine
3. **Phase 2**: Optimize materialized view from events
4. **Phase 3**: Use events for conflict resolution

---

## Questions?

If anything is unclear or needs adjustment, let me know and I'll update the plan accordingly.

