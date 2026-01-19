# Skip Habit Feature - Implementation Summary

## Overview
The Skip Habit feature allows users to mark days as "skipped" with a reason, preserving their streak without counting the day as completed. This is useful for legitimate reasons like illness, travel, or equipment unavailability.

---

## Phase 1: Data Models ✅ COMPLETE

### Created Files

#### `Core/Models/SkipReason.swift`
New file containing:

**SkipReason Enum:**
- 7 predefined reasons: medical, travel, equipment, weather, emergency, rest, other
- Properties:
  - `rawValue` - Display string (e.g., "Medical/Health")
  - `icon` - SF Symbol name (e.g., "cross.case.fill")
  - `shortLabel` - Compact label (e.g., "Medical")

**HabitSkip Struct:**
- `habitId: UUID` - ID of the habit that was skipped
- `dateKey: String` - Date in "yyyy-MM-dd" format
- `reason: SkipReason` - The skip reason
- `customNote: String?` - Optional user note
- `createdAt: Date` - When skip was recorded

### Updated Files

#### `Core/Models/Habit.swift`
Added skip feature support:

**New Property:**
```swift
var skippedDays: [String: HabitSkip] = [:]
```

**New Methods:**
```swift
func isSkipped(for date: Date) -> Bool
func skipReason(for date: Date) -> SkipReason?
mutating func skip(for date: Date, reason: SkipReason, note: String? = nil)
mutating func unskip(for date: Date)
```

**Codable Support:**
- Added `skippedDays` to CodingKeys
- Updated encoder/decoder
- Updated all initializers

---

## Phase 2: Streak Calculation ✅ COMPLETE

### Updated: `Core/Models/Habit.swift` - `calculateTrueStreak()`

**Changes:**

1. **Initial Today Check:**
   - Added check for `todaySkipped`
   - If today is skipped, preserve streak and continue counting backwards
   - Does not increment streak counter for skipped days

2. **While Loop Condition:**
   - Added `|| isSkipped(for: currentDate)` to condition
   - Skipped days now preserve the streak chain

3. **Loop Logic:**
   - Check if day is skipped with `isSkipped(for: currentDate)`
   - Skipped days don't increment `calculatedStreak`
   - Debug info includes skip status

### Behavior Matrix

| Day Status | Increments Streak? | Breaks Streak? | Preserves Chain? |
|------------|-------------------|----------------|------------------|
| Completed ✅ | Yes | No | Yes |
| Skipped ⏭️ | No | No | Yes |
| Vacation 🏖️ | No | No | Yes |
| Missed ❌ | No | Yes | No |

### Example Scenarios

**Scenario 1: Skip in Middle**
```
Day -4: ✅ Completed (streak = 1)
Day -3: ✅ Completed (streak = 2)
Day -2: ⏭️  Skipped   (streak = 2, preserved)
Day -1: ✅ Completed (streak = 3)
Today:  ✅ Completed (streak = 4)

Final Streak: 4
```

**Scenario 2: Today Skipped**
```
Day -3: ✅ Completed (streak = 1)
Day -2: ✅ Completed (streak = 2)
Day -1: ✅ Completed (streak = 3)
Today:  ⏭️  Skipped   (streak = 3, preserved)

Final Streak: 3
```

**Scenario 3: Multiple Skips**
```
Day -4: ✅ Completed (streak = 1)
Day -3: ✅ Completed (streak = 2)
Day -2: ⏭️  Skipped   (streak = 2, preserved)
Day -1: ⏭️  Skipped   (streak = 2, preserved)
Today:  ✅ Completed (streak = 3)

Final Streak: 3
```

---

## Testing

### Created: `Tests/SkipFeatureTest.swift`

Comprehensive test suite with 4 test cases:
1. `testSkippedDayPreservesStreak()` - Skip in middle
2. `testTodaySkippedPreservesStreak()` - Today skipped
3. `testMultipleSkippedDaysPreserveStreak()` - Multiple consecutive skips
4. `testMissedDayBreaksStreak()` - Control test (missed ≠ skipped)

### Running Tests

Add to your app (debug build):
```swift
#if DEBUG
SkipFeatureTest.runAllTests()
#endif
```

---

## Code Quality

✅ No linter errors
✅ Backward compatible with existing data
✅ Follows existing code patterns
✅ Includes debug logging
✅ Comprehensive documentation
✅ Test coverage

---

## Integration Points

### Current Integration
- [x] Data models (Phase 1)
- [x] Streak calculation (Phase 2)
- [ ] UI components (Phase 3 - pending)
- [ ] Analytics (Phase 3 - pending)
- [ ] Firestore sync (Phase 4 - pending)

### Dependencies
- Uses existing `DateUtils.dateKey(for:)` for date keys
- Compatible with `VacationManager` (both preserve streaks)
- Integrates with existing `completionHistory` system
- Works with `CompletionMode` settings

---

## API Usage Examples

### Skipping a Day
```swift
var habit = // ... your habit
habit.skip(for: Date(), reason: .medical, note: "Doctor appointment")
```

### Checking if Day is Skipped
```swift
let isSkipped = habit.isSkipped(for: someDate)
if isSkipped {
    let reason = habit.skipReason(for: someDate)
    print("Skipped: \(reason?.rawValue ?? "Unknown")")
}
```

### Unskipping a Day
```swift
habit.unskip(for: someDate)
```

### Calculating Streak (Automatic)
```swift
let streak = habit.calculateTrueStreak()
// Automatically accounts for skipped days
```

---

## Data Structure

### Storage Format
```swift
// In Habit struct
skippedDays: [String: HabitSkip]

// Example:
[
  "2026-01-15": HabitSkip(
    habitId: UUID(...),
    dateKey: "2026-01-15",
    reason: .medical,
    customNote: "Doctor appointment",
    createdAt: Date(...)
  ),
  "2026-01-17": HabitSkip(
    habitId: UUID(...),
    dateKey: "2026-01-17",
    reason: .travel,
    customNote: "Business trip",
    createdAt: Date(...)
  )
]
```

---

## Next Steps: Phase 3 (UI)

### Planned Components
1. **Skip Button/Action** - In habit detail or calendar view
2. **Skip Dialog** - Select reason and add optional note
3. **Calendar Visualization** - Show skipped days with distinct styling
4. **Skip History View** - List all skips with reasons
5. **Analytics** - Skip patterns and insights
6. **Edit/Delete Skips** - Manage existing skip entries

### UI Design Considerations
- Distinct visual indicator for skipped days (e.g., diagonal line, special icon)
- Quick access to skip from today's habit card
- Ability to skip past days (within reason)
- Clear distinction from vacation mode
- Skip statistics in habit insights

---

## Phase 4 (Future): Firestore Sync

### Sync Considerations
- Add `skippedDays` to Firestore document schema
- Sync skip actions across devices
- Conflict resolution for skip edits
- Migration for existing users
- Backup and restore support

---

## Design Decisions

### Why Skipped Days Don't Increment Streak?
- **Consistency**: Similar to vacation mode
- **Honesty**: User didn't actually complete the habit
- **Motivation**: Preserves streak to maintain momentum
- **Flexibility**: Allows legitimate breaks without penalty

### Why Dictionary Storage?
- **Efficient lookup**: O(1) for date checks
- **Consistent pattern**: Matches `completionHistory`, `difficultyHistory`
- **Backward compatible**: Easy to add to existing Habit model
- **Codable**: Works seamlessly with existing persistence

### Why Separate from Vacation Mode?
- **Granularity**: Per-day, per-habit control vs. global vacation
- **Tracking**: Captures specific reasons for analytics
- **Intent**: Different user intent (skip vs. vacation)
- **History**: Permanent record with notes

---

## Known Limitations

1. **No UI Yet**: Phase 3 will add user interface
2. **No Firestore Sync**: Phase 4 will add cloud sync
3. **No Undo Stack**: Simple unskip, not full undo history
4. **No Bulk Operations**: One day at a time for now

---

## Backward Compatibility

✅ Existing habits work without changes
✅ Old data decodes correctly (`skippedDays` defaults to `[:]`)
✅ No breaking changes to existing methods
✅ Streak calculation gracefully handles missing skip data

---

## Performance Considerations

- Skip checks are O(1) dictionary lookups
- No performance impact on habits without skips
- Minimal memory overhead (only stores actual skips)
- Efficient encoding/decoding

---

## Summary

**Phase 1 & 2 Complete!** ✅

The Skip Habit feature data models and streak calculation logic are fully implemented and tested. Users can now skip days with reasons, and the streak calculation properly handles skipped days (preserving streaks without incrementing the counter).

Next phase will add the UI components to make this functionality accessible to users.
