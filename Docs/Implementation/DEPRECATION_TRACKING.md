# Deprecated Code Tracking

**Last Updated:** January 2025
**Purpose:** Track deprecated code paths that need migration before removal.

## Overview

This document tracks deprecated code that still has active dependencies. These cannot be removed until all usages are migrated.

---

## Deprecated Properties in Habit Model

### 1. `isCompleted` (stored property)

**Status:** Deprecated in Phase 4  
**Location:** `Core/Models/HabitComputed.swift`  
**Replacement:** `isCompleted(for: Date)` method  

**Current Usages:**
- [ ] `ScheduledHabitItem.swift` - observes completion state
- [ ] Need to audit other files

**Safe to remove:** ❌ NO - UI still depends on it

---

### 2. `streak` (stored property)

**Status:** Deprecated in Phase 4  
**Location:** `Core/Models/HabitComputed.swift`  
**Replacement:** `computedStreak()` method  

**Current Usages:**
- [ ] Need to audit files that access `habit.streak`

**Safe to remove:** ❌ NO - UI still depends on it

---

### 3. `completionHistory` direct observation

**Status:** Should migrate to event-based updates  
**Location:** Various UI components  

**Current Usages:**
- [ ] `ScheduledHabitItem.swift:198-213` - `.onChange(of: habit.completionHistory)`
- [ ] HomeTabView celebration logic
- [ ] Need to audit other files

**Migration Plan:**
1. Update observers to use `@Query` or event notifications
2. Calculate from `ProgressEvents` instead of `completionHistory`

**Safe to remove:** ❌ NO - UI reactivity depends on it

---

### 4. Direct `completionHistory` writes in `HabitStore.setProgress()`

**Status:** Deprecated - marked with TODO  
**Location:** `Core/Data/Repository/HabitStore.swift:625-630`  
```swift
// ⚠️ DEPRECATED: Direct state update - kept for backward compatibility
// TODO: Remove this once all code paths use event replay
currentHabits[index].completionHistory[dateKey] = progress
currentHabits[index].completionStatus[dateKey] = isComplete
```

**Safe to remove:** ❌ NO - Required for UI observers and fallback

---

## Migration Checklist (Phase 5)

Before removing deprecated code:

- [ ] Audit all usages of `habit.isCompleted` property
- [ ] Audit all usages of `habit.streak` property  
- [ ] Migrate `ScheduledHabitItem` to not observe `completionHistory` directly
- [ ] Migrate `HomeTabView` celebration logic to use events
- [ ] Add integration tests for event-based updates
- [ ] Verify all habits have `ProgressEvents` (migration complete)
- [ ] Remove deprecated properties from `HabitComputed.swift`
- [ ] Remove direct writes from `HabitStore.setProgress()`

---

## How to Use This Document

1. Before removing any deprecated code, check this document
2. Update the checkboxes as usages are migrated
3. Only mark "Safe to remove: ✅ YES" when ALL usages are migrated
4. Test thoroughly before removing deprecated code
