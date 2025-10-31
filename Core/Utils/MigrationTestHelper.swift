import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Helper utility for testing the completionHistory → ProgressEvent migration
@MainActor
final class MigrationTestHelper {
    static let shared = MigrationTestHelper()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationTestHelper")
    
    /// Check migration status and ProgressEvent count
    func checkMigrationStatus(userId: String) async throws -> MigrationStatusReport {
        let context = SwiftDataContainer.shared.modelContext
        
        // Check MigrationState
        let migrationState = try? MigrationState.findForUser(userId: userId, in: context)
        
        // Count ProgressEvents
        let eventDescriptor = FetchDescriptor<ProgressEvent>()
        let allEvents = (try? context.fetch(eventDescriptor)) ?? []
        
        // Count migration events
        let migrationEvents = allEvents.filter { event in
            event.operationId.hasPrefix("migration_")
        }
        
        // Load habits to check completionHistory
        let habits = try await HabitStore.shared.loadHabits()
        var totalCompletionEntries = 0
        var habitsWithHistory: [String] = []
        
        for habit in habits {
            if !habit.completionHistory.isEmpty {
                habitsWithHistory.append(habit.name)
                totalCompletionEntries += habit.completionHistory.count
            }
        }
        
        // Group events by habit
        let eventsByHabit = Dictionary(grouping: allEvents) { $0.habitId }
        
        return MigrationStatusReport(
            migrationState: migrationState,
            totalEvents: allEvents.count,
            migrationEvents: migrationEvents.count,
            totalCompletionEntries: totalCompletionEntries,
            habitsWithHistory: habitsWithHistory,
            eventsByHabit: eventsByHabit.mapValues { $0.count }
        )
    }
    
    /// Print detailed migration status
    func printMigrationStatus(userId: String) async throws {
        logger.info("🔍 MigrationTestHelper: Checking migration status for user \(userId)")
        
        let context = SwiftDataContainer.shared.modelContext
        
        // Check all habits in SwiftData (regardless of userId)
        let allHabitsDescriptor = FetchDescriptor<HabitData>()
        let allHabits = (try? context.fetch(allHabitsDescriptor)) ?? []
        
        // Group habits by userId
        let habitsByUserId = Dictionary(grouping: allHabits) { $0.userId }
        
        // Check CompletionRecords
        let completionDescriptor = FetchDescriptor<CompletionRecord>()
        let allCompletions = (try? context.fetch(completionDescriptor)) ?? []
        let completionsByUserId = Dictionary(grouping: allCompletions) { $0.userId }
        
        let report = try await checkMigrationStatus(userId: userId)
        
        print("\n==========================================")
        print("📊 MIGRATION STATUS REPORT")
        print("==========================================")
        print("Current User ID: \(userId)")
        print("")
        
        print("📋 SwiftData Analysis:")
        print("  Total Habits in SwiftData: \(allHabits.count)")
        print("  Total CompletionRecords: \(allCompletions.count)")
        print("")
        print("  Habits by UserId:")
        if habitsByUserId.isEmpty {
            print("    ⚠️ No habits found in SwiftData")
        } else {
            for (uid, habits) in habitsByUserId.sorted(by: { $0.key < $1.key }) {
                let userIdLabel = uid.isEmpty ? "(empty/guest)" : uid.prefix(8) + "..."
                let matchMarker = uid == userId ? " ✅ (matches current user)" : ""
                print("    '\(userIdLabel)': \(habits.count) habits\(matchMarker)")
                for habit in habits.prefix(3) {
                    print("      - '\(habit.name)' (id: \(habit.id.uuidString.prefix(8))...)")
                }
                if habits.count > 3 {
                    print("      ... and \(habits.count - 3) more")
                }
            }
        }
        print("")
        print("  CompletionRecords by UserId:")
        if completionsByUserId.isEmpty {
            print("    ⚠️ No CompletionRecords found")
        } else {
            for (uid, records) in completionsByUserId.sorted(by: { $0.key < $1.key }) {
                let userIdLabel = uid.isEmpty ? "(empty/guest)" : uid.prefix(8) + "..."
                let matchMarker = uid == userId ? " ✅ (matches current user)" : ""
                print("    '\(userIdLabel)': \(records.count) records\(matchMarker)")
            }
        }
        print("")
        
        if let state = report.migrationState {
            print("Migration State:")
            print("  Status: \(state.status.displayName)")
            print("  Version: \(state.migrationVersion)")
            print("  Completed: \(state.isCompleted ? "✅" : "❌")")
            if let completedAt = state.completedAt {
                print("  Completed At: \(completedAt)")
            }
            print("  Records Migrated: \(state.migratedRecordsCount)")
        } else {
            print("Migration State: ⚠️ Not found (migration not run yet)")
        }
        
        print("")
        print("Progress Events:")
        print("  Total Events: \(report.totalEvents)")
        print("  Migration Events: \(report.migrationEvents)")
        print("  User-Generated Events: \(report.totalEvents - report.migrationEvents)")
        
        print("")
        print("Completion History (from loaded habits):")
        print("  Habits with History: \(report.habitsWithHistory.count)")
        print("  Total Entries: \(report.totalCompletionEntries)")
        if !report.habitsWithHistory.isEmpty {
            print("  Habits: \(report.habitsWithHistory.joined(separator: ", "))")
        } else if allHabits.isEmpty {
            print("  ⚠️ No habits found - cannot check completionHistory")
        } else {
            print("  ⚠️ No habits loaded for current user - habits may be stored under different userId")
        }
        
        print("")
        print("Events by Habit:")
        if report.eventsByHabit.isEmpty {
            print("  No events found")
        } else {
            for (habitId, count) in report.eventsByHabit {
                print("  \(habitId.uuidString.prefix(8))...: \(count) events")
            }
        }
        
        print("==========================================\n")
    }
    
    /// Verify migration results
    func verifyMigration(userId: String) async throws -> MigrationVerificationResult {
        let context = SwiftDataContainer.shared.modelContext
        
        // Load habits
        let habits = try await HabitStore.shared.loadHabits()
        
        var verified = 0
        var missing = 0
        var mismatched = 0
        var errors: [String] = []
        
        for habit in habits {
            guard !habit.completionHistory.isEmpty else { continue }
            
            for (dateKey, expectedProgress) in habit.completionHistory {
                guard expectedProgress > 0 else { continue }
                
                // Check if event exists
                let eventDescriptor = ProgressEvent.eventsForHabitDate(
                    habitId: habit.id,
                    dateKey: dateKey
                )
                let events = (try? context.fetch(eventDescriptor)) ?? []
                
                if events.isEmpty {
                    missing += 1
                    errors.append("Missing event for habit '\(habit.name)' on \(dateKey)")
                } else {
                    // Calculate progress from events
                    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
                    let result = await ProgressEventService.shared.calculateProgressFromEvents(
                        habitId: habit.id,
                        dateKey: dateKey,
                        goalAmount: goalAmount,
                        legacyProgress: expectedProgress,
                        modelContext: context
                    )
                    
                    if result.progress == expectedProgress {
                        verified += 1
                    } else {
                        mismatched += 1
                        errors.append("Progress mismatch for habit '\(habit.name)' on \(dateKey): expected \(expectedProgress), got \(result.progress)")
                    }
                }
            }
        }
        
        return MigrationVerificationResult(
            verified: verified,
            missing: missing,
            mismatched: mismatched,
            errors: errors
        )
    }
    
    /// Print verification results
    func printVerification(userId: String) async throws {
        logger.info("🔍 MigrationTestHelper: Verifying migration for user \(userId)")
        
        let result = try await verifyMigration(userId: userId)
        
        print("\n==========================================")
        print("✅ MIGRATION VERIFICATION")
        print("==========================================")
        print("Verified: \(result.verified) ✅")
        print("Missing: \(result.missing) ❌")
        print("Mismatched: \(result.mismatched) ⚠️")
        
        if !result.errors.isEmpty {
            print("\nErrors:")
            for error in result.errors.prefix(10) {
                print("  - \(error)")
            }
            if result.errors.count > 10 {
                print("  ... and \(result.errors.count - 10) more errors")
            }
        }
        
        print("==========================================\n")
    }
    
    /// Trigger migration (auto-detects userId)
    func triggerMigration(force: Bool = false) async throws {
        let userId = await CurrentUser().idOrGuest
        logger.info("🚀 MigrationTestHelper: Triggering migration for user \(userId) (force: \(force))")
        
        print("\n🚀 Starting migration for user: \(userId)")
        print("   Force mode: \(force ? "YES" : "NO")")
        
        do {
            if force {
                try await MigrationRunner.shared.forceMigration(userId: userId)
            } else {
                try await MigrationRunner.shared.runIfNeeded(userId: userId)
            }
            
            print("✅ Migration completed successfully")
            logger.info("✅ MigrationTestHelper: Migration completed")
            
            // Auto-print status after migration
            try await printMigrationStatus(userId: userId)
        } catch {
            print("❌ Migration failed: \(error.localizedDescription)")
            logger.error("❌ MigrationTestHelper: Migration failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Trigger migration with explicit userId
    func triggerMigration(userId: String, force: Bool = false) async throws {
        logger.info("🚀 MigrationTestHelper: Triggering migration for user \(userId) (force: \(force))")
        
        if force {
            try await MigrationRunner.shared.forceMigration(userId: userId)
        } else {
            try await MigrationRunner.shared.runIfNeeded(userId: userId)
        }
        
        logger.info("✅ MigrationTestHelper: Migration completed")
    }
    
    /// Check migration status (auto-detects userId)
    func checkMigrationStatus() async throws -> MigrationStatusReport {
        let userId = await CurrentUser().idOrGuest
        return try await checkMigrationStatus(userId: userId)
    }
    
    /// Print migration status (auto-detects userId)
    func printMigrationStatus() async throws {
        let userId = await CurrentUser().idOrGuest
        try await printMigrationStatus(userId: userId)
    }
    
    /// Verify migration (auto-detects userId)
    func verifyMigration() async throws -> MigrationVerificationResult {
        let userId = await CurrentUser().idOrGuest
        return try await verifyMigration(userId: userId)
    }
    
    /// Print verification (auto-detects userId)
    func printVerification() async throws {
        let userId = await CurrentUser().idOrGuest
        try await printVerification(userId: userId)
    }
}

// MARK: - Migration Status Report

struct MigrationStatusReport {
    let migrationState: MigrationState?
    let totalEvents: Int
    let migrationEvents: Int
    let totalCompletionEntries: Int
    let habitsWithHistory: [String]
    let eventsByHabit: [UUID: Int]
}

// MARK: - Migration Verification Result

struct MigrationVerificationResult {
    let verified: Int
    let missing: Int
    let mismatched: Int
    let errors: [String]
}

