# Progress Tab Fix: Partial Progress State Implementation

**Date**: January 24, 2026  
**Status**: ✅ COMPLETED  
**Commit**: `22b9156d`

## Problem Summary

In the Progress tab → All Habits → Daily → Today's Activity (TodaysJourneyView), habit cards with partial progress (e.g., 2/5 completed) were displaying incorrect visual indicators:

- ❌ **Incorrect**: Showing checkmark icon (reserved for fully completed habits)
- ❌ **Incorrect**: Not showing progress text or progress bar

This was caused by `TodaysJourneyView.loadJourneyItems()` using `habit.isCompletedForDate()`, which returns `true` when `completionCount > 0` (any progress), treating all partial progress as "completed".

## Solution Overview

Implemented a three-state completion model for habit cards:

1. **Pending** (0 progress): No checkmark, show progress text + bar
2. **InProgress** (partial progress): No checkmark, show progress text + bar  
3. **Completed** (goal reached): Show checkmark + difficulty badge

## Changes Made

### 1. TodaysJourneyModels.swift

Added `.inProgress` case to the `JourneyItemStatus` enum:

```swift
enum JourneyItemStatus: Equatable {
  case completed
  case inProgress  // has progress but not yet completed
  case pending     // not started (0 progress)
}
```

**Impact**: Enables the model layer to represent three distinct completion states.

---

### 2. TodaysJourneyView.swift

#### Updated `pendingItems` computed property

```swift
private var pendingItems: [JourneyHabitItem] {
  journeyItems
    .filter { $0.status == .pending || $0.status == .inProgress }  // ← Include inProgress
    .sorted { ... }
}
```

**Impact**: Groups both pending and inProgress habits together for timeline display.

---

#### Rewrote `loadJourneyItems()` function

The critical fix that determines the correct status based on actual completion state:

```swift
private func loadJourneyItems() {
  let scheduled = scheduledHabits
  let calendar = Calendar.current
  let isToday = calendar.isDate(selectedDate, inSameDayAs: Date())
  let dateKey = Habit.dateKey(for: selectedDate)

  var items: [JourneyHabitItem] = []

  for habit in scheduled {
    // Get current progress and goal
    let progress = habit.completionHistory[dateKey] ?? 0
    let goalAmount = habit.goalAmount(for: selectedDate)
    
    // Determine completion status: completed = progress >= goal
    let isFullyCompleted = goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)
    let hasPartialProgress = progress > 0 && !isFullyCompleted
    
    // Determine status
    let status: JourneyItemStatus
    if isFullyCompleted {
      status = .completed
    } else if hasPartialProgress {
      status = .inProgress      // ← NEW: Partial progress gets its own state
    } else {
      status = .pending
    }
    
    // ... rest of logic ...
  }

  journeyItems = items
}
```

**Key Logic**:
- `isFullyCompleted`: `progress >= goalAmount` (or `progress > 0` if goal is 0)
- `hasPartialProgress`: `progress > 0 && !isFullyCompleted`
- Status assignment based on these conditions

**Impact**: Correctly classifies habits into their appropriate state instead of treating any progress as completed.

---

### 3. TodaysJourneyItemView.swift

#### Updated `timeLine1` and `timeLine2` functions

Both now handle `.inProgress` with the same logic as `.pending`:

```swift
private var timeLine1: String {
  switch item.status {
  case .completed:
    guard let t = item.completionTime else { return "—" }
    return Self.timeFormatter.string(from: t)
  case .inProgress, .pending:  // ← Handle both the same way
    guard let t = estimatedTime else { return "—" }
    let now = Date()
    if t > now {
      return "~" + Self.timeFormatter.string(from: t)
    } else {
      return "—"
    }
  }
}
```

**Impact**: Time display remains consistent for both pending and inProgress states.

---

#### Updated `lineSegment()` function

Timeline line styling now treats `.inProgress` as pending (dashed line):

```swift
private func lineSegment(position: LinePosition) -> some View {
  let isPending = item.status == .pending || item.status == .inProgress  // ← Include inProgress
  let lineColor = isPending ? Color.appOutline02 : Color.appPrimaryOpacity10
  
  return GeometryReader { geo in
    if isPending {
      // Dashed line for pending items
      Path { path in
        path.move(to: CGPoint(x: 1.5, y: 0))
        path.addLine(to: CGPoint(x: 1.5, y: geo.size.height))
      }
      .stroke(lineColor, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
    } else {
      // Solid line for completed items
      Rectangle()
        .fill(lineColor)
        .frame(width: 3, height: geo.size.height)
    }
  }
  .frame(width: 3)
}
```

**Impact**: Visual timeline shows dashed lines for both pending and inProgress habits, solid lines for completed.

---

#### Updated `cardColumn` view

The main card display now correctly handles all three states:

```swift
private var cardColumn: some View {
  HStack(alignment: .top, spacing: 12) {
    HabitIconView(habit: item.habit)
      .frame(width: 36, height: 36)

    VStack(alignment: .leading, spacing: 4) {
      Text(item.habit.name)
        .font(.appLabelLargeEmphasised)
        .foregroundColor(.appText01)
        .lineLimit(2)
        .truncationMode(.tail)
      
      switch item.status {
      case .completed:
        if let difficulty = item.difficulty {
          DifficultyBadge(difficulty: difficulty)
        }
      case .inProgress, .pending:  // ← Both show progress content
        progressContent
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    
    // Checkmark ONLY for completed
    if item.status == .completed {  // ← Explicitly .completed only
      Image(systemName: "checkmark")
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(.white)
        .frame(width: 24, height: 24)
        .background(Circle().fill(Color.green))
    }
  }
  .padding(.top, 12)
  .padding(.leading, 12)
  .padding(.trailing, 12)
  .padding(.bottom, 16)
  .background(...)
  .overlay(...)
  .opacity(item.status == .completed ? 1 : 0.8)  // ← Pending + inProgress get 0.8 opacity
  .padding(.top, isFirst ? 0 : 16)
}
```

**Key Changes**:
- `case .inProgress, .pending`: Both show `progressContent` (progress text + bar)
- `if item.status == .completed`: Checkmark shown only for fully completed habits
- `opacity`: InProgress habits get 0.8 opacity (same as pending) instead of 1.0

**Impact**: Partial progress cards now display progress information with no checkmark, matching the expected behavior.

---

#### Updated preview

Updated the preview to include a `.inProgress` example for testing purposes.

---

## Behavior After Fix

| Status | Progress Text | Progress Bar | Checkmark | Difficulty Badge | Timeline Line |
|--------|:----:|:----:|:----:|:----:|:----:|
| **Pending** (0/5) | ✅ | ✅ | ❌ | ❌ | Dashed |
| **InProgress** (2/5) | ✅ | ✅ | ❌ | ❌ | Dashed |
| **Completed** (5/5) | ❌ | ❌ | ✅ | ✅ | Solid |

---

## Testing Instructions

### Test Case 1: Partial Progress Display
1. Create a habit with goal > 1 (e.g., "Read 5 pages")
2. Increment progress partially (e.g., 2/5)
3. Navigate to Progress tab → All Habits → Daily
4. Verify the card shows:
   - ✅ Progress text: "Progress: 2/5"
   - ✅ Progress bar (partially filled)
   - ✅ NO checkmark
   - ✅ NO difficulty badge

### Test Case 2: Full Completion Display
1. With the same habit at 2/5, increment to 5/5
2. Verify the card now shows:
   - ✅ Checkmark icon (green circle with checkmark)
   - ✅ Difficulty badge (if applicable)
   - ✅ NO progress bar
   - ✅ NO progress text

### Test Case 3: No Progress Display
1. Create a new habit and don't add any progress
2. Verify the card shows:
   - ✅ Progress text: "Progress: 0/5"
   - ✅ Progress bar (empty/minimal fill)
   - ✅ NO checkmark

### Test Case 4: Timeline Consistency
1. Have multiple habits at different progress states on the same day
2. Verify timeline shows:
   - ✅ Dashed line for pending habits
   - ✅ Dashed line for inProgress habits
   - ✅ Solid line for completed habits

---

## Files Modified

- ✅ `Views/Components/Progress/TodaysJourneyModels.swift`
- ✅ `Views/Components/Progress/TodaysJourneyView.swift`
- ✅ `Views/Components/Progress/TodaysJourneyItemView.swift`

## Linter Status

✅ All files compile without errors or warnings.

---

## Impact Analysis

### Backward Compatibility
- ✅ No breaking changes to existing APIs
- ✅ All existing enum cases preserved (only added `.inProgress`)
- ✅ No changes to data models

### Performance
- ✅ No performance degradation
- ✅ Logic remains O(n) where n = number of scheduled habits
- ✅ No additional database queries

### User Experience
- ✅ Improved clarity: Partial progress clearly distinguished from full completion
- ✅ Better visual feedback: Progress bar shows what remains to be done
- ✅ Consistent styling: InProgress and pending states visually related

---

## Future Enhancements

Potential improvements for consideration:
1. Add animation when transitioning from inProgress to completed
2. Show streak protection information on inProgress cards
3. Add estimated time to completion based on progress velocity
4. Implement smart sorting to show at-risk inProgress habits first

---

**Implementation Date**: January 24, 2026  
**Author**: Chloe (AI Assistant)  
**Status**: ✅ COMPLETE - Ready for deployment
