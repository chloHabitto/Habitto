import XCTest
import SwiftData
@testable import Habitto

// MARK: - Phase 3 Integration Tests
/// Tests for Phase 3: Migrations + feature-flagged routing
class Phase3IntegrationTests: XCTestCase {
    
    var testFeatureFlags: TestFeatureFlagProvider!
    var authRoutingManager: AuthRoutingManager!
    var migrationRunner: MigrationRunner!
    
    override func setUp() {
        super.setUp()
        
        // Set up test feature flags
        testFeatureFlags = TestFeatureFlagProvider()
        FeatureFlagManager.shared.setTestProvider(testFeatureFlags)
        
        // Set up auth routing manager with test flags
        authRoutingManager = AuthRoutingManager(featureFlags: testFeatureFlags)
        
        // Set up migration runner with test flags
        migrationRunner = MigrationRunner(featureFlags: testFeatureFlags)
    }
    
    override func tearDown() {
        // Clean up
        FeatureFlagManager.shared.resetToDefault()
        authRoutingManager.clearAllCaches()
        
        super.tearDown()
    }
    
    // MARK: - Unit Tests
    
    func testMigrationIdempotency() async throws {
        // Given: Legacy data exists
        let userId = "test_user_1"
        let testHabits = createTestHabits()
        await storeLegacyHabits(testHabits)
        
        // When: Run migration twice
        testFeatureFlags.enableAllDataImprovements()
        
        try await migrationRunner.runIfNeeded(userId: userId)
        let firstRunStatus = try await migrationRunner.getMigrationStatus(userId: userId)
        
        try await migrationRunner.runIfNeeded(userId: userId)
        let secondRunStatus = try await migrationRunner.getMigrationStatus(userId: userId)
        
        // Then: Migration should be idempotent
        XCTAssertEqual(firstRunStatus, .completed)
        XCTAssertEqual(secondRunStatus, .completed)
        
        // And: Data should be consistent
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        let habitRequest = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let migratedHabits = try context.fetch(habitRequest)
        
        XCTAssertEqual(migratedHabits.count, testHabits.count)
    }
    
    func testMigrationParity() async throws {
        // Given: Legacy data with specific completion history
        let userId = "test_user_2"
        let testHabits = createTestHabitsWithCompletion()
        await storeLegacyHabits(testHabits)
        
        // When: Run migration
        testFeatureFlags.enableAllDataImprovements()
        try await migrationRunner.runIfNeeded(userId: userId)
        
        // Then: New tables should reflect same facts
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        
        // Check habits
        let habitRequest = FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let migratedHabits = try context.fetch(habitRequest)
        XCTAssertEqual(migratedHabits.count, testHabits.count)
        
        // Check completion records
        let completionRequest = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let completionRecords = try context.fetch(completionRequest)
        XCTAssertGreaterThan(completionRecords.count, 0)
        
        // Check user progress
        let progressRequest = FetchDescriptor<UserProgress>(
            predicate: #Predicate { $0.userId == userId }
        )
        let userProgress = try context.fetch(progressRequest)
        XCTAssertEqual(userProgress.count, 1)
    }
    
    func testXPServiceIdempotency() async throws {
        // Given: XPService with feature flags enabled
        testFeatureFlags.enableAllDataImprovements()
        
        let xpService = XPService.shared
        let userId = "test_user_3"
        let dateKey = "2024-01-01"
        
        // When: Call awardDailyCompletionIfEligible twice
        let firstResult = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
        let secondResult = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey)
        
        // Then: Second call should return 0 (no double grant)
        XCTAssertGreaterThan(firstResult, 0)
        XCTAssertEqual(secondResult, 0)
        
        // And: Only one daily award should exist
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        let awardRequest = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId && $0.dateKey == dateKey }
        )
        let awards = try context.fetch(awardRequest)
        XCTAssertEqual(awards.count, 1)
    }
    
    // MARK: - Integration Tests
    
    func testGuestAccountIsolation() async throws {
        // Given: Guest user with some data
        testFeatureFlags.enableAllDataImprovements()
        
        await authRoutingManager.switchToGuest()
        let guestProvider = authRoutingManager.currentRepositoryProvider
        
        // Create some guest data
        let guestHabits = createTestHabits()
        try await guestProvider.habitRepository.saveHabits(guestHabits)
        
        // When: Switch to authenticated user
        let userId = "authenticated_user"
        await authRoutingManager.switchToUser(userId: userId)
        let userProvider = authRoutingManager.currentRepositoryProvider
        
        // Then: User should not see guest data
        let userHabits = try await userProvider.habitRepository.loadHabits()
        XCTAssertEqual(userHabits.count, 0)
        
        // And: Guest data should still exist
        await authRoutingManager.switchToGuest()
        let guestHabitsAfter = try await authRoutingManager.currentRepositoryProvider.habitRepository.loadHabits()
        XCTAssertEqual(guestHabitsAfter.count, guestHabits.count)
    }
    
    func testRepositoryReinitialization() async throws {
        // Given: Feature flags enabled
        testFeatureFlags.enableAllDataImprovements()
        
        let userId = "test_user_4"
        
        // When: Switch to user
        await authRoutingManager.switchToUser(userId: userId)
        
        // Then: Repository should be reinitialized
        let provider = authRoutingManager.currentRepositoryProvider
        XCTAssertNotNil(provider)
        
        // And: Migration should have run
        let migrationStatus = try await migrationRunner.getMigrationStatus(userId: userId)
        XCTAssertEqual(migrationStatus, .completed)
    }
    
    func testFeatureFlagToggle() async throws {
        // Given: Feature flags disabled (legacy path)
        testFeatureFlags.disableAllDataImprovements()
        
        let userId = "test_user_5"
        await authRoutingManager.switchToUser(userId: userId)
        
        let legacyProvider = authRoutingManager.currentRepositoryProvider
        XCTAssertTrue(legacyProvider.habitRepository is LegacyHabitRepository)
        
        // When: Enable feature flags
        testFeatureFlags.enableAllDataImprovements()
        await authRoutingManager.updateFeatureFlags()
        
        // Then: Should switch to normalized path
        let normalizedProvider = authRoutingManager.currentRepositoryProvider
        XCTAssertTrue(normalizedProvider.habitRepository is NormalizedHabitRepository)
    }
    
    // MARK: - Invariant Tests
    
    func testInvariantWithFeatureFlagOn() async throws {
        // Given: Feature flags enabled
        testFeatureFlags.enableAllDataImprovements()
        
        let userId = "test_user_6"
        await authRoutingManager.switchToUser(userId: userId)
        
        let provider = authRoutingManager.currentRepositoryProvider
        
        // When: Try to mutate XP through XPService
        let xpService = provider.xpService
        let result = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: "2024-01-01")
        
        // Then: Should work (no violation)
        XCTAssertGreaterThanOrEqual(result, 0)
    }
    
    func testInvariantWithFeatureFlagOff() async throws {
        // Given: Feature flags disabled
        testFeatureFlags.disableAllDataImprovements()
        
        let userId = "test_user_7"
        await authRoutingManager.switchToUser(userId: userId)
        
        let provider = authRoutingManager.currentRepositoryProvider
        
        // When: Try to mutate XP through legacy service
        let xpService = provider.xpService
        let result = try await xpService.awardDailyCompletionIfEligible(userId: userId, dateKey: "2024-01-01")
        
        // Then: Should work (legacy path allowed)
        XCTAssertGreaterThanOrEqual(result, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabits() -> [Habit] {
        return [
            Habit(
                name: "Test Habit 1",
                habitDescription: "Test Description 1",
                icon: "star",
                color: .blue,
                habitType: .formation,
                schedule: "daily",
                goal: "1 time",
                reminder: "morning",
                startDate: Date(),
                endDate: nil
            ),
            Habit(
                name: "Test Habit 2",
                habitDescription: "Test Description 2",
                icon: "heart",
                color: .red,
                habitType: .formation,
                schedule: "daily",
                goal: "1 time",
                reminder: "evening",
                startDate: Date(),
                endDate: nil
            )
        ]
    }
    
    private func createTestHabitsWithCompletion() -> [Habit] {
        var habits = createTestHabits()
        
        // Add completion history to first habit
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let dateKey1 = DateKey.key(for: today)
        let dateKey2 = DateKey.key(for: yesterday)
        
        habits[0].completionHistory[dateKey1] = 1
        habits[0].completionHistory[dateKey2] = 1
        
        return habits
    }
    
    private func storeLegacyHabits(_ habits: [Habit]) async {
        let userDefaults = UserDefaults.standard
        let habitsData = try! JSONEncoder().encode(habits)
        userDefaults.set(habitsData, forKey: "SavedHabits")
    }
}

// MARK: - Phase 3 Unit Tests
class Phase3UnitTests: XCTestCase {
    
    var testFeatureFlags: TestFeatureFlagProvider!
    
    override func setUp() {
        super.setUp()
        testFeatureFlags = TestFeatureFlagProvider()
        FeatureFlagManager.shared.setTestProvider(testFeatureFlags)
    }
    
    override func tearDown() {
        FeatureFlagManager.shared.resetToDefault()
        super.tearDown()
    }
    
    func testFeatureFlagValidation() {
        // Given: Invalid feature flag combination
        testFeatureFlags.useCentralizedXP = true
        testFeatureFlags.useNormalizedDataPath = false
        
        // When: Validate configuration
        let warnings = FeatureFlags.validateConfiguration()
        
        // Then: Should get warning
        XCTAssertFalse(warnings.isEmpty)
        XCTAssertTrue(warnings.contains { $0.contains("useCentralizedXP requires useNormalizedDataPath") })
    }
    
    func testMigrationStateManagement() async throws {
        // Given: Migration state
        let context = ModelContext(SwiftDataContainer.shared.modelContainer)
        let userId = "test_user_8"
        
        // When: Create migration state
        let migrationState = MigrationState(
            userId: userId,
            migrationVersion: 1
        )
        context.insert(migrationState)
        try context.save()
        
        // Then: Should be able to find it
        let foundState = try MigrationState.findForUser(userId: userId, in: context)
        XCTAssertNotNil(foundState)
        XCTAssertEqual(foundState?.userId, userId)
        XCTAssertEqual(foundState?.status, .pending)
    }
    
    func testRepositoryProviderCreation() {
        // Given: Feature flags
        testFeatureFlags.enableAllDataImprovements()
        
        // When: Create repository provider
        let provider = RepositoryProvider(featureFlags: testFeatureFlags)
        
        // Then: Should create normalized repositories
        XCTAssertTrue(provider.habitRepository is NormalizedHabitRepository)
        XCTAssertTrue(provider.xpService is XPService)
    }
    
    func testLegacyRepositoryProviderCreation() {
        // Given: Feature flags disabled
        testFeatureFlags.disableAllDataImprovements()
        
        // When: Create repository provider
        let provider = RepositoryProvider(featureFlags: testFeatureFlags)
        
        // Then: Should create legacy repositories
        XCTAssertTrue(provider.habitRepository is LegacyHabitRepository)
        XCTAssertTrue(provider.xpService is LegacyXPService)
    }
}
