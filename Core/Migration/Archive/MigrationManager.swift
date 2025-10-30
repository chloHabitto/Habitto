import Foundation
import SwiftData

/// MigrationManager orchestrates the entire migration from old to new data models
///
/// **Safety Features:**
/// - Never modifies old data (read-only)
/// - Transaction-based (rollback on failure)
/// - Idempotent (can run multiple times safely)
/// - Progress reporting
/// - Dry-run mode for testing
///
/// **Usage:**
/// ```swift
/// let manager = MigrationManager(modelContext: context)
/// try await manager.migrate(dryRun: true)  // Test first
/// try await manager.migrate(dryRun: false) // Actually migrate
/// ```
@MainActor
class MigrationManager {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let userId: String
    weak var progressDelegate: MigrationProgressDelegate?
    
    private let habitMigrator: HabitMigrator
    private let streakMigrator: StreakMigrator
    private let xpMigrator: XPMigrator
    private let validator: MigrationValidator
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
        
        // Initialize migrators
        self.habitMigrator = HabitMigrator(modelContext: modelContext, userId: userId)
        self.streakMigrator = StreakMigrator(modelContext: modelContext, userId: userId)
        self.xpMigrator = XPMigrator(modelContext: modelContext, userId: userId)
        self.validator = MigrationValidator(modelContext: modelContext, userId: userId)
    }
    
    // MARK: - Migration
    
    /// Run the complete migration process
    /// - Parameter dryRun: If true, validates but doesn't save data
    /// - Returns: Migration summary
    func migrate(dryRun: Bool = true) async throws -> HabitDataMigrationSummary {
        let startTime = Date()
        
        print("🔄 Starting migration (dryRun: \(dryRun))...")
        reportProgress(step: "Starting migration", current: 0, total: 100)
        
        var summary = HabitDataMigrationSummary(
            startTime: startTime,
            dryRun: dryRun,
            userId: userId
        )
        
        do {
            // Step 1: Validate old data exists
            reportProgress(step: "Validating old data", current: 10, total: 100)
            try validateOldDataExists()
            
            // Step 2: Check if already migrated
            if try await isAlreadyMigrated() {
                print("⚠️ Data already migrated! Use rollback() first if you want to re-migrate.")
                throw HabitDataMigrationError.alreadyMigrated
            }
            
            // Step 3: Migrate habits and progress
            reportProgress(step: "Migrating habits", current: 20, total: 100)
            let habitResult = try await habitMigrator.migrate(dryRun: dryRun)
            summary.habitsCreated = habitResult.habitsCreated
            summary.progressRecordsCreated = habitResult.progressRecordsCreated
            summary.scheduleParsing = habitResult.scheduleParsing
            
            // Step 4: Migrate global streak
            reportProgress(step: "Calculating global streak", current: 60, total: 100)
            let streakResult = try await streakMigrator.migrate(dryRun: dryRun)
            summary.streakCalculated = streakResult.streakCreated
            summary.currentStreak = streakResult.currentStreak
            summary.longestStreak = streakResult.longestStreak
            
            // Step 5: Migrate XP and achievements
            reportProgress(step: "Migrating XP", current: 80, total: 100)
            let xpResult = try await xpMigrator.migrate(dryRun: dryRun)
            summary.xpMigrated = xpResult.userProgressCreated
            summary.totalXP = xpResult.totalXP
            summary.transactionsCreated = xpResult.transactionsCreated
            
            // Step 6: Validate migrated data
            reportProgress(step: "Validating migration", current: 90, total: 100)
            if !dryRun {
                let validationResult = try await validator.validate()
                summary.validation = validationResult
                
                if !validationResult.isValid {
                    throw HabitDataMigrationError.validationFailed(validationResult.errors)
                }
            }
            
            // Step 7: Save if not dry run
            if !dryRun {
                reportProgress(step: "Saving to database", current: 95, total: 100)
                try modelContext.save()
                
                // Mark as migrated
                UserDefaults.standard.set(true, forKey: "migration_completed_\(userId)")
                UserDefaults.standard.set(Date(), forKey: "migration_date_\(userId)")
            }
            
            // Complete
            summary.endTime = Date()
            summary.success = true
            summary.duration = summary.endTime!.timeIntervalSince(startTime)
            
            reportProgress(step: "Migration complete", current: 100, total: 100)
            progressDelegate?.migrationComplete(summary: summary)
            
            // Print summary
            print(summary.description)
            
            return summary
            
        } catch {
            print("❌ Migration failed: \(error)")
            
            summary.endTime = Date()
            summary.success = false
            summary.error = error
            summary.duration = summary.endTime!.timeIntervalSince(startTime)
            
            progressDelegate?.migrationError(error: error)
            
            // Rollback if not dry run
            if !dryRun {
                print("🔄 Rolling back migration...")
                try await rollback()
            }
            
            throw error
        }
    }
    
    // MARK: - Rollback
    
    /// Rollback migration by deleting all new data
    /// **Old data is never touched - remains intact**
    func rollback() async throws {
        print("🔄 Rolling back migration...")
        
        // Delete all new models for this user
        try await deleteAllNewData()
        
        // Clear migration flag
        UserDefaults.standard.removeObject(forKey: "migration_completed_\(userId)")
        UserDefaults.standard.removeObject(forKey: "migration_date_\(userId)")
        
        print("✅ Rollback complete - all new data deleted")
    }
    
    // MARK: - Validation
    
    /// Check if old data exists and is accessible
    private func validateOldDataExists() throws {
        let oldHabits = Habit.loadHabits()
        
        if oldHabits.isEmpty {
            print("⚠️ No old habits found - nothing to migrate")
        } else {
            print("✅ Found \(oldHabits.count) old habits to migrate")
        }
    }
    
    /// Check if migration has already been completed
    private func isAlreadyMigrated() async throws -> Bool {
        // Check flag
        if UserDefaults.standard.bool(forKey: "migration_completed_\(userId)") {
            return true
        }
        
        // Also check if new data exists
        let habitCount = try modelContext.fetchCount(FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in habit.userId == userId }
        ))
        
        return habitCount > 0
    }
    
    // MARK: - Cleanup
    
    /// Delete all new data for this user
    private func deleteAllNewData() async throws {
        // Delete habits (cascade will delete progress records)
        let habits = try modelContext.fetch(FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in habit.userId == userId }
        ))
        
        for habit in habits {
            modelContext.delete(habit)
        }
        
        // Delete global streak
        let streaks = try modelContext.fetch(FetchDescriptor<GlobalStreakModel>(
            predicate: #Predicate { streak in streak.userId == userId }
        ))
        
        for streak in streaks {
            modelContext.delete(streak)
        }
        
        // Delete user progress
        let progress = try modelContext.fetch(FetchDescriptor<UserProgressModel>(
            predicate: #Predicate { progress in progress.userId == userId }
        ))
        
        for p in progress {
            modelContext.delete(p)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Progress Reporting
    
    private func reportProgress(step: String, current: Int, total: Int) {
        progressDelegate?.migrationProgress(step: step, current: current, total: total)
    }
}

// MARK: - Progress Delegate

protocol MigrationProgressDelegate: AnyObject {
    func migrationProgress(step: String, current: Int, total: Int)
    func migrationError(error: Error)
    func migrationComplete(summary: HabitDataMigrationSummary)
}

// MARK: - Migration Summary

struct HabitDataMigrationSummary: CustomStringConvertible {
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    let dryRun: Bool
    let userId: String
    
    var success: Bool = false
    var error: Error?
    
    // Migration results
    var habitsCreated: Int = 0
    var progressRecordsCreated: Int = 0
    var streakCalculated: Bool = false
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var xpMigrated: Bool = false
    var totalXP: Int = 0
    var transactionsCreated: Int = 0
    
    // Schedule parsing results
    var scheduleParsing: [String: Int] = [:]
    
    // Validation result
    var validation: HabitDataMigrationValidationResult?
    
    var description: String {
        var output = """
        
        ═══════════════════════════════════════════════════════════
        📊 MIGRATION SUMMARY
        ═══════════════════════════════════════════════════════════
        
        Status: \(success ? "✅ SUCCESS" : "❌ FAILED")
        Mode: \(dryRun ? "🧪 DRY RUN" : "💾 LIVE MIGRATION")
        User ID: \(userId)
        Duration: \(duration.map { String(format: "%.2fs", $0) } ?? "N/A")
        
        ───────────────────────────────────────────────────────────
        📦 DATA MIGRATED
        ───────────────────────────────────────────────────────────
        
        Habits: \(habitsCreated)
        Progress Records: \(progressRecordsCreated)
        XP Transactions: \(transactionsCreated)
        
        ───────────────────────────────────────────────────────────
        📅 SCHEDULE PARSING
        ───────────────────────────────────────────────────────────
        
        """
        
        for (type, count) in scheduleParsing.sorted(by: { $0.key < $1.key }) {
            output += "\(type): \(count) habits\n"
        }
        
        output += """
        
        ───────────────────────────────────────────────────────────
        🔥 STREAK
        ───────────────────────────────────────────────────────────
        
        Current Streak: \(currentStreak) days
        Longest Streak: \(longestStreak) days
        
        ───────────────────────────────────────────────────────────
        ⭐ XP
        ───────────────────────────────────────────────────────────
        
        Total XP: \(totalXP)
        Level: \(UserProgressModel.calculateLevel(fromXP: totalXP))
        
        """
        
        if let validation = validation {
            output += """
            ───────────────────────────────────────────────────────────
            ✓ VALIDATION
            ───────────────────────────────────────────────────────────
            
            \(validation.description)
            
            """
        }
        
        if let error = error {
            output += """
            ───────────────────────────────────────────────────────────
            ⚠️ ERROR
            ───────────────────────────────────────────────────────────
            
            \(error.localizedDescription)
            
            """
        }
        
        output += "═══════════════════════════════════════════════════════════\n"
        
        return output
    }
}

// MARK: - Migration Errors

enum HabitDataMigrationError: LocalizedError {
    case alreadyMigrated
    case validationFailed([String])
    case oldDataNotFound
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyMigrated:
            return "Migration has already been completed. Use rollback() first to re-migrate."
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .oldDataNotFound:
            return "No old data found to migrate"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        }
    }
}

