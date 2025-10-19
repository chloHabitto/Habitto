import Foundation
import SwiftData
import SwiftUI

/// Standalone migration test runner for easy testing
///
/// **Usage:**
/// ```swift
/// let runner = MigrationTestRunner()
/// await runner.runFullTest()
/// ```
@MainActor
class MigrationTestRunner: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRunning = false
    @Published var currentStep = ""
    @Published var progress: Double = 0.0
    @Published var output = ""
    @Published var migrationSummary: HabitDataMigrationSummary?
    @Published var validationResult: HabitDataMigrationValidationResult?
    
    // MARK: - Properties
    
    private let testUserId = "test_migration_user"
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    // MARK: - Setup
    
    func setup() throws {
        log("🔧 Setting up SwiftData container...")
        
        let schema = Schema([
            HabitModel.self,
            DailyProgressModel.self,
            GlobalStreakModel.self,
            UserProgressModel.self,
            XPTransactionModel.self,
            AchievementModel.self,
            ReminderModel.self
        ])
        
        // Use in-memory store for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer!)
        
        log("✅ SwiftData container ready")
    }
    
    // MARK: - Test Data
    
    func generateTestData() {
        log("🧪 Generating sample test data...")
        SampleDataGenerator.generateTestData(userId: testUserId)
        
        // Verify it was created
        let habits = Habit.loadHabits()
        log("✅ Generated \(habits.count) test habits")
        
        // Show details
        for habit in habits {
            log("  - \(habit.name) (\(habit.habitType == .formation ? "Formation" : "Breaking"))")
            log("    Goal: \(habit.goal)")
            log("    Schedule: \(habit.schedule)")
            
            let progressCount = habit.habitType == .breaking
                ? habit.actualUsage.count
                : habit.completionHistory.count
            log("    Progress records: \(progressCount)")
        }
    }
    
    func clearTestData() {
        log("🗑️ Clearing test data...")
        SampleDataGenerator.clearTestData(userId: testUserId)
        
        // Also clear new data if exists
        if let context = modelContext {
            do {
                let habits = try context.fetch(FetchDescriptor<HabitModel>(
                    predicate: #Predicate { habit in habit.userId == testUserId }
                ))
                
                for habit in habits {
                    context.delete(habit)
                }
                
                try context.save()
                log("✅ Test data cleared")
            } catch {
                log("⚠️ Error clearing new data: \(error)")
            }
        }
    }
    
    func getOldDataStatus() -> (habitCount: Int, progressCount: Int, xp: Int) {
        let habits = Habit.loadHabits()
        var progressCount = 0
        
        for habit in habits {
            if habit.habitType == .breaking {
                progressCount += habit.actualUsage.count
            } else {
                progressCount += habit.completionHistory.count
            }
        }
        
        let xp = UserDefaults.standard.integer(forKey: "total_xp_\(testUserId)")
        
        return (habits.count, progressCount, xp)
    }
    
    // MARK: - Migration Tests
    
    func runDryRun() async throws {
        guard let context = modelContext else {
            throw NSError(domain: "MigrationTestRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not initialized. Call setup() first."])
        }
        
        log("🧪 Running migration DRY RUN...")
        isRunning = true
        currentStep = "Running dry run"
        progress = 0.1
        
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        manager.progressDelegate = self
        
        do {
            let summary = try await manager.migrate(dryRun: true)
            migrationSummary = summary
            
            log(summary.description)
            
            if summary.success {
                log("✅ Dry run PASSED")
            } else {
                log("❌ Dry run FAILED")
            }
            
            isRunning = false
            currentStep = "Dry run complete"
            progress = 1.0
            
        } catch {
            log("❌ Dry run ERROR: \(error.localizedDescription)")
            isRunning = false
            throw error
        }
    }
    
    func runActualMigration() async throws {
        guard let context = modelContext else {
            throw NSError(domain: "MigrationTestRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not initialized. Call setup() first."])
        }
        
        log("💾 Running ACTUAL migration...")
        isRunning = true
        currentStep = "Running actual migration"
        progress = 0.1
        
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        manager.progressDelegate = self
        
        do {
            let summary = try await manager.migrate(dryRun: false)
            migrationSummary = summary
            
            log(summary.description)
            
            if summary.success {
                log("✅ Migration SUCCESSFUL")
            } else {
                log("❌ Migration FAILED")
            }
            
            isRunning = false
            currentStep = "Migration complete"
            progress = 1.0
            
        } catch {
            log("❌ Migration ERROR: \(error.localizedDescription)")
            isRunning = false
            throw error
        }
    }
    
    func validateMigration() async throws {
        guard let context = modelContext else {
            throw NSError(domain: "MigrationTestRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not initialized. Call setup() first."])
        }
        
        log("🔍 Validating migrated data...")
        
        let validator = MigrationValidator(modelContext: context, userId: testUserId)
        let result = try await validator.validate()
        validationResult = result
        
        log(result.description)
        
        if result.isValid {
            log("✅ Validation PASSED")
        } else {
            log("❌ Validation FAILED")
            for error in result.errors {
                log("  ❌ \(error)")
            }
        }
    }
    
    func rollback() async throws {
        guard let context = modelContext else {
            throw NSError(domain: "MigrationTestRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not initialized. Call setup() first."])
        }
        
        log("🔄 Rolling back migration...")
        
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        try await manager.rollback()
        
        log("✅ Rollback complete")
    }
    
    // MARK: - Full Test
    
    func runFullTest() async {
        log("═══════════════════════════════════════════════════════════")
        log("🧪 MIGRATION FULL TEST")
        log("═══════════════════════════════════════════════════════════\n")
        
        do {
            // Setup
            try setup()
            
            // Generate test data
            generateTestData()
            
            let oldStatus = getOldDataStatus()
            log("\n📊 Old Data Status:")
            log("  - Habits: \(oldStatus.habitCount)")
            log("  - Progress records: \(oldStatus.progressCount)")
            log("  - XP: \(oldStatus.xp)")
            
            // Dry run
            log("\n" + String(repeating: "─", count: 63))
            log("STEP 1: DRY RUN")
            log(String(repeating: "─", count: 63) + "\n")
            try await runDryRun()
            
            // Actual migration
            log("\n" + String(repeating: "─", count: 63))
            log("STEP 2: ACTUAL MIGRATION")
            log(String(repeating: "─", count: 63) + "\n")
            try await runActualMigration()
            
            // Validation
            log("\n" + String(repeating: "─", count: 63))
            log("STEP 3: VALIDATION")
            log(String(repeating: "─", count: 63) + "\n")
            try await validateMigration()
            
            // Summary
            log("\n═══════════════════════════════════════════════════════════")
            log("🎉 FULL TEST COMPLETE")
            log("═══════════════════════════════════════════════════════════\n")
            
            if let summary = migrationSummary, summary.success,
               let validation = validationResult, validation.isValid {
                log("✅ ALL TESTS PASSED")
                log("\nMigration Summary:")
                log("  - Habits migrated: \(summary.habitsCreated)")
                log("  - Progress records: \(summary.progressRecordsCreated)")
                log("  - XP migrated: \(summary.totalXP)")
                log("  - Duration: \(String(format: "%.2fs", summary.duration ?? 0))")
            } else {
                log("❌ TESTS FAILED - See errors above")
            }
            
            // Cleanup
            log("\n🗑️ Cleaning up...")
            clearTestData()
            try await rollback()
            
            log("✅ Cleanup complete\n")
            
        } catch {
            log("\n❌ TEST FAILED: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)"
        
        print(line)
        
        DispatchQueue.main.async {
            self.output += line + "\n"
        }
    }
}

// MARK: - Migration Progress Delegate

extension MigrationTestRunner: MigrationProgressDelegate {
    nonisolated func migrationProgress(step: String, current: Int, total: Int) {
        Task { @MainActor in
            currentStep = step
            progress = Double(current) / Double(total)
            log("⏳ \(step) (\(current)/\(total))")
        }
    }
    
    nonisolated func migrationError(error: Error) {
        Task { @MainActor in
            log("❌ ERROR: \(error.localizedDescription)")
        }
    }
    
    nonisolated func migrationComplete(summary: HabitDataMigrationSummary) {
        Task { @MainActor in
            log("✅ Migration complete!")
        }
    }
}

