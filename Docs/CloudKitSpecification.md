# CloudKit Integration Specification

## Overview
This document outlines the CloudKit integration strategy for Habitto, including record models, conflict resolution, account scoping, and sync behavior.

## Record Model

### HabitRecord
```swift
struct CloudKitHabitRecord {
    let recordName: String // Habit UUID (deterministic)
    let recordType: String = "Habit"
    
    // Core habit data
    let name: String
    let description: String
    let habitType: String // "formation" or "breaking"
    let schedule: String // "daily", "weekly", etc.
    let goal: String
    let reminder: String
    let startDate: Date
    let endDate: Date?
    
    // Completion history (compressed JSON)
    let completionHistory: Data // JSON compressed with gzip
    
    // Versioning
    let dataVersion: String // Schema version
    let migrationVersion: String
    
    // Sync metadata
    let lastModified: Date
    let syncStatus: String // "synced", "pending", "conflict"
    let deviceId: String // For conflict resolution
}
```

### CompletionEventRecord
```swift
struct CloudKitCompletionEventRecord {
    let recordName: String // "habitId_date" (deterministic)
    let recordType: String = "CompletionEvent"
    
    let habitId: String // Reference to HabitRecord
    let date: Date
    let completionCount: Int
    let difficulty: Int? // Optional difficulty rating
    let notes: String? // Optional completion notes
    
    // Sync metadata
    let lastModified: Date
    let deviceId: String
}
```

## Account Scoping Strategy

### Private Database + Custom Zone
- **Database**: `CKContainer.default().privateCloudDatabase`
- **Zone**: `CKRecordZone(zoneName: "HabittoHabitsZone")`
- **Scoping**: Private DB automatically scopes to Apple ID - no userId field needed
- **Benefits**: 
  - Automatic user isolation
  - No custom user management required
  - Leverages Apple's security model

### Zone Configuration
```swift
let userZone = CKRecordZone(zoneName: "HabittoHabitsZone")

// Zone setup (one-time)
func setupCloudKitZone() async throws {
    try await privateDB.save(userZone)
}
```

## Conflict Resolution

### Current Strategy: Last Writer Wins (LWW)
```swift
func resolveConflict(local: CloudKitHabitRecord, remote: CloudKitHabitRecord) -> CloudKitHabitRecord {
    // Simple LWW: newer timestamp wins
    if local.lastModified > remote.lastModified {
        return local
    } else {
        return remote
    }
}
```

### Future Strategy: Field-Level Merge
```swift
func mergeCompletionHistory(local: [String: Int], remote: [String: Int]) -> [String: Int] {
    var merged = local
    for (date, count) in remote {
        merged[date] = max(merged[date] ?? 0, count)
    }
    return merged
}

func mergeHabitMetadata(local: Habit, remote: Habit) -> Habit {
    // Merge non-conflicting fields
    var merged = local
    merged.description = remote.description // Remote description wins
    merged.goal = max(local.goal, remote.goal) // Higher goal wins
    return merged
}
```

## Seeding Strategy for Existing Installs

### One-Time Seeding Process
```swift
func seedExistingHabitsToCloudKit() async throws {
    let habits = await habitStore.loadHabits()
    let batchSize = 100 // CloudKit batch limit
    
    for batch in habits.chunked(into: batchSize) {
        let records = batch.map { habit in
            createCloudKitRecord(from: habit)
        }
        
        try await privateDB.modifyRecords(saving: records, deleting: [])
    }
}
```

### Deduplication Strategy
```swift
func deduplicateHabits() async throws {
    // Query all habits with same name
    let predicate = NSPredicate(format: "name == %@", habitName)
    let query = CKQuery(recordType: "Habit", predicate: predicate)
    
    let results = try await privateDB.records(matching: query)
    
    // Keep newest, delete duplicates
    let sortedByDate = results.records.sorted { $0.lastModified > $1.lastModified }
    let duplicates = Array(sortedByDate.dropFirst())
    
    if !duplicates.isEmpty {
        try await privateDB.modifyRecords(saving: [], deleting: duplicates.map { $0.recordID })
    }
}
```

## Write Batching and Retry Policy

### Batch Configuration
```swift
struct CloudKitSyncConfig {
    static let batchSize = 100 // CK max records per batch
    static let maxRetries = 3
    static let baseRetryDelay: TimeInterval = 1.0
    static let maxRetryDelay: TimeInterval = 30.0
}
```

### Retry with Exponential Backoff
```swift
func syncWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
    var attempt = 0
    var delay: TimeInterval = CloudKitSyncConfig.baseRetryDelay
    
    while attempt < CloudKitSyncConfig.maxRetries {
        do {
            return try await operation()
        } catch let error as CKError {
            if error.isRetryable {
                attempt += 1
                if attempt < CloudKitSyncConfig.maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay = min(delay * 2, CloudKitSyncConfig.maxRetryDelay)
                    continue
                }
            }
            throw error
        }
    }
    
    throw CloudKitError.maxRetriesExceeded
}

extension CKError {
    var isRetryable: Bool {
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable:
            return true
        default:
            return false
        }
    }
}
```

## Offline → Online Sync Behavior

### Conflict Detection
```swift
func detectConflicts(local: [Habit], remote: [CloudKitHabitRecord]) -> [Conflict] {
    var conflicts: [Conflict] = []
    
    for localHabit in local {
        if let remoteRecord = remote.first(where: { $0.recordName == localHabit.id.uuidString }) {
            if localHabit.lastModified != remoteRecord.lastModified {
                conflicts.append(Conflict(
                    habitId: localHabit.id,
                    local: localHabit,
                    remote: remoteRecord
                ))
            }
        }
    }
    
    return conflicts
}
```

### Offline Queue Management
```swift
actor OfflineSyncQueue {
    private var pendingOperations: [SyncOperation] = []
    
    func enqueueOperation(_ operation: SyncOperation) {
        pendingOperations.append(operation)
        saveQueueToDisk()
    }
    
    func processOfflineQueue() async throws {
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            try await executeOperation(operation)
        }
    }
}
```

## Sign-Out/Switch Account Behavior

### Account Switch Process
```swift
func handleAccountSwitch(from oldUserId: String, to newUserId: String) async {
    // 1. Save current state locally
    try await habitStore.saveHabits(currentHabits)
    
    // 2. Clear CloudKit cache for old user
    await cloudKitManager.clearCache(for: oldUserId)
    
    // 3. Switch to new user's zone
    let newZone = CKRecordZone(zoneName: "HabittoHabitsZone")
    await cloudKitManager.switchToZone(newZone)
    
    // 4. Load new user's habits from local storage
    await habitStore.loadHabits() // Loads from new user's file
    
    // 5. Sync with new account's CloudKit
    try await cloudKitManager.syncWithCloudKit()
}
```

## GDPR Delete Propagation

### Deletion Tombstones
```swift
struct DeletionTombstone {
    let recordName: String // "tombstone_habitId"
    let recordType: String = "DeletionTombstone"
    let habitId: String
    let deletedAt: Date
    let ttl: Date // 30 days TTL
    let reason: String // "user_request", "gdpr", etc.
    let deviceId: String
}

func createDeletionTombstone(habitId: String) -> DeletionTombstone {
    return DeletionTombstone(
        recordName: "tombstone_\(habitId)",
        habitId: habitId,
        deletedAt: Date(),
        ttl: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        reason: "gdpr_request",
        deviceId: getDeviceId()
    )
}
```

### Resurrection Prevention
```swift
func preventDataResurrection() async throws {
    // 1. Create tombstones for deleted habits
    let deletedHabits = await getDeletedHabits()
    let tombstones = deletedHabits.map { createDeletionTombstone(habitId: $0.id.uuidString) }
    
    try await privateDB.modifyRecords(saving: tombstones, deleting: [])
    
    // 2. Verify no data resurrection
    try await verifyNoDataResurrection()
}

func verifyNoDataResurrection() async throws {
    let tombstones = try await queryTombstones()
    let activeHabits = try await queryActiveHabits()
    
    for tombstone in tombstones {
        if activeHabits.contains(where: { $0.recordName == tombstone.habitId }) {
            throw CloudKitError.dataResurrectionDetected(habitId: tombstone.habitId)
        }
    }
}
```

## Performance Optimizations

### Incremental Sync
```swift
func incrementalSync(lastSyncDate: Date) async throws {
    let predicate = NSPredicate(format: "lastModified > %@", lastSyncDate as NSDate)
    let query = CKQuery(recordType: "Habit", predicate: predicate)
    
    let results = try await privateDB.records(matching: query)
    // Process only changed records
}
```

### Compression for Large Data
```swift
func compressCompletionHistory(_ history: [String: Int]) -> Data {
    let jsonData = try! JSONEncoder().encode(history)
    return try! (jsonData as NSData).compressed(using: .gzip)
}

func decompressCompletionHistory(_ data: Data) -> [String: Int] {
    let decompressedData = try! (data as NSData).decompressed(using: .gzip)
    return try! JSONDecoder().decode([String: Int].self, from: decompressedData as Data)
}
```

## Error Handling

### CloudKit Error Categories
```swift
enum CloudKitError: LocalizedError {
    case networkUnavailable
    case quotaExceeded
    case recordNotFound
    case conflictDetected
    case dataResurrectionDetected(habitId: String)
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network unavailable. Changes will sync when connection is restored."
        case .quotaExceeded:
            return "CloudKit quota exceeded. Please contact support."
        case .recordNotFound:
            return "Record not found. This may indicate a sync issue."
        case .conflictDetected:
            return "Data conflict detected. Using most recent version."
        case .dataResurrectionDetected(let habitId):
            return "Data resurrection detected for habit \(habitId). This is a security violation."
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded. Please try again later."
        }
    }
}
```

## Testing Strategy

### CloudKit Testing
```swift
func testCloudKitSync() async throws {
    // 1. Create test habits
    let testHabits = createTestHabits()
    
    // 2. Seed to CloudKit
    try await seedHabitsToCloudKit(testHabits)
    
    // 3. Verify sync
    let syncedHabits = try await fetchHabitsFromCloudKit()
    assert(syncedHabits.count == testHabits.count)
    
    // 4. Test conflict resolution
    let conflictResult = try await testConflictResolution()
    assert(conflictResult.resolved)
}
```

## Migration Path

### Phase 1: Basic Sync (MVP)
- LWW conflict resolution
- Simple batch uploads
- Basic offline queue

### Phase 2: Advanced Sync
- Field-level merge
- Incremental sync
- Advanced conflict resolution

### Phase 3: Multi-Device Optimization
- Real-time sync
- Conflict-free replicated data types (CRDTs)
- Advanced compression

## Security Considerations

### Data Protection
- All data encrypted in transit (HTTPS)
- All data encrypted at rest (CloudKit handles this)
- Private database provides user isolation
- Custom zone adds additional isolation layer

### Privacy
- No personally identifiable information in record names
- Habit names/descriptions are user-controlled content
- Completion history is anonymized (no personal data)
- GDPR compliance through tombstone system

## Monitoring and Telemetry

### Sync Metrics
```swift
struct CloudKitSyncMetrics {
    let syncStartTime: Date
    let syncEndTime: Date
    let recordsProcessed: Int
    let conflictsResolved: Int
    let errorsEncountered: Int
    let networkCalls: Int
    let dataTransferred: Int64
}
```

### Error Tracking
```swift
func trackCloudKitError(_ error: Error, context: String) {
    let errorInfo = [
        "error": error.localizedDescription,
        "context": context,
        "timestamp": Date().iso8601String,
        "deviceId": getDeviceId()
    ]
    
    // Send to telemetry system
    telemetryManager.recordEvent(.cloudKitError, metadata: errorInfo)
}
```

This specification provides a comprehensive foundation for CloudKit integration that can be implemented incrementally, starting with basic sync and evolving to advanced features as needed.