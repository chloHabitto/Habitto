import XCTest
import SwiftData
@testable import Habitto

final class MigrationIdempotencyTests: XCTestCase {
    
    func test_migrationIdempotency_runTwice_noDuplicateRecords() async throws {
        let userId = "test_user_migration"
        let context = ModelContext(inMemoryStore)
        
        // First migration run
        print("🔄 Running first migration...")
        try await MigrationRunner.shared.runIfNeeded(userId: userId)
        
        // Count records after first run
        let completionRequest1 = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let completions1 = try context.fetch(completionRequest1)
        
        let dailyAwardRequest1 = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId }
        )
        let dailyAwards1 = try context.fetch(dailyAwardRequest1)
        
        let userProgressRequest1 = FetchDescriptor<UserProgressData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let userProgress1 = try context.fetch(userProgressRequest1)
        
        print("📊 After first migration:")
        print("  Completions: \(completions1.count)")
        print("  Daily Awards: \(dailyAwards1.count)")
        print("  User Progress: \(userProgress1.count)")
        
        // Second migration run
        print("🔄 Running second migration...")
        try await MigrationRunner.shared.runIfNeeded(userId: userId)
        
        // Count records after second run
        let completionRequest2 = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let completions2 = try context.fetch(completionRequest2)
        
        let dailyAwardRequest2 = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId }
        )
        let dailyAwards2 = try context.fetch(dailyAwardRequest2)
        
        let userProgressRequest2 = FetchDescriptor<UserProgressData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let userProgress2 = try context.fetch(userProgressRequest2)
        
        print("📊 After second migration:")
        print("  Completions: \(completions2.count)")
        print("  Daily Awards: \(dailyAwards2.count)")
        print("  User Progress: \(userProgress2.count)")
        
        // Verify no duplicate records were created
        XCTAssertEqual(completions1.count, completions2.count, "Completion count should not change on second migration")
        XCTAssertEqual(dailyAwards1.count, dailyAwards2.count, "Daily award count should not change on second migration")
        XCTAssertEqual(userProgress1.count, userProgress2.count, "User progress count should not change on second migration")
        
        print("✅ Migration idempotency test passed - no duplicate records created")
    }
    
    func test_migrationIdempotency_withExistingData_noDuplicates() async throws {
        let userId = "test_user_existing"
        let context = ModelContext(inMemoryStore)
        
        // Pre-create some data
        let habitId = UUID()
        let dateKey = "2025-01-01"
        
        let existingCompletion = CompletionRecord(
            userId: userId,
            habitId: habitId,
            date: Date(),
            dateKey: dateKey,
            isCompleted: true
        )
        context.insert(existingCompletion)
        
        let existingDailyAward = DailyAward(
            userId: userId,
            date: Date(),
            dateKey: dateKey,
            allHabitsCompleted: true,
            xpAwarded: 100
        )
        context.insert(existingDailyAward)
        
        let existingUserProgress = UserProgressData(userId: userId)
        existingUserProgress.xpTotal = 500
        existingUserProgress.level = 2
        context.insert(existingUserProgress)
        
        try context.save()
        
        print("📊 Pre-existing data:")
        print("  Completions: 1")
        print("  Daily Awards: 1")
        print("  User Progress: 1")
        
        // Run migration
        print("🔄 Running migration with existing data...")
        try await MigrationRunner.shared.runIfNeeded(userId: userId)
        
        // Count records after migration
        let completionRequest = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let completions = try context.fetch(completionRequest)
        
        let dailyAwardRequest = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId }
        )
        let dailyAwards = try context.fetch(dailyAwardRequest)
        
        let userProgressRequest = FetchDescriptor<UserProgressData>(
            predicate: #Predicate { $0.userId == userId }
        )
        let userProgress = try context.fetch(userProgressRequest)
        
        print("📊 After migration:")
        print("  Completions: \(completions.count)")
        print("  Daily Awards: \(dailyAwards.count)")
        print("  User Progress: \(userProgress.count)")
        
        // Verify existing data was preserved and no duplicates created
        XCTAssertEqual(completions.count, 1, "Should preserve existing completion record")
        XCTAssertEqual(dailyAwards.count, 1, "Should preserve existing daily award")
        XCTAssertEqual(userProgress.count, 1, "Should preserve existing user progress")
        
        print("✅ Migration with existing data test passed - no duplicates created")
    }
}
