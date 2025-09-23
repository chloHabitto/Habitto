# CloudKit Integration Specification

## Overview
This document outlines the CloudKit integration strategy for Habitto's habit tracking system, designed for v2.0 release.

## Architecture

### Database Configuration
- **Database**: Private Database (user-specific data)
- **Zone**: Custom Zone (`HabittoHabitsZone`) - constant name, no user PII
- **Record Name**: Habit UUID (deterministic, globally unique)
- **Isolation**: Private DB already scopes to iCloud account, no additional userId field needed

### Record Model

```swift
struct CloudKitHabitRecord {
    // Primary Key
    let recordName: String // UUID string (habit.id.uuidString)
    
    // Core Habit Data
    let habitName: String
    let description: String
    let icon: String
    let color: Data // Serialized Color
    let habitType: String // "formation" or "breaking"
    let schedule: String // "daily", "weekly", etc.
    let goal: String
    let reminder: String
    
    // Dates
    let startDate: Date
    let endDate: Date?
    let createdAt: Date
    let lastModified: Date
    
    // Status
    let isCompleted: Bool
    let streak: Int
    
    // Versioning
    let dataVersion: String // "1.0.0", "2.0.0", etc.
    let migrationVersion: String // For sync compatibility
    
    // No userId field needed - Private DB + custom zone provides isolation
    
    // Metadata
    let recordType: String = "Habit"
    let syncStatus: String // "synced", "pending", "conflict"
    let lastSyncDate: Date?
}
```

## Conflict Resolution Strategy

### Primary Strategy: Last Writer Wins (LWW)
- **Field**: `lastModified` timestamp determines winner
- **Use Case**: Most habit data (name, description, icon, etc.)
- **Implementation**: Compare timestamps, keep newer record

### Secondary Strategy: Field-Level Merge
- **Fields**: Counters, histories, completion data
- **Use Case**: `completionHistory`, `difficultyHistory`, `actualUsage`
- **Implementation**: Merge dictionaries, preserve all data

```swift
// Example field-level merge for completion history
func mergeCompletionHistory(_ local: [String: Int], _ remote: [String: Int]) -> [String: Int] {
    var merged = local
    for (date, count) in remote {
        merged[date] = max(merged[date] ?? 0, count) // Keep higher count
    }
    return merged
}
```

### Tertiary Strategy: User Prompt
- **Use Case**: Conflicting changes to critical fields (habit name, type)
- **Implementation**: Present conflict resolution UI to user

## Account Scoping

### User Identification
- **Primary**: Apple ID (when available)
- **Fallback**: Custom user identifier for non-Apple users
- **Scope**: Private DB automatically scopes to iCloud account, custom zone provides additional isolation

### Multi-Account Support
- **Separate Zones**: Each user account gets its own zone
- **Clean Separation**: No data mixing between accounts
- **Account Switching**: Seamless transition between accounts

## GDPR Data Deletion

### Complete Data Deletion Sequence
1. **Local Deletion**: Remove all local habit data from CrashSafeHabitStore
2. **CloudKit Deletion**: Delete all records from private zone
3. **Tombstone Creation**: Create deletion tombstones to prevent re-sync
4. **Telemetry Cleanup**: Record "forget" event and purge user telemetry
5. **Verification**: Confirm no data resurrection on offline device return

### Implementation
```swift
func deleteUserData(userId: String) async throws {
    // 1. Local deletion
    try await habitStore.deleteAllHabits()
    
    // 2. CloudKit deletion
    let records = try await fetchAllRecords(in: userZone)
    try await deleteRecords(records)
    
    // 3. Create tombstones
    let tombstone = createDeletionTombstone(userId: userId)
    try await saveTombstone(tombstone)
    
    // 4. Telemetry cleanup
    await telemetryManager.recordForgetEvent(userId: userId)
    
    // 5. Verification test
    try await verifyNoDataResurrection(userId: userId)
}
```

### Offline Device Protection
- **Tombstone Mechanism**: Prevents offline devices from re-syncing deleted data
- **Zone Cleanup**: Entire zone deletion ensures no orphaned records
- **Resurrection Test**: Automated test to verify no data reappears

## Offline/Online Behavior

### Offline Mode
- **Local Storage**: All operations continue locally
- **Queue**: Changes queued for sync when online
- **Status**: Records marked as `syncStatus: "pending"`

### Online Sync
- **Incremental**: Only changed records since last sync
- **Batch Processing**: Process changes in batches of 100
- **Conflict Detection**: Compare `lastModified` timestamps
- **Retry Logic**: Exponential backoff for failed syncs

### Backfill Strategy
```swift
func performBackfill() async throws {
    // 1. Fetch all remote records modified since last sync
    let lastSyncDate = getLastSyncDate()
    let remoteRecords = try await fetchRecordsModifiedSince(lastSyncDate)
    
    // 2. Compare with local records
    for remoteRecord in remoteRecords {
        if let localRecord = findLocalRecord(remoteRecord.recordName) {
            // Handle conflict resolution
            let resolvedRecord = resolveConflict(localRecord, remoteRecord)
            try await saveLocalRecord(resolvedRecord)
        } else {
            // New remote record, add locally
            try await saveLocalRecord(remoteRecord.toLocalHabit())
        }
    }
    
    // 3. Upload pending local changes
    let pendingRecords = getPendingLocalRecords()
    try await uploadRecords(pendingRecords)
    
    // 4. Update last sync timestamp
    updateLastSyncDate()
}
```

## One-Time Seeding & Deduplication

### Existing User Migration
```swift
func enableCloudKitSync() async throws {
    // 1. Create custom zone if it doesn't exist
    try await createCustomZone()
    
    // 2. Seed existing habits to CloudKit
    let localHabits = await loadLocalHabits()
    let cloudKitRecords = localHabits.map { $0.toCloudKitRecord() }
    try await uploadRecords(cloudKitRecords)
    
    // 3. Enable sync monitoring
    startSyncMonitoring()
    
    // 4. Mark migration as complete
    markCloudKitMigrationComplete()
}
```

### Deduplication Strategy
- **Primary Key**: Use habit UUID as record name
- **Collision Detection**: Check for existing records before upload
- **Resolution**: Merge or prompt user for resolution

## Performance Considerations

### Batch Operations
- **Upload Batch Size**: 100 records per batch
- **Download Batch Size**: 200 records per batch
- **Rate Limiting**: Respect CloudKit quotas

### Caching Strategy
- **Local Cache**: Store frequently accessed records locally
- **TTL**: Cache expires after 1 hour
- **Invalidation**: Clear cache on account switch

### Error Handling
- **Network Errors**: Retry with exponential backoff
- **Quota Exceeded**: Queue operations for later
- **Authentication Errors**: Prompt user to re-authenticate

## Security & Privacy

### Data Encryption
- **In Transit**: HTTPS/TLS (CloudKit default)
- **At Rest**: CloudKit encryption (Apple's infrastructure)
- **Field-Level**: Sensitive fields encrypted locally before sync

### Access Control
- **Private Database**: User can only access their own data
- **Record-Level**: All records scoped to user ID
- **API Keys**: No API keys required (uses Apple ID)

### GDPR Compliance
- **Data Export**: Full data export capability
- **Data Deletion**: Complete data removal from CloudKit
- **Audit Trail**: Log all data operations

## Monitoring & Telemetry

### Sync Metrics
- **Success Rate**: Percentage of successful sync operations
- **Latency**: Time to complete sync operations
- **Conflict Rate**: Frequency of conflict resolution
- **Error Rate**: Failed sync operations

### Health Checks
- **Connectivity**: Test CloudKit availability
- **Authentication**: Verify user authentication status
- **Quota Usage**: Monitor API quota consumption

## Implementation Timeline

### Phase 1: Core Infrastructure (v2.0.0)
- [ ] CloudKit record model
- [ ] Basic sync operations
- [ ] Conflict resolution (LWW)
- [ ] Account scoping

### Phase 2: Advanced Features (v2.1.0)
- [ ] Field-level merge
- [ ] Offline queue
- [ ] Batch operations
- [ ] Performance optimization

### Phase 3: Production Hardening (v2.2.0)
- [ ] Comprehensive error handling
- [ ] Monitoring & telemetry
- [ ] GDPR compliance
- [ ] Performance testing

## Testing Strategy

### Unit Tests
- Record serialization/deserialization
- Conflict resolution logic
- Account scoping
- Batch operations

### Integration Tests
- CloudKit connectivity
- Sync operations
- Offline/online transitions
- Multi-device scenarios

### Stress Tests
- Large dataset sync (10k+ records)
- Network interruption scenarios
- Concurrent access patterns
- Quota limit testing

## Migration Path

### From Local-Only to CloudKit
1. **Backup**: Create full local backup
2. **Enable**: Turn on CloudKit sync
3. **Seed**: Upload existing habits
4. **Verify**: Confirm data integrity
5. **Monitor**: Track sync performance

### Rollback Plan
- **Disable Sync**: Turn off CloudKit integration
- **Restore**: Restore from local backup
- **Continue**: Resume local-only operation
- **Debug**: Investigate sync issues

## Success Metrics

### Technical Metrics
- **Sync Success Rate**: >99.5%
- **Sync Latency**: <2 seconds average
- **Conflict Rate**: <1% of operations
- **Error Rate**: <0.1% of operations

### User Experience Metrics
- **Data Consistency**: 100% across devices
- **Offline Capability**: Full functionality
- **Sync Transparency**: No user intervention required
- **Performance Impact**: <5% app startup time increase

---

*This specification is a living document and will be updated as the implementation progresses.*
