# Migration Plan - Phase 3 Implementation

## Overview

This document outlines the migration strategy from legacy storage (UserDefaults + SwiftData dual storage) to normalized SwiftData-only storage with proper user isolation.

## Migration Strategy

### 1. Feature-Flagged Rollout

- **Phase 3A**: Feature flags disabled (legacy path)
- **Phase 3B**: Feature flags enabled for testing (normalized path)
- **Phase 3C**: Feature flags enabled for all users (normalized path)
- **Phase 3D**: Remove legacy code (cleanup)

### 2. Idempotent Migration

- Migration can be run multiple times safely
- Tracks migration state per user
- Handles partial failures gracefully
- Supports rollback if needed

## Migration Steps

### Step 1: Detect Legacy Data

```swift
// Check for UserDefaults business data
let possibleKeys = ["SavedHabits", "user_progress", "recent_xp_transactions", "daily_xp_awards"]

// Check for denormalized fields in existing SwiftData
let denormalizedHabits = habits.filter { $0.isCompleted || $0.streak > 0 }
```

### Step 2: Migrate Habits

```swift
// Convert Habit structs to HabitData with userId
for habit in legacyHabits {
    let habitData = HabitData(
        id: habit.id,
        userId: userId,
        name: habit.name,
        // ... other fields
        isCompleted: habit.isCompleted, // Marked as deprecated
        streak: habit.streak // Marked as deprecated
    )
    context.insert(habitData)
}
```

### Step 3: Migrate Completion Records

```swift
// Convert completion history dictionaries to CompletionRecord models
for (dateString, completionCount) in habit.completionHistory {
    let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString)
    let dateKey = DateKey.key(for: date)
    
    let completionRecord = CompletionRecord(
        userId: userId,
        habitId: habit.id,
        date: date,
        dateKey: dateKey,
        isCompleted: completionCount > 0
    )
    context.insert(completionRecord)
}
```

### Step 4: Migrate Daily Awards

```swift
// Create DailyAward records for historical XP
if legacyProgress.xpTotal > 0 {
    let dailyAward = DailyAward(
        userId: userId,
        dateKey: todayDateKey,
        xpGranted: legacyProgress.xpTotal,
        allHabitsCompleted: true
    )
    context.insert(dailyAward)
}
```

### Step 5: Migrate User Progress

```swift
// Create UserProgress with migrated data
let userProgress = UserProgress(
    userId: userId,
    xpTotal: legacyProgress.xpTotal,
    level: legacyProgress.level,
    levelProgress: legacyProgress.levelProgress,
    lastCompletedDate: legacyProgress.lastCompletedDate
)
context.insert(userProgress)
```

## Migration State Tracking

### MigrationState Model

```swift
@Model
final class MigrationState {
    @Attribute(.indexed) var userId: String
    var migrationVersion: Int
    var status: MigrationStatus // .pending, .inProgress, .completed, .failed
    var startedAt: Date
    var completedAt: Date?
    var errorMessage: String?
    var migratedRecordsCount: Int
}
```

### Migration Versions

- **Version 1**: Initial normalization migration
- **Version 2**: User scoping migration (future)
- **Version 3**: Container separation migration (future)

## Error Handling

### Partial Failure Recovery

```swift
do {
    try await runMigration(userId: userId, context: context, state: migrationState)
} catch {
    // Mark migration as failed
    migrationState.markFailed(error: error)
    try context.save()
    
    // Log error for debugging
    logger.error("Migration failed for user \(userId): \(error.localizedDescription)")
    
    // Continue with legacy path
    throw error
}
```

### Rollback Strategy

```swift
// If migration fails, continue using legacy storage
if migrationState.hasFailed {
    logger.warning("Migration failed, using legacy storage for user \(userId)")
    return legacyRepositoryProvider
}
```

## Testing Strategy

### Unit Tests

1. **Migration Idempotency**: Run migration twice, verify no duplicate data
2. **Migration Parity**: Verify migrated data matches legacy data
3. **Error Handling**: Test migration failure scenarios
4. **Rollback**: Test rollback functionality

### Integration Tests

1. **Guest/Account Isolation**: Verify no data leakage between users
2. **Feature Flag Toggle**: Test switching between legacy and normalized paths
3. **Auth State Changes**: Test repository switching on sign-in/sign-out
4. **XP Service**: Test XP awarding in both legacy and normalized modes

### Performance Tests

1. **Migration Speed**: Measure migration time for large datasets
2. **Memory Usage**: Monitor memory usage during migration
3. **Database Size**: Compare storage size before/after migration

## Rollback Plan

### Automatic Rollback

- Migration failure → Continue with legacy storage
- Feature flag disabled → Switch to legacy repositories
- Data corruption detected → Rollback to last known good state

### Manual Rollback

```swift
// Disable feature flags
FeatureFlags.useNormalizedDataPath = false
FeatureFlags.useCentralizedXP = false

// Clear normalized data (if needed)
try await clearNormalizedData(userId: userId)

// Continue with legacy storage
```

## Monitoring and Metrics

### Migration Metrics

- **Success Rate**: Percentage of successful migrations
- **Migration Time**: Average time per user migration
- **Error Rate**: Percentage of failed migrations
- **Rollback Rate**: Percentage of rollbacks

### Data Quality Metrics

- **Data Parity**: Verify migrated data matches legacy data
- **User Isolation**: Verify no data leakage between users
- **XP Consistency**: Verify XP calculations are correct

## Deployment Plan

### Phase 3A: Foundation (Current)

- ✅ Feature flags implemented
- ✅ Migration infrastructure created
- ✅ Repository provider implemented
- ✅ Tests written

### Phase 3B: Testing

- [ ] Enable feature flags for test users
- [ ] Run migration on test data
- [ ] Verify data parity
- [ ] Test rollback scenarios

### Phase 3C: Gradual Rollout

- [ ] Enable feature flags for 10% of users
- [ ] Monitor migration success rate
- [ ] Enable feature flags for 50% of users
- [ ] Enable feature flags for all users

### Phase 3D: Cleanup

- [ ] Remove legacy code
- [ ] Remove UserDefaults business data storage
- [ ] Remove dual storage paths
- [ ] Update documentation

## Risk Mitigation

### Data Loss Prevention

- **Backup**: Create backup before migration
- **Validation**: Verify data parity after migration
- **Rollback**: Keep legacy code until migration is stable

### Performance Impact

- **Async Migration**: Run migration in background
- **Batch Processing**: Process large datasets in batches
- **Progress Tracking**: Show migration progress to user

### User Experience

- **Transparent**: Migration should be invisible to user
- **Fast**: Migration should complete quickly
- **Reliable**: Migration should never fail silently

## Success Criteria

### Functional Requirements

- [ ] All legacy data migrated successfully
- [ ] No data loss during migration
- [ ] User isolation working correctly
- [ ] XP calculations accurate
- [ ] Performance maintained or improved

### Non-Functional Requirements

- [ ] Migration completes within 30 seconds
- [ ] No user-visible errors during migration
- [ ] Rollback available if needed
- [ ] Comprehensive test coverage
- [ ] Documentation updated

## Timeline

- **Week 1**: Phase 3A completion (foundation)
- **Week 2**: Phase 3B testing and validation
- **Week 3**: Phase 3C gradual rollout
- **Week 4**: Phase 3D cleanup and documentation

## Conclusion

This migration plan provides a safe, tested, and monitored approach to moving from legacy storage to normalized SwiftData storage. The feature-flagged rollout ensures we can quickly rollback if issues arise, while the comprehensive testing ensures data integrity throughout the process.
