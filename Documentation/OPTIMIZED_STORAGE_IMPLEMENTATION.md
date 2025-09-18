# Optimized UserDefaults Storage Implementation

## Overview

This document describes the optimized UserDefaults storage system implemented to improve performance, reduce memory usage, and prevent unlimited data growth in Habitto.

## Problem Statement

The original storage system had several limitations:

1. **Single Array Storage**: All habits were stored as one large array in UserDefaults
2. **Full Reload**: Every save operation required loading and saving the entire habits array
3. **Unlimited Growth**: Completion history, difficulty history, and usage data could grow indefinitely
4. **Memory Inefficiency**: Large arrays caused memory pressure and slow operations
5. **Poor Performance**: Frequent full array operations as the number of habits increased

## Solution: Individual Habit Storage

### Architecture

The new `OptimizedHabitStorageManager` implements:

1. **Individual Storage**: Each habit is stored separately with a unique key (`habit_{UUID}`)
2. **History Capping**: Automatic capping of completion, difficulty, and usage history to 365 days
3. **Efficient Caching**: Smart caching system to avoid redundant UserDefaults reads
4. **Migration Support**: Seamless migration from old array-based storage
5. **Performance Monitoring**: Built-in statistics and cleanup utilities

### Storage Structure

```
UserDefaults Keys:
├── habit_ids: [UUID]                    # List of all habit IDs
├── habit_{uuid1}: Habit                 # Individual habit data
├── habit_{uuid2}: Habit                 # Individual habit data
└── ...                                  # More individual habits
```

### Key Features

#### 1. Individual Habit Storage
```swift
// Each habit stored separately
let key = "habit_\(habit.id.uuidString)"
userDefaults.set(encodedHabit, forKey: key)
```

#### 2. History Capping
```swift
// Automatically cap history to 365 days
private let maxHistoryDays = 365

// Cap completion history
if habit.completionHistory.count > maxHistoryDays {
    let sortedKeys = habit.completionHistory.keys.sorted(by: >)
    let keysToRemove = Array(sortedKeys.dropFirst(maxHistoryDays))
    // Remove old entries...
}
```

#### 3. Smart Caching
```swift
// Cache loaded habits to avoid repeated UserDefaults reads
private var cachedHabits: [UUID: Habit] = [:]

// Only load from UserDefaults if not cached
if let cached = cachedHabits[id] {
    return cached
}
```

#### 4. Debounced Saves
```swift
// Prevent excessive saves with debouncing
private let saveDebounceInterval: TimeInterval = 0.5

// Allow immediate saves when needed
if immediate {
    performSave(habits)
    return
}
```

## Performance Benefits

### Before (Array Storage)
- **Load Time**: O(n) - Load entire array every time
- **Save Time**: O(n) - Save entire array every time
- **Memory Usage**: O(n) - Keep entire array in memory
- **Storage Growth**: Unlimited - No history capping

### After (Individual Storage)
- **Load Time**: O(1) - Load only needed habits
- **Save Time**: O(1) - Save only changed habits
- **Memory Usage**: O(1) - Cache only loaded habits
- **Storage Growth**: Capped - 365 days max history

## Migration Strategy

### Automatic Migration
The system automatically detects and migrates from old storage:

```swift
var needsMigration: Bool {
    return userDefaults.data(forKey: "SavedHabits") != nil && 
           userDefaults.data(forKey: habitIdsKey) == nil
}

func migrateIfNeeded() {
    if needsMigration {
        migrateFromArrayStorage()
    }
}
```

### Migration Process
1. **Detect Old Storage**: Check for existing `SavedHabits` key
2. **Load Old Data**: Decode the old habits array
3. **Save Individually**: Store each habit with individual keys
4. **Update Index**: Create new `habit_ids` list
5. **Clean Up**: Remove old array storage

## API Changes

### HabitRepository Updates
```swift
// Old
let loadedHabits = HabitStorageManager.shared.loadHabits()

// New
OptimizedHabitStorageManager.shared.migrateIfNeeded()
let loadedHabits = OptimizedHabitStorageManager.shared.loadHabits()
```

### Habit Model Updates
```swift
// Old
Habit.saveHabits(habits, immediate: true)

// New
OptimizedHabitStorageManager.shared.saveHabits(habits, immediate: true)
```

## Storage Statistics

### Monitoring
```swift
func getStorageStats() -> (totalHabits: Int, totalKeys: Int, cacheSize: Int) {
    // Returns current storage statistics
}
```

### Cleanup
```swift
func cleanupOrphanedEntries() {
    // Removes orphaned habit entries
}
```

## Configuration

### History Capping
```swift
private let maxHistoryDays = 365 // Configurable limit
```

### Save Debouncing
```swift
private let saveDebounceInterval: TimeInterval = 0.5 // 500ms debounce
```

## Benefits

### Performance
- **Faster Loads**: Only load needed habits
- **Faster Saves**: Only save changed habits
- **Reduced Memory**: Cache only active habits
- **Better Responsiveness**: Debounced saves prevent UI blocking

### Storage Efficiency
- **Controlled Growth**: History automatically capped
- **Individual Access**: Load/save specific habits
- **Cleanup Support**: Remove orphaned entries
- **Migration Safe**: Seamless upgrade from old system

### Developer Experience
- **Backward Compatible**: Works with existing code
- **Automatic Migration**: No manual intervention needed
- **Performance Monitoring**: Built-in statistics
- **Clean API**: Simple interface for common operations

## Usage Examples

### Basic Operations
```swift
// Load all habits
let habits = OptimizedHabitStorageManager.shared.loadHabits()

// Load specific habit
let habit = OptimizedHabitStorageManager.shared.loadHabit(by: habitId)

// Save habits
OptimizedHabitStorageManager.shared.saveHabits(habits)

// Save single habit
OptimizedHabitStorageManager.shared.saveHabit(habit)

// Delete habit
OptimizedHabitStorageManager.shared.deleteHabit(by: habitId)
```

### Migration
```swift
// Automatic migration on first load
OptimizedHabitStorageManager.shared.migrateIfNeeded()
```

### Monitoring
```swift
// Get storage statistics
let stats = OptimizedHabitStorageManager.shared.getStorageStats()
print("Total habits: \(stats.totalHabits)")
print("Total keys: \(stats.totalKeys)")
print("Cache size: \(stats.cacheSize)")

// Cleanup orphaned entries
OptimizedHabitStorageManager.shared.cleanupOrphanedEntries()
```

## Future Enhancements

### Potential Improvements
1. **Compression**: Compress habit data before storage
2. **Background Sync**: Save changes in background queue
3. **Incremental Updates**: Track and save only changed fields
4. **Storage Quotas**: Monitor and enforce storage limits
5. **Data Archiving**: Archive old data to separate storage

### CloudKit Integration
The individual storage system is designed to work well with future CloudKit integration:
- Each habit can be synced individually
- History capping reduces sync payload
- Individual records are easier to manage in CloudKit

## Conclusion

The optimized storage system provides significant performance improvements while maintaining backward compatibility and adding essential features like history capping. The individual storage approach scales better and provides a foundation for future enhancements like CloudKit sync.

---

**Key Benefits:**
- ✅ **Performance**: Faster loads and saves
- ✅ **Memory**: Reduced memory usage
- ✅ **Storage**: Controlled data growth
- ✅ **Migration**: Seamless upgrade path
- ✅ **Monitoring**: Built-in statistics and cleanup
