# Core Data + CloudKit Implementation for Habitto

## Overview

This document outlines the Core Data + CloudKit implementation for Habitto, providing a robust, scalable database solution with automatic sync across devices.

## Architecture

### 1. Core Data Stack
- **CoreDataManager**: Manages the Core Data stack and provides CRUD operations
- **HabitRepository**: Manages habit data and provides CRUD operations
- **CloudKitManager**: Handles CloudKit sync and user authentication

### 2. Data Model

#### Entities:
- **HabitEntity**: Main habit data
- **CompletionRecordEntity**: Daily completion tracking
- **UsageRecordEntity**: Habit breaking usage tracking
- **NoteEntity**: Future notes feature
- **DifficultyLogEntity**: Future difficulty tracking
- **MoodLogEntity**: Future mood tracking
- **ReminderItemEntity**: Reminder management

#### Relationships:
```
HabitEntity
├── completionHistory: [CompletionRecordEntity] (one-to-many)
├── usageRecords: [UsageRecordEntity] (one-to-many)
├── notes: [NoteEntity] (one-to-many)
├── difficultyLogs: [DifficultyLogEntity] (one-to-many)
├── moodLogs: [MoodLogEntity] (one-to-many)
└── reminders: [ReminderItemEntity] (one-to-many)
```

## Implementation Details

### 1. Core Data Manager (`CoreDataManager.swift`)

**Key Features:**
- Singleton pattern for global access
- Background context for heavy operations
- Automatic CloudKit integration
- Migration from UserDefaults
- Performance optimizations

**Usage:**
```swift
let coreDataManager = CoreDataManager.shared

// Create a habit
let habitEntity = coreDataManager.createHabit(from: habit)

// Fetch habits
let habits = coreDataManager.fetchHabits()

// Update habit
coreDataManager.updateHabit(habitEntity, with: updatedHabit)

// Delete habit
coreDataManager.deleteHabit(habitEntity)
```

### 2. Habit Repository (`HabitRepository.swift`)

**Purpose:** Provides a clean interface between existing code and Core Data

**Key Features:**
- Automatic conversion between `Habit` structs and `HabitEntity`
- Published properties for SwiftUI integration
- Seamless migration from UserDefaults
- Background processing for performance

**Usage:**
```swift
let repository = HabitRepository.shared

// Subscribe to changes
repository.$habits
    .receive(on: DispatchQueue.main)
    .assign(to: &$habits)

// CRUD operations
repository.createHabit(habit)
repository.updateHabit(habit)
repository.deleteHabit(habit)
repository.toggleHabitCompletion(habit, for: date)
```

### 3. CloudKit Manager (`CloudKitManager.swift`)

**Key Features:**
- Automatic sync across devices
- User authentication
- Error handling
- Real-time updates
- Custom record operations

**Usage:**
```swift
let cloudKitManager = CloudKitManager.shared

// Check authentication
cloudKitManager.checkAuthenticationStatus()

// Manual sync
cloudKitManager.sync()

// Custom operations
cloudKitManager.saveCustomRecord(record) { result in
    // Handle result
}
```

## Migration Strategy

### Phase 1: Core Data Implementation ✅
- [x] Core Data model creation
- [x] Core Data manager implementation
- [x] Adapter layer for seamless transition
- [x] Migration from UserDefaults
- [x] Integration with existing views

### Phase 2: CloudKit Integration 🔄
- [x] CloudKit manager implementation
- [x] User authentication
- [x] Basic sync operations
- [ ] Real-time sync testing
- [ ] Conflict resolution

### Phase 3: Advanced Features 📋
- [ ] Notes functionality
- [ ] Difficulty tracking
- [ ] Mood logging
- [ ] Advanced analytics
- [ ] Heatmap generation

## Setup Instructions

### 1. Xcode Project Configuration

1. **Add Core Data Model:**
   - Add `HabittoDataModel.xcdatamodeld` to your project
   - Ensure it's included in your app target

2. **Enable CloudKit:**
   - Go to your app target settings
   - Select "Signing & Capabilities"
   - Add "CloudKit" capability
   - Configure your CloudKit container ID

3. **Update Bundle Identifier:**
   - Ensure your bundle ID matches your CloudKit container
   - Update `CoreDataManager.swift` and `CloudKitManager.swift` with your container ID

### 2. Code Integration

1. **Initialize Core Data:**
   ```swift
   // In HabittoApp.swift
   @StateObject private var coreDataManager = CoreDataManager.shared
   @StateObject private var habitRepository = HabitRepository.shared
   ```

2. **Update Views:**
   ```swift
   // Replace UserDefaults calls with Core Data
   // Old: Habit.saveHabits(habits)
   // New: coreDataAdapter.saveHabits(habits)
   ```

3. **Environment Setup:**
   ```swift
   .environment(\.managedObjectContext, coreDataManager.context)
   .environmentObject(coreDataManager)
   .environmentObject(coreDataAdapter)
   ```

## Performance Optimizations

### 1. Background Processing
- Heavy operations run on background contexts
- UI updates happen on main thread
- Automatic memory management

### 2. Caching
- Core Data provides automatic caching
- Lazy loading for large datasets
- Efficient query optimization

### 3. Batch Operations
- Bulk saves for multiple operations
- Debounced saves to prevent excessive I/O
- Smart change detection

## Error Handling

### 1. Core Data Errors
```swift
do {
    try context.save()
} catch {
    print("❌ Core Data save error: \(error)")
    // Handle error appropriately
}
```

### 2. CloudKit Errors
```swift
cloudKitManager.handleCloudKitError(error)
```

### 3. Migration Errors
- Automatic rollback on migration failure
- UserDefaults backup preserved during migration
- Graceful degradation if Core Data unavailable

## Testing

### 1. Unit Tests
```swift
// Test Core Data operations
func testCreateHabit() {
    let habit = Habit(name: "Test", ...)
    let entity = coreDataManager.createHabit(from: habit)
    XCTAssertNotNil(entity)
}
```

### 2. Integration Tests
```swift
// Test migration
func testMigrationFromUserDefaults() {
    // Setup test data in UserDefaults
    coreDataAdapter.migrateFromUserDefaults()
    // Verify data in Core Data
}
```

### 3. CloudKit Tests
```swift
// Test sync operations
func testCloudKitSync() {
    cloudKitManager.sync()
    // Verify sync status
}
```

## Future Enhancements

### 1. Advanced Analytics
- Complex queries for pattern analysis
- Performance metrics
- Predictive insights

### 2. Social Features
- Shared habits
- Community challenges
- Progress sharing

### 3. AI Integration
- Smart recommendations
- Habit optimization
- Personalized insights

## Troubleshooting

### Common Issues:

1. **Migration Fails:**
   - Check UserDefaults data integrity
   - Verify Core Data model compatibility
   - Clear app data and retry

2. **CloudKit Sync Issues:**
   - Verify iCloud account status
   - Check network connectivity
   - Review CloudKit container configuration

3. **Performance Issues:**
   - Monitor Core Data operations
   - Optimize fetch requests
   - Use background contexts for heavy operations

## Support

For issues or questions:
1. Check console logs for detailed error messages
2. Verify Core Data model configuration
3. Test with minimal data set
4. Review CloudKit dashboard for sync issues

## Data Security & Privacy

### Current Implementation
- **Keychain**: Sensitive data (auth tokens, user IDs, personal info) stored in iOS Keychain
- **UserDefaults**: Non-sensitive app preferences and user content
- **Authentication**: Secure user login with Firebase
- **Privacy**: Auth via Firebase; habit data local today; future sync via CloudKit

### Security Principles
- **Secrets → Keychain**: Authentication tokens, user identifiers, personal information
- **Prefs & State → UserDefaults**: App preferences, tutorial state, non-sensitive user content
- **Structured Data → Core Data/SwiftData**: Complex relationships, future CloudKit sync

### Data Classification
| Data Type | Storage Location | Reason |
|-----------|------------------|--------|
| Auth Tokens | Keychain | High security required |
| User IDs/Emails | Keychain | Personal identifiers |
| Apple Display Names | Keychain | Personal information |
| Habit Data | UserDefaults | User content, not sensitive |
| App Preferences | UserDefaults | Non-sensitive settings |
| Progress Data | UserDefaults | User content, not sensitive |

---

**Note:** This implementation provides a solid foundation for Habitto's future growth while maintaining backward compatibility with existing features.
