# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2025-01-XX

### Added
- **Data Architecture & Migration Plan - Event Sourcing Implementation**
  - `ProgressEvent` model as immutable source of truth for habit progress
  - `ProgressEventService` for event creation and management
  - Event-sourced records for all habit progress changes
  - `SyncEngine` actor with Firestore sync capabilities
  - Periodic sync scheduling for authenticated users
  - Dual-write strategy (SwiftData + Firestore)
  - `EventCompactor` service for storage optimization
  - `EventSequenceCounter` for deterministic event IDs
  - Sync health monitoring with error logging and toast notifications
  - Debug UI for migration status verification

### Changed
- **Data Layer Architecture**
  - Default feature flags now enable normalized data path (useNormalizedDataPath = true)
  - All XP/level/streak mutations now go through XPService only
  - Event creation integrated into `HabitStore.setProgress()`
  - Materialized views (`CompletionRecord`) maintained for performance
  - Idempotent sync operations with deterministic IDs
  - Conflict-free merging capability

### Fixed
- **Data Migrations**
  - Guest to Auth migration completed successfully
  - Completion Status migration completed successfully
  - Completions to Events migration completed (28 events created)
  - XP Data migration completed successfully
  - All migrations verified and operational

## [Previous Phases]

### Phase 3: Migrations + Feature-Flagged Routing
- Implemented MigrationRunner with idempotent migration logic
- Created RepositoryProvider for feature-flagged routing
- Added AuthRoutingManager for authentication state handling
- Enhanced XPService with proper validation and XP_RULES configuration
- Added comprehensive test coverage for both legacy and normalized paths

### Phase 2: Centralize XP Management and Add Invariant Guards
- Introduced XPService as centralized XP management service
- Added userId to all persisted models with proper indexing
- Enhanced DailyAward with allHabitsCompleted field and unique constraints
- Created invariant guard tests to detect XP mutation violations
- Marked denormalized fields as deprecated without removing them

### Phase 1: Data Hardening — Evidence & Guards
- Generated comprehensive model inventory and relationship mapping
- Traced all XP/Level/Streak/Completion mutation paths
- Audited dual storage usage and user isolation issues
- Created detailed documentation of data architecture problems
- Identified root cause of guest/sign-in bug

## Migration Guide

### For Developers

1. **XP Mutations**: Use `XPService.awardDailyCompletionIfEligible()` instead of direct XPManager methods
2. **Streak Access**: Use `habit.calculateTrueStreak()` instead of `habit.streak` property
3. **Completion Status**: Use `habit.isCompleted(for: date)` instead of `habit.isCompleted` property
4. **Repository Access**: Use `AuthRoutingManager.shared.currentRepositoryProvider` for data access

### For Users

- No user-visible changes - all improvements are internal
- Existing data will be automatically migrated to the new storage system
- Performance improvements and better data consistency
- No action required from users

## Breaking Changes

### API Changes
- `XPManager.debugForceAwardXP()` is now unavailable
- `XPManager.addXP()` is now unavailable  
- `Habit.updateStreakWithReset()` is now unavailable
- `Habit.correctStreak()` is now unavailable
- `Habit.recalculateCompletionStatus()` is now unavailable

### Data Model Changes
- All SwiftData models now require userId field
- Denormalized fields (isCompleted, streak) are deprecated
- Use computed methods for accessing derived data

## Testing

### Test Coverage
- **Unit Tests**: Migration idempotency, XPService functionality, feature flag validation
- **Integration Tests**: Guest/account isolation, repository switching, data consistency
- **Invariant Tests**: Build-time enforcement of XP mutation restrictions
- **End-to-End Tests**: Complete day completion flow with exact XP/level validation
- **Migration QA**: Mixed legacy/new data scenarios, rollback testing

### Test Execution
```bash
# Run all tests
xcodebuild test -scheme Habitto

# Run specific test suites
xcodebuild test -scheme Habitto -only-testing:HabittoTests/Phase4InvariantTests
xcodebuild test -scheme Habitto -only-testing:HabittoTests/Phase3IntegrationTests
```

## Performance

### Improvements
- Eliminated dual storage writes (UserDefaults + SwiftData)
- Centralized XP management reduces duplicate calculations
- User-scoped containers improve query performance
- Proper indexing on userId fields

### Metrics
- Migration time: < 30 seconds for typical user data
- XP calculation: O(1) for level determination
- User isolation: Zero data leakage between users
- Memory usage: Reduced due to eliminated dual storage

## Rollback Plan

### Emergency Rollback
1. Set `FeatureFlags.useNormalizedDataPath = false` (requires app update)
2. For internal builds: Set `emergencyDisableNormalizedPath = true` (compile-time)
3. App will automatically use legacy storage paths
4. No data loss - both storage systems remain intact

### Data Recovery
- Legacy data preserved in UserDefaults during migration
- Migration state tracked per user for rollback capability
- Comprehensive logging for troubleshooting

## Support

### Issues
- Report any data inconsistencies or migration issues
- Provide anonymized logs for debugging
- Include user ID hash (first 8 characters) for support

### Documentation
- See `docs/data/` for detailed architecture documentation
- Migration plan available in `docs/data/migration_plan.md`
- Auth routing details in `docs/data/auth_routing.md`
