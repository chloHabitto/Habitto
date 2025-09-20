# 🗄️ Habitto Data Architecture

## Overview

**Today**: Offline-first. SwiftData is the primary store for all habit data, scoped by userId (guest = ""). UI talks to a HabitRepository on the main actor; a background HabitStore actor handles validation, retention, backups, and persistence. Non-sensitive prefs live in UserDefaults; secrets (auth tokens) live in Keychain with device-only accessibility. Streaks and "completed today" are derived from day-level logs.

**Planned**: Flip on CloudKit (private DB, custom zone per user) with day-level conflict resolution; recompute denormalized fields post-merge. No UI changes required.

## Persistence (Current Implementation)

Habitto is **offline-first**. All habit data is stored in SwiftData (`@Model` entities), scoped by `userId` (guest = `""`). UI reads/writes go through a Repository on the main actor, which delegates to a background actor (`HabitStore`) for validation, retention, and persistence. UserDefaults stores non-sensitive preferences and legacy flags; Keychain stores auth secrets (Firebase/Apple/Google tokens).

**⚠️ IMPORTANT**: Denormalized fields (`isCompleted`, `streak`) are non-authoritative; recomputed from logs on merge/migration. Always use source-of-truth methods for critical operations.

### Data Flow
```
UI Layer → HabitRepository (@MainActor) → HabitStore (Actor) → SwiftDataStorage → SQLite
```

### Storage Hierarchy
1. **SwiftData** (Primary) - Habit data, relationships, user isolation
2. **UserDefaults** (Legacy/Settings) - App preferences, migration flags
3. **Keychain** (Security) - Authentication tokens, user secrets
4. **CloudKit** (PLANNED/DISABLED) - Cross-device sync infrastructure ready but disabled

## Data Models

### Primary Models (SwiftData)
```swift
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String // User isolation
    var name: String
    var schedule: Schedule // ✅ Typed enum (v2 migration)
    var habitType: HabitType // ✅ Typed enum (v2 migration)
    var themeKey: String // ✅ Design token (was colorData: Data)
    // ⚠️ DENORMALIZED FIELDS (use recompute methods):
    var isCompleted: Bool // Use isCompleted(for:) for truth
    var streak: Int // Use calculateTrueStreak() for truth
    
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
}

// ✅ V2 Migration: Typed Schedule Enum
enum Schedule: Codable, Equatable {
    case daily
    case weekly(Set<DayOfWeek>)
    case specificDays([Date])
    case custom(String) // Fallback for complex logic
}

enum HabitType: String, Codable, CaseIterable {
    case build, break, quit, start, improve, other
}
```

### Derived Fields
Streaks and "completed today" are **derived from per-day records**; they may be cached but are not authoritative. Always use:
- `habit.isCompleted(for: date)` for completion status
- `habit.calculateTrueStreak()` for streak calculation
- `habit.recomputeDenormalizedFields()` to refresh cached values

**On sync/migration, cached streak/isCompleted are invalidated and recomputed from CompletionRecord.**

## Day Boundary Handling

**"Day" is computed in the user's local timezone** with a defined cutoff. Persist UTC timestamps; render in local timezone. All date operations use `Calendar.current` for timezone-aware calculations.

### DST Considerations
- Store dates in UTC
- Calculate day boundaries in local timezone
- Test DST transitions (spring forward/fall back)
- Use `Calendar.current.startOfDay(for: date)` for consistent day boundaries

## User Data Isolation

All data includes `userId` for strict user separation:
- **Authenticated users**: Firebase UID
- **Guest users**: Empty string `""`
- **Helper**: Use `CurrentUser().idOrGuest` to never forget scoping

### Query Scoping (Always Required)
```swift
// ✅ Correct - always scoped to current user
let currentUserId = CurrentUser().idOrGuest
let descriptor = FetchDescriptor<HabitData>(
    predicate: #Predicate<HabitData> { habit in
        habit.userId == currentUserId
    }
)

// ❌ Wrong - shows all users' data
let descriptor = FetchDescriptor<HabitData>() // SECURITY RISK!
```

## Security

### Keychain Security
- **Accessibility**: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **Scrubbing**: Tokens cleared on sign-out and account deletion
- **No PII**: Analytics never include tokens or personal information

### Authentication Flow
```
UI → AuthenticationManager → Firebase Auth → KeychainManager → iOS Keychain
```

### Account Deletion
Simplified to sign-out + local data clearing (Firebase account remains but user is signed out).

## Backups & Retention

### BackupManager
- **Rotating snapshots**: Keeps last 10 backups
- **JSON export/import**: Human-readable format
- **User-specific**: Each user has separate backup directory
- **24-hour intervals**: Automatic backup scheduling

### DataRetentionManager
- **365-day policy**: Automatic cleanup of detailed logs
- **Preserves aggregates**: Streak counts, completion rates
- **User-scoped**: Retention applied per user
- **Configurable**: Policy can be adjusted per user preference

## Analytics & Monitoring

### Privacy-First Analytics
- **No PII**: Analytics events pass through a single `PrivacyHelper.redact()`; we never log UID, email, or tokens
- **PrivacyHelper**: Automatic PII detection and redaction for all analytics events
- **Safe logging**: `PrivacyHelper.safeAnalyticsLog()` for all events with automatic redaction

### Performance Monitoring
- **PerformanceMetrics**: Timing, events, memory usage
- **DataUsageAnalytics**: Storage usage, operation sizes
- **UserAnalytics**: Behavior tracking, engagement metrics

## Schema Versioning

### Current Version
- **Schema Version**: 1
- **Migration Matrix**: Defined migration paths between versions
- **Breaking Changes**: Documented and versioned

### Migration Strategy
```swift
// Check if migration needed
let storedVersion = getStoredSchemaVersion()
if storedVersion < SchemaVersion.current {
    // Execute migration
    let executor = SchemaMigrationExecutor()
    try await executor.executeMigration(from: storedVersion, to: SchemaVersion.current)
}
```

## Sync (PLANNED/DISABLED)

### CloudKit Integration (Infrastructure Ready)
- **Private Database**: User-specific data zones (PLANNED)
- **Conflict Resolution**: Day-level conflict unit (PLANNED)
- **Last-write-wins**: Per-day completion records (PLANNED)
- **Streak Recalculation**: Recompute after merge (PLANNED)
- **Repository Mediation**: All sync operations through Repository (PLANNED)

### Sync Strategy (PLANNED)
```
Local Changes → Repository → CloudKit Sync Manager → CloudKit Private DB
Remote Changes → CloudKit → Conflict Resolution → Repository → UI Update
```

## Risk Checks & Edge Cases

### Day Boundary & DST Handling
**Risk**: Day boundaries and DST transitions can cause data inconsistency.  
**Solution**: "Day" is defined as local time with consistent cutoff. Persist UTC timestamps; render in local timezone. All date operations use `Calendar.current` for timezone-aware calculations. Test DST transitions (spring forward/fall back) to ensure streak calculations remain accurate.

### Single ModelContainer Strategy
**Risk**: Multiple ModelContainer instances can cause data inconsistency.  
**Solution**: Affirm there's one container/context strategy app-wide. Saves are debounced (0.5s) and lifecycle-flushed (app background/foreground). All SwiftData operations go through the single `HabitStore` actor for thread safety.

### Guest→Auth Migration Decision Rule
**Risk**: Unclear data ownership when guest users sign up.  
**Solution**: Guest data merges (not forks) when user signs up. User gets choice: "Keep My Data" or "Start Fresh". If keeping data, guest habits are migrated to authenticated user's `userId` and synced to cloud storage. Migration is one-way and irreversible.

## Production Checklist

### ✅ Completed
- [x] SwiftData primary storage with relationships
- [x] User data isolation with `userId` scoping
- [x] Keychain security with proper accessibility settings
- [x] Denormalized fields marked with recompute methods
- [x] Privacy-first analytics with PII redaction
- [x] Schema versioning and migration framework
- [x] Backup and retention systems
- [x] Comprehensive error handling and logging

### 🔄 In Progress
- [ ] Schedule enum migration (String → typed enum)
- [ ] DST transition testing
- [ ] CloudKit conflict resolution implementation
- [ ] Performance optimization for large datasets

### 📋 Future Enhancements
- [ ] Real-time sync with CloudKit
- [ ] Advanced conflict resolution strategies
- [ ] Data export/import formats (CSV, JSON)
- [ ] Cross-platform data compatibility
- [ ] Advanced analytics and insights

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           🎯 HABITTO DATA ARCHITECTURE                         │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                📱 UI LAYER                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│  HomeView  │  MoreTabView  │  ProfileView  │  LoginView  │  CreateHabitView    │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           🎛️  MANAGER LAYER (@MainActor)                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│  AuthenticationManager  │  HabitRepository  │  VacationManager  │  Analytics    │
│  • Firebase Auth        │  • UI Facade      │  • UserDefaults   │  • Privacy    │
│  • Keychain Tokens      │  • User Scoping   │  • History Mgmt   │  • PII Safe   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           ⚡ ACTOR LAYER (Background)                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                            HabitStore (Actor)                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ DataValidation  │  │ MigrationMgr    │  │ RetentionMgr    │  │ BackupMgr   │ │
│  │ • Input Valid.  │  │ • Schema Mgmt   │  │ • 365-day Clean│  │ • JSON Snap │ │
│  │ • Data Integrity│  │ • Version Mgmt  │  │ • User Scoped   │  │ • Rotating  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            💾 STORAGE LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│  SwiftData (Primary)  │  UserDefaults (Legacy)  │  Keychain (Security)  │  CK* │
│  • HabitData          │  • App Settings         │  • Auth Tokens        │DISAB│
│  • Relationships      │  • Migration Flags      │  • User Secrets       │     │
│  • User Isolation     │  • Cache Data           │  • Biometric          │     │
│  • SQLite Backend     │  • JSON Storage         │  • iOS Keychain       │     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Code Examples

### Safe User Data Access
```swift
// ✅ Always scope queries to current user
let currentUserId = CurrentUser().idOrGuest
let descriptor = FetchDescriptor<HabitData>(
    predicate: #Predicate<HabitData> { habit in
        habit.userId == currentUserId
    }
)
```

### Denormalized Field Management
```swift
// ✅ Use source of truth methods
let isCompleted = habit.isCompleted(for: today)
let trueStreak = habit.calculateTrueStreak()

// ✅ Recompute when modifying completion history
habit.completionHistory.append(newRecord)
habit.recomputeDenormalizedFields()
```

### Privacy-Safe Analytics
```swift
// ✅ Safe analytics logging
PrivacyHelper.safeAnalyticsLog(
    event: "habit_created",
    parameters: [
        "habit_type": "formation",
        "schedule": "daily"
    ]
)
```

### Schema Migration
```swift
// ✅ Check and execute migrations
if storedVersion < SchemaVersion.current {
    let executor = SchemaMigrationExecutor()
    try await executor.executeMigration(from: storedVersion, to: SchemaVersion.current)
}
```

This architecture provides a robust, secure, and scalable foundation for habit tracking with clear separation of concerns and comprehensive data management.
