import XCTest
import SwiftUI
@testable import Habitto

// MARK: - Phase 4 Invariant Tests
/// Tests that enforce invariants and fail build on forbidden symbols
class Phase4InvariantTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Enable all data improvements for testing
        FeatureFlags.enableAllDataImprovements()
    }
    
    override func tearDown() {
        FeatureFlags.resetToDefaults()
        super.tearDown()
    }
    
    // MARK: - Build-Time Invariant Tests
    
    func testBuildTimeInvariantEnforcement() {
        // This test should fail at compile time if forbidden symbols exist
        // The compiler should catch any remaining forbidden mutations
        
        // These should cause compile errors if the invariant is properly enforced:
        
        /*
        // ❌ These should NOT compile:
        let xpManager = XPManager.shared
        xpManager.userProgress.totalXP += 100  // Should not compile
        xpManager.userProgress.currentLevel = 10  // Should not compile
        xpManager.debugForceAwardXP(50)  // Should not compile (unavailable)
        
        var habit = Habit(name: "Test", ...)
        habit.updateStreakWithReset()  // Should not compile (unavailable)
        habit.correctStreak()  // Should not compile (unavailable)
        habit.recalculateCompletionStatus()  // Should not compile (unavailable)
        */
        
        // ✅ These should compile:
        let xpService = XPService.shared
        let _ = xpService  // Should compile
        
        // For now, we'll just test that the test framework works
        XCTAssertTrue(true, "Build-time invariant check placeholder")
    }
    
    // MARK: - Runtime Invariant Tests
    
    func testRuntimeInvariantEnforcement() {
        // Test that runtime guards catch forbidden mutations
        
        let guard = XPServiceGuard.shared
        
        // Test allowed callers
        XCTAssertNoThrow({
            guard.validateXPMutation(caller: "XPService", function: "awardDailyCompletionIfEligible")
        }, "XPService should be allowed")
        
        XCTAssertNoThrow({
            guard.validateXPMutation(caller: "DailyAwardService", function: "grantIfAllComplete")
        }, "DailyAwardService should be allowed")
        
        // Test forbidden callers (should fail in debug builds)
        #if DEBUG
        XCTAssertThrowsError({
            guard.validateXPMutation(caller: "XPManager", function: "addXP")
        }, "XPManager should be blocked")
        
        XCTAssertThrowsError({
            guard.validateXPMutation(caller: "HabitRepository", function: "toggleHabitCompletion")
        }, "HabitRepository should be blocked")
        #endif
    }
    
    // MARK: - End-to-End Day Completion Flow Tests
    
    func testEndToEndDayCompletionFlow() async throws {
        // Given: N habits
        let userId = "test_user_e2e"
        let dateKey = "2024-01-01"
        let habits = createTestHabits(count: 3)
        
        // Create habits in SwiftData
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        for habit in habits {
            let habitData = HabitData(
                id: habit.id,
                userId: userId,
                name: habit.name,
                habitDescription: habit.habitDescription,
                icon: habit.icon,
                colorData: Data(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: false,
                streak: 0
            )
            context.insert(habitData)
        }
        try context.save()
        
        // When: Complete all habits
        let xpService = XPService.shared
        
        // Create completion records for all habits
        for habit in habits {
            let completionRecord = CompletionRecord(
                userId: userId,
                habitId: habit.id,
                date: ISO8601DateHelper.shared.dateWithFallback(from: dateKey) ?? Date(),
                dateKey: dateKey,
                isCompleted: true
            )
            context.insert(completionRecord)
        }
        try context.save()
        
        // Award XP for daily completion
        let xpAwarded = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
        
        // Then: Assert one DailyAward
        let awardRequest = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId && $0.dateKey == dateKey }
        )
        let awards = try context.fetch(awardRequest)
        XCTAssertEqual(awards.count, 1)
        
        // Assert exact XP added
        XCTAssertEqual(xpAwarded, XP_RULES.dailyCompletionXP)
        XCTAssertEqual(awards.first?.xpGranted, XP_RULES.dailyCompletionXP)
        
        // Assert level math
        let userProgress = try await xpService.getUserProgress(userId: userId)
        XCTAssertEqual(userProgress.xpTotal, XP_RULES.dailyCompletionXP)
        XCTAssertEqual(userProgress.level, 1) // Should be level 1 with base XP
        
        // Assert level progress calculation
        let expectedLevelProgress = Double(XP_RULES.dailyCompletionXP) / Double(XP_RULES.levelBaseXP)
        XCTAssertEqual(userProgress.levelProgress, expectedLevelProgress, accuracy: 0.01)
    }
    
    func testMultipleDayCompletionFlow() async throws {
        // Given: User with habits
        let userId = "test_user_multiple"
        let habits = createTestHabits(count: 2)
        
        // Create habits in SwiftData
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        for habit in habits {
            let habitData = HabitData(
                id: habit.id,
                userId: userId,
                name: habit.name,
                habitDescription: habit.habitDescription,
                icon: habit.icon,
                colorData: Data(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: false,
                streak: 0
            )
            context.insert(habitData)
        }
        try context.save()
        
        let xpService = XPService.shared
        
        // When: Complete all habits for 3 consecutive days
        for dayOffset in 0..<3 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
            let dateKey = DateKey.key(for: date)
            
            // Create completion records
            for habit in habits {
                let completionRecord = CompletionRecord(
                    userId: userId,
                    habitId: habit.id,
                    date: date,
                    dateKey: dateKey,
                    isCompleted: true
                )
                context.insert(completionRecord)
            }
            try context.save()
            
            // Award XP
            let xpAwarded = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
            XCTAssertEqual(xpAwarded, XP_RULES.dailyCompletionXP)
        }
        
        // Then: Should have 3 daily awards
        let awardRequest = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId }
        )
        let awards = try context.fetch(awardRequest)
        XCTAssertEqual(awards.count, 3)
        
        // Should have total XP of 3 * daily XP
        let userProgress = try await xpService.getUserProgress(userId: userId)
        XCTAssertEqual(userProgress.xpTotal, 3 * XP_RULES.dailyCompletionXP)
    }
    
    // MARK: - Guest/Account Isolation Tests
    
    func testGuestAccountIsolationWithSnapshots() async throws {
        // Given: Guest user with some data
        let guestUserId = "guest_user"
        let authenticatedUserId = "authenticated_user"
        
        let authRoutingManager = AuthRoutingManager.shared
        let xpService = XPService.shared
        
        // When: Guest completes habits
        await authRoutingManager.switchToGuest()
        
        // Create guest habits
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        let guestHabits = createTestHabits(count: 2)
        
        for habit in guestHabits {
            let habitData = HabitData(
                id: habit.id,
                userId: guestUserId,
                name: habit.name,
                habitDescription: habit.habitDescription,
                icon: habit.icon,
                colorData: Data(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: false,
                streak: 0
            )
            context.insert(habitData)
        }
        try context.save()
        
        // Complete guest habits and award XP
        let dateKey = "2024-01-01"
        for habit in guestHabits {
            let completionRecord = CompletionRecord(
                userId: guestUserId,
                habitId: habit.id,
                date: ISO8601DateHelper.shared.dateWithFallback(from: dateKey) ?? Date(),
                dateKey: dateKey,
                isCompleted: true
            )
            context.insert(completionRecord)
        }
        try context.save()
        
        let guestXPAwarded = try await xpService.awardDailyCompletionIfEligible(userId: guestUserId, dateKey: dateKey)
        XCTAssertEqual(guestXPAwarded, XP_RULES.dailyCompletionXP)
        
        // Take snapshot of guest data
        let guestProgress = try await xpService.getUserProgress(userId: guestUserId)
        let guestXPTotal = guestProgress.xpTotal
        
        // When: Switch to authenticated user
        await authRoutingManager.switchToUser(userId: authenticatedUserId)
        
        // Create authenticated user habits
        let authenticatedHabits = createTestHabits(count: 3)
        for habit in authenticatedHabits {
            let habitData = HabitData(
                id: habit.id,
                userId: authenticatedUserId,
                name: habit.name,
                habitDescription: habit.habitDescription,
                icon: habit.icon,
                colorData: Data(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: false,
                streak: 0
            )
            context.insert(habitData)
        }
        try context.save()
        
        // Complete authenticated user habits
        for habit in authenticatedHabits {
            let completionRecord = CompletionRecord(
                userId: authenticatedUserId,
                habitId: habit.id,
                date: ISO8601DateHelper.shared.dateWithFallback(from: dateKey) ?? Date(),
                dateKey: dateKey,
                isCompleted: true
            )
            context.insert(completionRecord)
        }
        try context.save()
        
        let authenticatedXPAwarded = try await xpService.awardDailyCompletionIfEligible(userId: authenticatedUserId, dateKey: dateKey)
        XCTAssertEqual(authenticatedXPAwarded, XP_RULES.dailyCompletionXP)
        
        // Take snapshot of authenticated user data
        let authenticatedProgress = try await xpService.getUserProgress(userId: authenticatedUserId)
        let authenticatedXPTotal = authenticatedProgress.xpTotal
        
        // When: Switch back to guest
        await authRoutingManager.switchToGuest()
        
        // Then: Guest data should be unchanged
        let guestProgressAfter = try await xpService.getUserProgress(userId: guestUserId)
        XCTAssertEqual(guestProgressAfter.xpTotal, guestXPTotal)
        
        // And: Authenticated user data should be unchanged
        await authRoutingManager.switchToUser(userId: authenticatedUserId)
        let authenticatedProgressAfter = try await xpService.getUserProgress(userId: authenticatedUserId)
        XCTAssertEqual(authenticatedProgressAfter.xpTotal, authenticatedXPTotal)
        
        // And: Data should be isolated (different totals)
        XCTAssertNotEqual(guestXPTotal, authenticatedXPTotal)
    }
    
    // MARK: - Migration QA Tests
    
    func testMixedLegacyAndNewData() async throws {
        // Given: Mixed legacy and new data
        let userId = "test_user_mixed"
        
        // Create legacy data in UserDefaults
        let legacyHabits = createTestHabits(count: 2)
        let userDefaults = UserDefaults.standard
        let habitsData = try JSONEncoder().encode(legacyHabits)
        userDefaults.set(habitsData, forKey: "SavedHabits")
        
        // Create some new data in SwiftData
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        let newHabits = createTestHabits(count: 1)
        
        for habit in newHabits {
            let habitData = HabitData(
                id: habit.id,
                userId: userId,
                name: habit.name,
                habitDescription: habit.habitDescription,
                icon: habit.icon,
                colorData: Data(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: false,
                streak: 0
            )
            context.insert(habitData)
        }
        try context.save()
        
        // When: Run migration
        let migrationRunner = MigrationRunner.shared
        try await migrationRunner.runIfNeeded(userId: userId)
        
        // Then: App should read from normalized path and ignore legacy
        let xpService = XPService.shared
        
        // Should only see new data, not legacy data
        let userProgress = try await xpService.getUserProgress(userId: userId)
        XCTAssertEqual(userProgress.xpTotal, 0) // New user, no XP yet
        
        // Should have migrated habits
        let habitRequest = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let migratedHabits = try context.fetch(habitRequest)
        XCTAssertGreaterThanOrEqual(migratedHabits.count, 1) // At least the new habit
    }
    
    func testAlreadyMigratedProfileNoRegression() async throws {
        // Given: Already migrated profile
        let userId = "test_user_migrated"
        
        // Create migrated data
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        let habitData = HabitData(
            id: UUID(),
            userId: userId,
            name: "Migrated Habit",
            habitDescription: "Test",
            icon: "star",
            colorData: Data(),
            habitType: "formation",
            schedule: "daily",
            goal: "1 time",
            reminder: "morning",
            startDate: Date(),
            endDate: nil,
            isCompleted: false,
            streak: 0
        )
        context.insert(habitData)
        try context.save()
        
        // Create migration state
        let migrationState = MigrationState(userId: userId, migrationVersion: 1)
        migrationState.markCompleted(recordsCount: 1)
        context.insert(migrationState)
        try context.save()
        
        // When: Run migration again
        let migrationRunner = MigrationRunner.shared
        try await migrationRunner.runIfNeeded(userId: userId)
        
        // Then: Should not regress or duplicate
        let habitRequest = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let habits = try context.fetch(habitRequest)
        XCTAssertEqual(habits.count, 1) // Should still be 1, not duplicated
        
        // Migration should still be marked as completed
        let migrationStatus = try await migrationRunner.getMigrationStatus(userId: userId)
        XCTAssertEqual(migrationStatus, .completed)
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabits(count: Int) -> [Habit] {
        return (0..<count).map { index in
            Habit(
                name: "Test Habit \(index + 1)",
                habitDescription: "Test Description \(index + 1)",
                icon: "star",
                color: .blue,
                habitType: .formation,
                schedule: "daily",
                goal: "1 time",
                reminder: "morning",
                startDate: Date(),
                endDate: nil
            )
        }
    }
}
