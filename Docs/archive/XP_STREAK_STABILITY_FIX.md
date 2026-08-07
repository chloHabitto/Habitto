# XP and Streak Value Stability Fix

## Problem

XP and streak values were changing/showing incorrect values before eventually settling on the correct number. Symptoms included:
- XP shows one value, then changes after screen refresh, navigation, or app restart
- Same behavior with streak counts
- Eventually shows correct value, but initial display is wrong

## Root Causes

### 1. Race Condition Between Multiple XP Sources

**Issue**: Multiple async operations updating XP in different orders:
- `XPManager.publishXP()` calculates from `completedDaysCount * 50` (immediate UI feedback)
- `DailyAwardService.refreshXPState()` loads from SwiftData DailyAward records (source of truth)
- `XPManager.applyXPState()` observer overwrites calculated values

**Timeline of race condition:**
1. User completes habit → `publishXP()` sets XP to 150 (calculated)
2. `refreshXPState()` loads from database → finds 200 XP
3. Observer `applyXPState()` overwrites 150 with 200
4. But then `publishXP()` might be called again with different value
5. Result: XP flickers between values

### 2. Observer Overwriting Recent Calculations

**Issue**: `applyXPState()` observer immediately overwrites values set by `publishXP()`, even when the calculated value is more recent.

### 3. Multiple Async Operations

**Issue**: Multiple async operations completing in different orders:
- `XPManager.init()` calls `refreshXPState()` async
- `HomeTabView.onAppear` calls `publishXP()` with calculated value
- Observer applies state, potentially overwriting calculated value

### 4. Streak Calculation Delay

**Issue**: `updateStreak()` has a 0.2 second delay and `updateAllStreaks()` has throttling logic, causing initial incorrect values.

## Solution

### 1. Added Comprehensive XP Trace Logging

**Files Modified:**
- `Core/Managers/XPManager.swift`
- `Core/Services/DailyAwardService.swift`
- `Views/Screens/HomeView.swift`

**Logging Format:**
```swift
print("💰 [XP_TRACE] \(timestamp) \(function) - START")
print("   Source: \(source)")
print("   Thread: \(Thread.isMainThread ? "Main" : "Background")")
print("   XP changing from \(oldXP) to \(newXP)")
print("💰 [XP_TRACE] \(timestamp) \(function) - COMPLETE")
```

This allows tracking every XP value change with:
- Timestamp
- Source (publishXP, refreshXPState, applyXPState, etc.)
- Thread (Main vs Background)
- Old and new values

### 2. Fixed Race Condition with Grace Period

**File**: `Core/Managers/XPManager.swift`

**Solution**: Added grace period to prevent observer from overwriting recent calculated values:

```swift
private var lastPublishXPTime: Date?
private let publishXPGracePeriod: TimeInterval = 0.5 // 500ms

// In applyXPState():
if let lastPublish = lastPublishXPTime {
  let timeSincePublish = timestamp.timeIntervalSince(lastPublish)
  if timeSincePublish < publishXPGracePeriod {
    // Skip overwriting - calculated value is more recent
    return
  }
}
```

**How it works:**
- When `publishXP()` is called, we track the timestamp
- `applyXPState()` checks if `publishXP()` was called recently (within 500ms)
- If so, it skips overwriting to allow the calculated value to be displayed
- After grace period, database value (source of truth) takes precedence

### 3. Improved Observer Logic

**File**: `Core/Managers/XPManager.swift`

**Changes:**
1. Only apply state if values actually changed
2. Don't overwrite with 0 if we have valid XP
3. Respect grace period for recent `publishXP()` calls
4. Comprehensive logging for debugging

### 4. Added Streak Trace Logging

**File**: `Views/Screens/HomeView.swift`

Added similar logging for streak updates to track value changes.

## Expected Behavior

### Before Fix:
1. User completes habit
2. `publishXP()` sets XP to 150 (calculated)
3. `refreshXPState()` loads 200 from database
4. Observer overwrites 150 with 200 immediately
5. XP flickers: 150 → 200

### After Fix:
1. User completes habit
2. `publishXP()` sets XP to 150 (calculated), tracks timestamp
3. `refreshXPState()` loads 200 from database
4. Observer checks grace period - `publishXP()` was just called
5. Observer skips overwriting (within grace period)
6. XP shows 150 (calculated) immediately
7. After 500ms, if observer fires again, it applies 200 (database value)
8. XP smoothly transitions: 150 → 200 (no flicker)

## Testing

To verify the fix:

1. **Complete a habit** → XP should update immediately without flickering
2. **Navigate between tabs** → XP should remain stable
3. **Close and reopen app** → XP should load correctly on first display
4. **Check console logs** → Should see `[XP_TRACE]` logs showing all value changes

### Expected Log Output:
```
💰 [XP_TRACE] <timestamp> publishXP() - START
   Source: countCompletedDays calculation
   XP changing from 100 to 150
💰 [XP_TRACE] <timestamp> publishXP() - COMPLETE

💰 [XP_TRACE] <timestamp> refreshXPState() - Updating xpState
   XP changing from 0 to 200
💰 [XP_TRACE] <timestamp> refreshXPState() - xpState updated

💰 [XP_TRACE] <timestamp> applyXPState() - START
   Last publishXP(): 0.10s ago
⚠️ [XP_TRACE] <timestamp> applyXPState() - SKIP (within grace period)
```

## Files Modified

1. `Core/Managers/XPManager.swift`
   - Added `lastPublishXPTime` tracking
   - Added grace period check in `applyXPState()`
   - Added comprehensive logging to `publishXP()`, `applyXPState()`, `loadUserXPFromSwiftData()`

2. `Core/Services/DailyAwardService.swift`
   - Added logging to `refreshXPState()`

3. `Views/Screens/HomeView.swift`
   - Added logging to `updateStreak()`

## Future Improvements

1. **Consider removing `publishXP()` entirely** - Use DailyAwardService as single source of truth
2. **Make DailyAwardService update immediately** - Award XP synchronously when habit completes
3. **Add debouncing** - Prevent rapid-fire updates
4. **Cache calculated values** - Store last calculated value to prevent unnecessary recalculations
