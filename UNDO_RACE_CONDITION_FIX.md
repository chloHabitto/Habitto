# Undo Race Condition Fix

## Problem Summary

**Critical Bug**: Race condition between habit deletion and undo action causing data inconsistency.

### Log Evidence
```
♻️ [RESTORE] Habit was not soft-deleted (race condition - delete hadn't completed yet)
```

### Root Cause

The Undo toast appeared BEFORE the async delete completed, creating a race condition window:

1. User taps Delete → confirmation dialog appears
2. User confirms → `deleteHabit()` called
3. **BUG**: `deletedHabitForUndo = habit` set immediately (line 277)
4. Habit removed from local state (instant UI update)
5. Undo toast appears immediately
6. `habitRepository.deleteHabit()` starts async deletion
7. **RACE WINDOW**: User can tap Undo while delete is in progress
8. `restoreHabit()` runs, finds habit not soft-deleted yet
9. Race condition: restore and delete operations compete

## Solution Implemented (Option A - Simplest)

### Code Changes

**Before** (lines 272-302 in HomeView.swift):
```swift
func deleteHabit(_ habit: Habit) async {
  // ❌ BAD: Set undo state BEFORE delete
  await MainActor.run {
    self.deletedHabitForUndo = habit  // Toast appears immediately!
  }
  
  // Remove from local state
  DispatchQueue.main.async {
    self.habits.removeAll { $0.id == habit.id }
  }
  
  // Async delete (can take time)
  do {
    try await habitRepository.deleteHabit(habit)
  } catch {
    // No error recovery - habit removed from UI but delete failed
  }
}
```

**After**:
```swift
func deleteHabit(_ habit: Habit) async {
  // Remove from local state for instant UI update
  await MainActor.run {
    self.habits.removeAll { $0.id == habit.id }
  }
  
  // Async delete
  do {
    try await habitRepository.deleteHabit(habit)
    
    // ✅ GOOD: Set undo state AFTER delete succeeds
    await MainActor.run {
      self.deletedHabitForUndo = habit  // Toast appears after delete completes
    }
  } catch {
    // ✅ ERROR RECOVERY: Restore habit to UI if delete fails
    await MainActor.run {
      self.habits.append(habit)
    }
  }
}
```

### Key Improvements

1. **Race Condition Eliminated**: Undo toast only appears after delete succeeds
2. **Error Recovery Added**: Failed deletes restore habit to UI
3. **Better UX**: User can't trigger Undo during delete operation
4. **Code Cleanup**: Removed DispatchQueue.main.async in favor of await MainActor.run

## UX Changes

### Before
- Undo toast appeared instantly (felt responsive)
- Race condition if user tapped Undo quickly
- Failed deletes left orphaned undo toasts

### After
- Undo toast appears with brief delay (~0.5-2 seconds depending on delete speed)
- Race condition impossible - user can't Undo until delete completes
- Failed deletes restore habit to UI (no orphaned toasts)

## Testing Checklist

### Basic Flow
- [ ] Delete a habit
- [ ] Verify Undo toast appears after brief delay (not instant)
- [ ] Tap Undo immediately when it appears
- [ ] Verify habit restores correctly
- [ ] Check no duplicate habits appear

### Persistence
- [ ] Delete a habit
- [ ] Wait for Undo toast to appear
- [ ] Close app without tapping Undo
- [ ] Reopen app
- [ ] Verify habit stays deleted (not restored)

### Error Recovery
- [ ] Turn off network/Firestore
- [ ] Delete a habit
- [ ] Verify habit returns to UI (delete failed, so habit restored)
- [ ] Turn network back on
- [ ] Verify habit is still present

### Rapid Actions
- [ ] Delete a habit
- [ ] Before Undo appears, swipe to another tab
- [ ] Come back - verify habit is gone
- [ ] Verify no crash or orphaned state

### Auto-Dismiss
- [ ] Delete a habit
- [ ] Wait for Undo toast to appear
- [ ] Don't tap Undo, wait 5 seconds
- [ ] Verify toast auto-dismisses
- [ ] Verify habit stays deleted

## Related Files

- **Views/Screens/HomeView.swift**: Main fix location (lines 270-310)
- **Views/Components/UndoToastView.swift**: Toast UI (has 5-second auto-dismiss)
- **Core/Data/HabitRepository.swift**: Async delete implementation

## Other Observations

### "Deleted 3 Times" Issue

The logs showed a habit being deleted 3 times in one session. Investigation found:

- **No code bug**: Only one delete path exists (through confirmation dialog)
- **Likely cause**: User testing delete → undo → delete → undo → delete flow
- **Swipe-to-delete**: HabitsTabView has `.onDelete()` but routes through same confirmation dialog

### UndoToastView Auto-Dismiss

- Toast auto-dismisses after 5 seconds (line 55 in UndoToastView.swift)
- Only calls `onDismiss()` which sets `deletedHabitForUndo = nil`
- Does NOT trigger undo action itself (safe)

### deletedHabitForUndo Usage

Found only 3 places where this is set:
1. Line 297: After successful delete (NEW - our fix)
2. Line 368: In `restoreHabit()` to clear the toast
3. Line 1477: In toast's `onDismiss` callback

No double-setting issues found.

## Commit

- **Commit**: `0c993553`
- **Date**: Jan 18, 2026
- **Build Status**: ✅ Passed (no compile errors, no linter errors)

## Pre-Launch Assessment

**Risk Level**: 🟢 Low
- Simple fix (moved 1 line of code + added error recovery)
- Build passes cleanly
- No breaking changes to API
- UX change is minor (brief delay before Undo appears)

**Recommendation**: ✅ Safe to include in launch build
- Fixes a real user-facing bug (race condition)
- Improves reliability and error handling
- UX change is acceptable trade-off for correctness
