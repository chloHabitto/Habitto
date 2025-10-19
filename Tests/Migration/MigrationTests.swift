import XCTest
import SwiftData
@testable import Habitto

/// Comprehensive tests for the migration system
///
/// **Test Coverage:**
/// - Unit tests for each migrator
/// - Integration test for full migration
/// - Edge case tests
/// - Rollback tests
/// - Validation tests
@MainActor
final class MigrationTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    let testUserId = "test_user_123"
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            HabitModel.self,
            DailyProgressModel.self,
            GlobalStreakModel.self,
            UserProgressModel.self,
            XPTransactionModel.self,
            AchievementModel.self,
            ReminderModel.self
        ])
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        
        // Clear any existing test data
        SampleDataGenerator.clearTestData(userId: testUserId)
    }
    
    override func tearDown() async throws {
        // Cleanup
        SampleDataGenerator.clearTestData(userId: testUserId)
        container = nil
        context = nil
    }
    
    // MARK: - Integration Tests
    
    /// Test complete migration flow with sample data
    func testFullMigration() async throws {
        // 1. Generate sample data
        SampleDataGenerator.generateTestData(userId: testUserId)
        
        // 2. Create migration manager
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        
        // 3. Run migration (dry run first)
        let dryRunSummary = try await manager.migrate(dryRun: true)
        
        XCTAssertTrue(dryRunSummary.success, "Dry run should succeed")
        XCTAssertTrue(dryRunSummary.habitsCreated > 0, "Should migrate habits")
        XCTAssertTrue(dryRunSummary.progressRecordsCreated > 0, "Should create progress records")
        
        // 4. Run actual migration
        let summary = try await manager.migrate(dryRun: false)
        
        XCTAssertTrue(summary.success, "Migration should succeed")
        XCTAssertEqual(summary.habitsCreated, 10, "Should migrate all test habits")
        
        // 5. Validate data
        let habits = try context.fetch(FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in habit.userId == testUserId }
        ))
        
        XCTAssertEqual(habits.count, 10, "All habits should be migrated")
        
        // 6. Validate progress records
        let progress = try context.fetch(FetchDescriptor<DailyProgressModel>())
        XCTAssertTrue(progress.count > 0, "Should have progress records")
        
        // 7. Validate global streak
        let streaks = try context.fetch(FetchDescriptor<GlobalStreakModel>(
            predicate: #Predicate { streak in streak.userId == testUserId }
        ))
        
        XCTAssertEqual(streaks.count, 1, "Should have exactly one global streak")
        
        let streak = streaks.first!
        XCTAssertTrue(streak.currentStreak >= 0, "Current streak should be non-negative")
        XCTAssertTrue(streak.currentStreak <= streak.longestStreak, "Current ≤ Longest")
        XCTAssertTrue(streak.longestStreak <= streak.totalCompleteDays, "Longest ≤ Total")
        
        // 8. Validate XP
        let userProgress = try context.fetch(FetchDescriptor<UserProgressModel>(
            predicate: #Predicate { progress in progress.userId == testUserId }
        ))
        
        XCTAssertEqual(userProgress.count, 1, "Should have user progress")
        XCTAssertTrue(userProgress.first!.totalXP > 0, "Should have XP")
    }
    
    // MARK: - Unit Tests: HabitMigrator
    
    func testHabitMigratorFormationHabit() async throws {
        // Create a simple formation habit
        let habit = Habit(
            name: "Test Habit",
            description: "Test",
            icon: "star",
            color: .blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "5 times",
            reminder: "",
            startDate: Date()
        )
        
        Habit.saveHabits([habit])
        
        // Migrate
        let migrator = HabitMigrator(modelContext: context, userId: testUserId)
        let result = try await migrator.migrate(dryRun: false)
        
        XCTAssertEqual(result.habitsCreated, 1)
        
        // Verify habit
        let habits = try context.fetch(FetchDescriptor<HabitModel>())
        XCTAssertEqual(habits.count, 1)
        
        let newHabit = habits.first!
        XCTAssertEqual(newHabit.name, "Test Habit")
        XCTAssertEqual(newHabit.goalCount, 5)
        XCTAssertEqual(newHabit.goalUnit, "times")
        XCTAssertEqual(newHabit.habitTypeEnum, .formation)
    }
    
    func testHabitMigratorBreakingHabit() async throws {
        // Create a breaking habit
        var habit = Habit(
            name: "Reduce Coffee",
            description: "Test",
            icon: "cup.and.saucer.fill",
            color: .brown,
            habitType: .breaking,
            schedule: "Everyday",
            goal: "3 cups",
            reminder: "",
            startDate: Date(),
            baseline: 10,
            target: 3
        )
        
        // Add actualUsage
        habit.actualUsage["2024-01-01"] = 5
        habit.actualUsage["2024-01-02"] = 3
        
        Habit.saveHabits([habit])
        
        // Migrate
        let migrator = HabitMigrator(modelContext: context, userId: testUserId)
        let result = try await migrator.migrate(dryRun: false)
        
        XCTAssertEqual(result.habitsCreated, 1)
        XCTAssertEqual(result.progressRecordsCreated, 2)
        
        // Verify habit
        let habits = try context.fetch(FetchDescriptor<HabitModel>())
        let newHabit = habits.first!
        
        XCTAssertEqual(newHabit.habitTypeEnum, .breaking)
        XCTAssertEqual(newHabit.goalCount, 3)
        XCTAssertEqual(newHabit.baselineCount, 10)
    }
    
    func testScheduleParsing() async throws {
        let testCases: [(String, Schedule)] = [
            ("Everyday", .daily),
            ("Every 3 days", .everyNDays(3)),
            ("Every Monday, Wednesday", .specificWeekdays([.monday, .wednesday])),
            ("3 days a week", .frequencyWeekly(3)),
            ("5 days a month", .frequencyMonthly(5))
        ]
        
        for (scheduleString, expectedSchedule) in testCases {
            let parsed = Schedule.fromLegacyString(scheduleString)
            
            // Compare by description (since Schedule doesn't conform to Equatable)
            XCTAssertEqual(
                String(describing: parsed),
                String(describing: expectedSchedule),
                "Failed to parse: \(scheduleString)"
            )
        }
    }
    
    // MARK: - Unit Tests: StreakMigrator
    
    func testStreakCalculation() async throws {
        // Create habits with progress
        SampleDataGenerator.generateTestData(userId: testUserId)
        
        // Migrate habits first
        let habitMigrator = HabitMigrator(modelContext: context, userId: testUserId)
        _ = try await habitMigrator.migrate(dryRun: false)
        
        // Then migrate streak
        let streakMigrator = StreakMigrator(modelContext: context, userId: testUserId)
        let result = try await streakMigrator.migrate(dryRun: false)
        
        XCTAssertTrue(result.streakCreated)
        XCTAssertTrue(result.currentStreak >= 0)
        XCTAssertTrue(result.longestStreak >= result.currentStreak)
        XCTAssertTrue(result.totalCompleteDays >= result.longestStreak)
    }
    
    // MARK: - Unit Tests: XPMigrator
    
    func testXPMigration() async throws {
        // Set up old XP data
        UserDefaults.standard.set(5000, forKey: "total_xp_\(testUserId)")
        UserDefaults.standard.set(5, forKey: "current_level_\(testUserId)")
        
        // Migrate
        let migrator = XPMigrator(modelContext: context, userId: testUserId)
        let result = try await migrator.migrate(dryRun: false)
        
        XCTAssertTrue(result.userProgressCreated)
        XCTAssertEqual(result.totalXP, 5000)
        
        // Verify user progress
        let userProgress = try context.fetch(FetchDescriptor<UserProgressModel>(
            predicate: #Predicate { progress in progress.userId == testUserId }
        ))
        
        XCTAssertEqual(userProgress.count, 1)
        XCTAssertEqual(userProgress.first!.totalXP, 5000)
    }
    
    // MARK: - Validation Tests
    
    func testValidationPasses() async throws {
        // Generate and migrate data
        SampleDataGenerator.generateTestData(userId: testUserId)
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        _ = try await manager.migrate(dryRun: false)
        
        // Validate
        let validator = MigrationValidator(modelContext: context, userId: testUserId)
        let result = try await validator.validate()
        
        XCTAssertTrue(result.isValid, "Validation should pass")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }
    
    // MARK: - Edge Case Tests
    
    func testMigrationWithNoData() async throws {
        // Don't generate any data
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        let summary = try await manager.migrate(dryRun: false)
        
        // Should succeed but with 0 items migrated
        XCTAssertTrue(summary.success)
        XCTAssertEqual(summary.habitsCreated, 0)
    }
    
    func testMigrationIdempotency() async throws {
        // Generate data
        SampleDataGenerator.generateTestData(userId: testUserId)
        
        // First migration
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        let firstSummary = try await manager.migrate(dryRun: false)
        XCTAssertTrue(firstSummary.success)
        
        // Second migration should fail (already migrated)
        do {
            _ = try await manager.migrate(dryRun: false)
            XCTFail("Second migration should throw alreadyMigrated error")
        } catch MigrationError.alreadyMigrated {
            // Expected
        }
    }
    
    // MARK: - Rollback Tests
    
    func testRollback() async throws {
        // Generate and migrate data
        SampleDataGenerator.generateTestData(userId: testUserId)
        let manager = MigrationManager(modelContext: context, userId: testUserId)
        _ = try await manager.migrate(dryRun: false)
        
        // Verify data exists
        var habits = try context.fetch(FetchDescriptor<HabitModel>())
        XCTAssertFalse(habits.isEmpty)
        
        // Rollback
        try await manager.rollback()
        
        // Verify data is deleted
        habits = try context.fetch(FetchDescriptor<HabitModel>())
        XCTAssertTrue(habits.isEmpty, "All new data should be deleted")
        
        // Should be able to migrate again
        let secondSummary = try await manager.migrate(dryRun: false)
        XCTAssertTrue(secondSummary.success)
    }
    
    // MARK: - Performance Tests
    
    func testMigrationPerformance() async throws {
        // Generate large dataset
        SampleDataGenerator.generateTestData(userId: testUserId)
        
        measure {
            Task { @MainActor in
                let manager = MigrationManager(modelContext: context, userId: testUserId)
                _ = try? await manager.migrate(dryRun: true)
            }
        }
    }
}

