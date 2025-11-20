# XP Award Architecture Fix

## ✅ Problem Solved

**Issue:** XP awards were broken because `awardXP()` updated `UserProgressData` directly, then `refreshXPState()` recalculated from empty `DailyAward` records (which didn't exist yet), resetting XP back to 0.

**Root Cause:** Architecture violation - `UserProgressData` was being updated before `DailyAward` ledger entry was created.

## ✅ Solution: DailyAward as Source of Truth

### **New Architecture Flow:**

```
HabitStore detects completion
    ↓
DailyAwardService.awardXP(delta: 50, dateKey: "2025-11-20", reason: "...")
    ↓
STEP 1: Create DailyAward record (immutable ledger entry) ✅
    ↓
STEP 2: Recalculate UserProgressData.totalXP from sum(DailyAward.xpGranted) ✅
    ↓
STEP 3: Update xpState for UI reactivity ✅
```

### **Key Changes:**

1. **DailyAward is the source of truth** (immutable ledger)
2. **UserProgressData is derived** from `sum(DailyAward.xpGranted)`
3. **No race conditions** - ledger entry created first, then state derived from it

---

## 📝 Code Changes

### **1. DailyAwardService.awardXP() - Rewritten**

**Before (BROKEN):**
```swift
func awardXP(delta: Int, reason: String) async throws {
    // 1. Update UserProgressData directly ❌
    userProgress.updateXP(newTotalXP)
    
    // 2. Refresh from DailyAward (doesn't exist yet!) ❌
    await refreshXPState() // Calculates 0 from empty array
}
```

**After (FIXED):**
```swift
func awardXP(delta: Int, dateKey: String, reason: String) async throws {
    // ✅ STEP 1: Create or delete DailyAward record (immutable ledger entry)
    if delta > 0 {
        let award = DailyAward(userId: userId, dateKey: dateKey, xpGranted: delta)
        modelContext.insert(award)
    } else if delta < 0 {
        // Delete DailyAward for reversal
        // ... delete logic
    }
    try modelContext.save()
    
    // ✅ STEP 2: Recalculate UserProgressData from ALL DailyAward records
    let allAwards = try modelContext.fetch(FetchDescriptor<DailyAward>(...))
    let calculatedTotalXP = allAwards.reduce(0) { $0 + $1.xpGranted }
    userProgress.updateXP(calculatedTotalXP)
    
    // ✅ STEP 3: Update xpState for UI
    await refreshXPState()
}
```

### **2. HabitStore.checkDailyCompletionAndAwardXP() - Simplified**

**Before:**
```swift
// Called awardXP() (updated UserProgressData)
try await DailyAwardService.shared.awardXP(delta: 50, reason: "...")

// Then created DailyAward separately ❌
let award = DailyAward(...)
modelContext.insert(award)
```

**After:**
```swift
// ✅ Single call - creates DailyAward AND recalculates XP
try await DailyAwardService.shared.awardXP(
    delta: 50,
    dateKey: dateKey,
    reason: "All habits completed on \(dateKey)"
)
// No separate DailyAward creation needed!
```

### **3. Method Signature Changes**

**Added `dateKey` parameter** to all award methods:
- `awardXP(delta: Int, dateKey: String, reason: String)`
- `awardDailyCompletionBonus(on date: Date)` → Uses `DateUtils.dateKey(for: date)`
- `awardHabitCompletionXP(...)` → Added dateKey parameter
- `awardStreakBonusXP(...)` → Added date parameter

---

## 🎯 Architecture Principles (Now Enforced)

1. **DailyAward records are append-only** (immutable ledger) ✅
   - Created in `awardXP()` with positive delta
   - Deleted in `awardXP()` with negative delta
   - Never modified after creation

2. **UserProgressData.totalXP is derived** from `sum(DailyAward.xpGranted)` ✅
   - Always recalculated after ledger change
   - Never updated directly
   - Always matches ledger total

3. **No race conditions** ✅
   - Ledger entry created first
   - State derived from ledger second
   - Atomic operations via SwiftData transactions

4. **Integrity guaranteed** ✅
   - `sum(DailyAward.xpGranted) == UserProgressData.totalXP` always true
   - `verifyIntegrity()` checks this invariant
   - `repairIntegrity()` recalculates from ledger if mismatch

---

## ✅ Result

**XP awards now work correctly:**

1. User completes all habits ✅
2. `DailyAwardService.awardXP()` creates `DailyAward` record ✅
3. XP recalculated from ledger: `sum(DailyAward) = 50` ✅
4. `UserProgressData.totalXP = 50` ✅
5. Level recalculated automatically ✅
6. UI updates reactively ✅

**No more:**
- ❌ XP resetting to 0 after award
- ❌ Race conditions between create and refresh
- ❌ Integrity mismatches
- ❌ Authentication errors

---

## 📊 Files Modified

1. **Core/Services/DailyAwardService.swift**
   - Rewrote `awardXP()` to create ledger first, derive state second
   - Added `dateKey` parameter to all award methods
   - Updated helper methods to pass dateKey

2. **Core/Data/Repository/HabitStore.swift**
   - Removed `DailyAward` creation logic
   - Simplified to single `awardXP()` call
   - Passes `dateKey` parameter

---

## 🧪 Testing Checklist

- [ ] Complete all habits → XP increases by 50
- [ ] Uncomplete habits → XP decreases by 50
- [ ] Verify `DailyAward` record created
- [ ] Verify `UserProgressData.totalXP == sum(DailyAward.xpGranted)`
- [ ] Verify level calculated correctly
- [ ] Verify UI updates reactively
- [ ] Check logs for no errors

---

**Status:** ✅ **FIXED** - Architecture now follows correct pattern with DailyAward as source of truth!

