# PERSISTENCE DIAGNOSTIC PLAN

## THE SAVE CHAIN

```
UI (HomeView)
  └─> HomeViewState.setHabitProgress() [async]
      └─> HabitRepository.setProgress() [async throws]
          └─> HabitStore.setProgress() [async throws]
              └─> HabitStore.saveHabits() [async throws]
                  └─> activeStorage.saveHabits() [async throws]
                      ├─> DualWriteStorage.saveHabits()
                      │   ├─> secondaryStorage.saveHabits() [SwiftData]
                      │   │   └─> SwiftDataStorage.saveHabits()
                      │   │       └─> container.modelContext.save() ← ACTUAL SAVE
                      │   └─> Background Task: syncHabitsToFirestore()
                      └─> RETURN
```

## POTENTIAL FAILURE POINTS

1. **DualWriteStorage line 69**: Local save might be failing
2. **SwiftDataStorage line 201**: modelContext.save() might be throwing
3. **Error handling**: Errors might be caught and suppressed
4. **Task lifecycle**: Background Task might not execute if app closes

## DIAGNOSTIC LOGGING TO ADD

### 1. HabitRepository.setProgress()
- ✅ Already has logs
- Add: Timestamp when await starts
- Add: Timestamp when await completes
- Add: Explicit success/failure message

### 2. HabitStore.setProgress()
- ✅ Already has logs
- Add: Timestamp before saveHabits()
- Add: Timestamp after saveHabits()
- Add: Explicit confirmation of save completion

### 3. DualWriteStorage.saveHabits()
- ✅ Already has some logs
- Add: Timestamp before SwiftData save
- Add: Timestamp after SwiftData save
- Add: Catch block logging for any errors
- Add: Explicit confirmation of SwiftData save success

### 4. SwiftDataStorage.saveHabits()
- ✅ Already has logs
- Add: Log each habit being inserted/updated
- Add: Log before modelContext.save()
- Add: Log after modelContext.save()
- Add: Log any caught errors with full details
- Add: Verification that save actually persisted

## EXPECTED CONSOLE OUTPUT (SUCCESS)

```
🔄 HomeViewState: setHabitProgress called for Habit1, progress: 10
⏱️ AWAIT_START: setProgress() at 12:34:56.123
🎯 PERSISTENCE FIX: Using async/await to guarantee save completion
🔄 HabitRepository: Setting progress to 10 for habit 'Habit1' on 2025-10-22
✅ HabitRepository: UI updated immediately for habit 'Habit1' on 2025-10-22
🎯 PERSIST_START: Habit1 progress=10 date=2025-10-22
  ⏱️ HABITSTORE_START: setProgress() at 12:34:56.125
  🎯 DEBUG: HabitStore.setProgress called - will create CompletionRecord
  ⏱️ SAVE_START: saveHabits() at 12:34:56.127
  💾 DUALWRITE_START: Saving 2 habits
  💾 SWIFTDATA_START: SwiftDataStorage.saveHabits()
  ✅ SWIFTDATA_SAVE: modelContext.save() SUCCEEDED
  ✅ SWIFTDATA_END: Saved 2 habits in 0.032s
  ✅ DUALWRITE_END: Local write successful
  ⏱️ SAVE_END: saveHabits() at 12:34:56.159
  ⏱️ HABITSTORE_END: setProgress() at 12:34:56.160
✅ PERSIST_SUCCESS: Habit1 saved in 0.035s
✅ GUARANTEED: Data persisted to SwiftData
⏱️ AWAIT_END: setProgress() at 12:34:56.161
✅ GUARANTEED: Progress saved and persisted
```

## EXPECTED CONSOLE OUTPUT (FAILURE)

```
🔄 HomeViewState: setHabitProgress called for Habit1, progress: 10
⏱️ AWAIT_START: setProgress() at 12:34:56.123
🎯 PERSISTENCE FIX: Using async/await to guarantee save completion
🔄 HabitRepository: Setting progress to 10 for habit 'Habit1' on 2025-10-22
✅ HabitRepository: UI updated immediately for habit 'Habit1' on 2025-10-22
🎯 PERSIST_START: Habit1 progress=10 date=2025-10-22
  ⏱️ HABITSTORE_START: setProgress() at 12:34:56.125
  🎯 DEBUG: HabitStore.setProgress called - will create CompletionRecord
  ⏱️ SAVE_START: saveHabits() at 12:34:56.127
  💾 DUALWRITE_START: Saving 2 habits
  💾 SWIFTDATA_START: SwiftDataStorage.saveHabits()
  ❌ SWIFTDATA_SAVE_FAILED: Error: <error details>
  ❌ SWIFTDATA_END: modelContext.save() threw error
  ❌ DUALWRITE_END: Local write FAILED
❌ PERSIST_FAILED: Habit1 - <error details>
🔄 PERSIST_REVERT: Reverted Habit1 to progress=0
⏱️ AWAIT_END: setProgress() at 12:34:56.135
❌ Failed to set progress: <error details>
```

## NEXT STEP

Add the diagnostic logging, then ask user to:
1. Complete a habit
2. Copy ALL console output
3. We'll see EXACTLY where the save is failing

