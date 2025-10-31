# 🔧 Fix Plan - Critical Issues

## Root Cause Analysis

### Issue #3: Completion Not Persisting
**Root Cause**: CompletionRecords are saved, but when habits are reloaded, there might be:
1. **UserId mismatch**: Guest CompletionRecords have userId="" or anonymous userId, but when loading, it filters by current authenticated userId
2. **Save timing**: CompletionRecord is saved, but `saveHabits()` might be overwriting data
3. **Load timing**: Habits might be loaded before CompletionRecords are fully persisted

### Issue #4: Migration UI Not Showing
**Root Cause**: 
1. `hasGuestData()` is checking SwiftData, but when user signs up, the data is already migrated silently before the UI check
2. The check happens in `handleUserChange()` but migration might run before the check completes

### Issue #1: Migration UI Timing
**Root Cause**: `hasGuestData()` is probably being called during app initialization for authenticated users, detecting stale data

---

## Fix Strategy

### Step 1: Fix Completion Persistence (CRITICAL)
**Priority**: 🔴 HIGHEST

1. **Ensure CompletionRecords are saved synchronously**
   - Already done: `createCompletionRecordIfNeeded()` uses `try modelContext.save()` 
   - ✅ Verify it's awaited: Line 395 shows `await createCompletionRecordIfNeeded()`

2. **Fix userId consistency**
   - Problem: Guest creates CompletionRecord with userId="", but when loading, might filter by authenticated userId
   - Fix: Ensure migration happens BEFORE loading habits

3. **Add explicit save verification**
   - After saving CompletionRecord, verify it exists before returning
   - Add retry logic if save fails

### Step 2: Fix Migration UI Timing
**Priority**: 🟡 HIGH

1. **Only check for guest data when user transitions from unauthenticated → authenticated**
   - Don't check on app launch if user is already authenticated
   - Only check in `handleUserChange()` when auth state changes to `.authenticated`

2. **Check BEFORE migrating**
   - Current code checks, then migrates silently if no guest data detected
   - Need to check, show UI if needed, THEN migrate based on user choice

### Step 3: Fix Migration Detection
**Priority**: 🟡 HIGH

1. **Improve `hasGuestData()` to exclude already-migrated data**
   - Check if habits belong to current authenticated user (already migrated)
   - Only detect habits with userId="" or different userId when user just authenticated

---

## Implementation Order

1. ✅ **Fix Issue #3** (completion persistence) - Most critical
2. ✅ **Fix Issue #4** (migration UI) - Prevents data loss
3. ✅ **Fix Issue #1** (migration timing) - UX improvement
4. ⚠️ **Issue #2** (account deletion) - Can be handled separately

