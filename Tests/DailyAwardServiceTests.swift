import XCTest
import SwiftData
@testable import Habitto

@MainActor
final class DailyAwardServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var awardService: DailyAwardService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: DailyAward.self, Habit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
        awardService = DailyAwardService(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        awardService = nil
        try await super.tearDown()
    }
    
    // MARK: - Unit Tests
    
    func testGrantAwardOnce() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // When
        let result = await awardService.onHabitCompleted(date: date, userId: userId)
        
        // Then
        XCTAssertTrue(result, "Should grant award when all habits completed")
        
        // Verify award was created
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == DateKey.key(for: date)
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        XCTAssertEqual(awards.count, 1, "Should create exactly one award")
    }
    
    func testIdempotency() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // When - call multiple times
        let result1 = await awardService.onHabitCompleted(date: date, userId: userId)
        let result2 = await awardService.onHabitCompleted(date: date, userId: userId)
        let result3 = await awardService.onHabitCompleted(date: date, userId: userId)
        
        // Then
        XCTAssertTrue(result1, "First call should grant award")
        XCTAssertFalse(result2, "Second call should not grant award (idempotency)")
        XCTAssertFalse(result3, "Third call should not grant award (idempotency)")
        
        // Verify only one award exists
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == DateKey.key(for: date)
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        XCTAssertEqual(awards.count, 1, "Should create exactly one award")
    }
    
    func testRevokeAwardOnUncomplete() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // Grant award first
        _ = await awardService.onHabitCompleted(date: date, userId: userId)
        
        // When - uncomplete habit
        await awardService.onHabitUncompleted(date: date, userId: userId)
        
        // Then - award should be revoked
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == DateKey.key(for: date)
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        XCTAssertEqual(awards.count, 0, "Award should be revoked")
    }
    
    func testReGrantAfterReComplete() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // Grant award
        let result1 = await awardService.onHabitCompleted(date: date, userId: userId)
        XCTAssertTrue(result1)
        
        // Revoke award
        await awardService.onHabitUncompleted(date: date, userId: userId)
        
        // When - re-complete
        let result2 = await awardService.onHabitCompleted(date: date, userId: userId)
        
        // Then
        XCTAssertTrue(result2, "Should re-grant award after re-completion")
        
        // Verify exactly one award exists
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == DateKey.key(for: date)
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        XCTAssertEqual(awards.count, 1, "Should have exactly one award")
    }
    
    func testTimezoneBoundaries() async throws {
        // Test DST transition dates
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // DST start (2024-03-31 02:00:00)
        let dstStart = formatter.date(from: "2024-03-31 02:00:00")!
        let result1 = await awardService.onHabitCompleted(date: dstStart, userId: "test_user")
        XCTAssertTrue(result1)
        
        // DST end (2024-10-27 02:00:00)
        let dstEnd = formatter.date(from: "2024-10-27 02:00:00")!
        let result2 = await awardService.onHabitCompleted(date: dstEnd, userId: "test_user")
        XCTAssertTrue(result2)
        
        // Verify different date keys
        let key1 = DateKey.key(for: dstStart)
        let key2 = DateKey.key(for: dstEnd)
        XCTAssertNotEqual(key1, key2, "Different dates should have different keys")
    }
    
    func testMidnightBoundaries() async throws {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Just before midnight
        let justBeforeMidnight = formatter.date(from: "2024-03-31 23:59:59")!
        let key1 = DateKey.key(for: justBeforeMidnight)
        
        // Just after midnight
        let justAfterMidnight = formatter.date(from: "2024-04-01 00:00:01")!
        let key2 = DateKey.key(for: justAfterMidnight)
        
        XCTAssertNotEqual(key1, key2, "Midnight boundary should create different date keys")
    }
}

// MARK: - Property Tests
extension DailyAwardServiceTests {
    func testPropertyIdempotency() async throws {
        // Test random toggle sequences never yield >1 award per (userId, dateKey)
        let userId = "test_user"
        let date = Date()
        let dateKey = DateKey.key(for: date)
        
        // Simulate random completion/uncompletion
        for _ in 0..<100 {
            let shouldComplete = Bool.random()
            
            if shouldComplete {
                _ = await awardService.onHabitCompleted(date: date, userId: userId)
            } else {
                await awardService.onHabitUncompleted(date: date, userId: userId)
            }
        }
        
        // Verify at most one award exists
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        XCTAssertLessThanOrEqual(awards.count, 1, "Should never have more than one award per (userId, dateKey)")
    }
}
