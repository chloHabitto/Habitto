import Foundation
import SwiftData

@MainActor
final class DailyAwardServiceTests {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var awardService: DailyAwardService!
    
    func setUp() async throws {
        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: DailyAward.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
        awardService = DailyAwardService(modelContext: modelContext)
    }
    
    func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        awardService = nil
    }
    
    // MARK: - Unit Tests
    
    func testGrantAwardOnce() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // When
        let result = await awardService.onHabitCompleted(date: date, userId: userId)
        
        // Then
        assert(result, "Should grant award when all habits completed")
        
        // Verify award was created
        let dateKey = DateKey.key(for: date)
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        assert(awards.count == 1, "Should create exactly one award")
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
        assert(result1, "First call should grant award")
        assert(!result2, "Second call should not grant award (idempotency)")
        assert(!result3, "Third call should not grant award (idempotency)")
        
        // Verify only one award exists
        let dateKey = DateKey.key(for: date)
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        assert(awards.count == 1, "Should create exactly one award")
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
        let dateKey = DateKey.key(for: date)
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        assert(awards.count == 0, "Award should be revoked")
    }
    
    func testReGrantAfterReComplete() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // Grant award
        let result1 = await awardService.onHabitCompleted(date: date, userId: userId)
        assert(result1)
        
        // Revoke award
        await awardService.onHabitUncompleted(date: date, userId: userId)
        
        // When - re-complete
        let result2 = await awardService.onHabitCompleted(date: date, userId: userId)
        
        // Then
        assert(result2, "Should re-grant award after re-completion")
        
        // Verify exactly one award exists
        let dateKey = DateKey.key(for: date)
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        assert(awards.count == 1, "Should have exactly one award")
    }
    
    func testTimezoneBoundaries() async throws {
        // Test DST transition dates
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // DST start (2024-03-31 02:00:00)
        let dstStart = formatter.date(from: "2024-03-31 02:00:00")!
        let result1 = await awardService.onHabitCompleted(date: dstStart, userId: "test_user")
        assert(result1)
        
        // DST end (2024-10-27 02:00:00)
        let dstEnd = formatter.date(from: "2024-10-27 02:00:00")!
        let result2 = await awardService.onHabitCompleted(date: dstEnd, userId: "test_user")
        assert(result2)
        
        // Verify different date keys
        let key1 = DateKey.key(for: dstStart)
        let key2 = DateKey.key(for: dstEnd)
        assert(key1 != key2, "Different dates should have different keys")
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
        
        assert(key1 != key2, "Midnight boundary should create different date keys")
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
        assert(awards.count <= 1, "Should never have more than one award per (userId, dateKey)")
    }
}

// MARK: - Concurrency Tests
extension DailyAwardServiceTests {
    /// Test: 20 concurrent grantIfAllComplete calls should result in exactly 1 award
    func test_award_idempotent_under_concurrent_grants() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        let dateKey = DateKey.key(for: date)
        
        // Capture initial state
        let initialPredicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let initialRequest = FetchDescriptor<DailyAward>(predicate: initialPredicate)
        let initialAwards = try modelContext.fetch(initialRequest)
        let initialCount = initialAwards.count
        let initialXP = initialAwards.reduce(0) { $0 + $1.xpGranted }
        
        // When - spawn 20 concurrent grant calls
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await self.awardService.grantIfAllComplete(date: date, userId: userId)
                }
            }
            
            // Wait for all tasks to complete
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            
            // Then - exactly one should succeed
            let successCount = results.filter { $0 }.count
            print("✅ Concurrent grants: \(successCount) succeeded out of 20 attempts")
        }
        
        // Verify exactly one award exists
        let finalPredicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let finalRequest = FetchDescriptor<DailyAward>(predicate: finalPredicate)
        let finalAwards = try modelContext.fetch(finalRequest)
        let finalXP = finalAwards.reduce(0) { $0 + $1.xpGranted }
        
        assert(finalAwards.count == initialCount + 1, 
               "❌ CONCURRENCY BUG: Expected exactly 1 award, got \(finalAwards.count - initialCount)")
        assert(finalXP == initialXP + 100, 
               "❌ CONCURRENCY BUG: XP should increase by exactly 100, got +\(finalXP - initialXP)")
        
        print("✅ Concurrency test passed: 1 award, +100 XP")
    }
    
    /// Test: Revoke then concurrent grants should result in net 1 award
    func test_revoke_then_concurrent_grants_is_net_one_award() async throws {
        // Given - create initial award
        let date = Date()
        let userId = "test_user"
        let dateKey = DateKey.key(for: date)
        
        _ = await awardService.grantIfAllComplete(date: date, userId: userId)
        
        // Revoke it
        _ = await awardService.revokeIfAnyIncomplete(date: date, userId: userId)
        
        // Capture state after revoke
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awardsAfterRevoke = try modelContext.fetch(request)
        assert(awardsAfterRevoke.count == 0, "Award should be revoked")
        
        // When - spawn 20 concurrent grant calls after revoke
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await self.awardService.grantIfAllComplete(date: date, userId: userId)
                }
            }
            
            // Wait for all to complete
            for await _ in group {}
        }
        
        // Then - exactly one award should exist
        let finalAwards = try modelContext.fetch(request)
        assert(finalAwards.count == 1, 
               "❌ CONCURRENCY BUG: After revoke+concurrent grants, expected 1 award, got \(finalAwards.count)")
        
        print("✅ Revoke+concurrent test passed: net 1 award")
    }
    
    /// Test: Complete→Uncomplete→Recomplete same day should net exactly +100 XP (not double)
    func test_complete_uncomplete_recomplete_same_day_no_duplicate_xp() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        let dateKey = DateKey.key(for: date)
        
        // Capture initial XP
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let initialAwards = try modelContext.fetch(request)
        let initialTotalXP = initialAwards.reduce(0) { $0 + $1.xpGranted }
        
        // Step 1: Mark all habits complete → grant award → expect +100 XP
        let granted1 = await awardService.grantIfAllComplete(date: date, userId: userId)
        assert(granted1, "Step 1: Should grant award")
        
        let afterGrant1 = try modelContext.fetch(request)
        let xpAfterGrant1 = afterGrant1.reduce(0) { $0 + $1.xpGranted }
        assert(xpAfterGrant1 == initialTotalXP + 100, 
               "Step 1: XP should be +100, got +\(xpAfterGrant1 - initialTotalXP)")
        
        // Step 2: Uncomplete one habit → revoke award → expect XP baseline
        let revoked = await awardService.revokeIfAnyIncomplete(date: date, userId: userId)
        assert(revoked, "Step 2: Should revoke award")
        
        let afterRevoke = try modelContext.fetch(request)
        let xpAfterRevoke = afterRevoke.reduce(0) { $0 + $1.xpGranted }
        assert(xpAfterRevoke == initialTotalXP, 
               "Step 2: XP should return to baseline, got \(xpAfterRevoke)")
        
        // Step 3: Complete that habit again (all complete) → grant → expect exactly +100 total (NOT +200)
        let granted2 = await awardService.grantIfAllComplete(date: date, userId: userId)
        assert(granted2, "Step 3: Should re-grant award")
        
        let finalAwards = try modelContext.fetch(request)
        let finalTotalXP = finalAwards.reduce(0) { $0 + $1.xpGranted }
        assert(finalTotalXP == initialTotalXP + 100, 
               "❌ DUPLICATE XP BUG: Expected net +100 XP, got +\(finalTotalXP - initialTotalXP)")
        
        // Verify exactly one award for today
        let todayPredicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        let todayRequest = FetchDescriptor<DailyAward>(predicate: todayPredicate)
        let todayAwards = try modelContext.fetch(todayRequest)
        assert(todayAwards.count == 1, 
               "❌ DUPLICATE AWARD BUG: Expected 1 award for today, got \(todayAwards.count)")
        
        print("✅ Complete→Uncomplete→Recomplete test passed: net +100 XP, 1 award")
    }
}
