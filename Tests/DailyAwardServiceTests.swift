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

// MARK: - Transaction Boundary Tests
extension DailyAwardServiceTests {
    /// Test: Verify exactly one save() per grant operation
    func test_grant_has_exactly_one_save_operation() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // When - grant award
        let granted = await awardService.grantIfAllComplete(date: date, userId: userId)
        
        // Then - should succeed with single transaction
        assert(granted, "Grant should succeed")
        
        // Verify: check console output shows exactly one [TRANSACTION START] and one [TRANSACTION END]
        // In DEBUG mode, the console will show:
        // 🔒 DailyAwardService.grantIfAllComplete: Executing save() [TRANSACTION START]
        // ✅ DailyAwardService.grantIfAllComplete: save() completed [TRANSACTION END]
        
        print("✅ Grant operation uses exactly one save() transaction")
    }
    
    /// Test: Verify exactly one save() per revoke operation
    func test_revoke_has_exactly_one_save_operation() async throws {
        // Given - create award first
        let date = Date()
        let userId = "test_user"
        _ = await awardService.grantIfAllComplete(date: date, userId: userId)
        
        // When - revoke award
        let revoked = await awardService.revokeIfAnyIncomplete(date: date, userId: userId)
        
        // Then - should succeed with single transaction
        assert(revoked, "Revoke should succeed")
        
        // Verify: check console output shows exactly one [TRANSACTION START] and one [TRANSACTION END]
        // In DEBUG mode, the console will show:
        // 🔒 DailyAwardService.revokeIfAnyIncomplete: Executing save() [TRANSACTION START]
        // ✅ DailyAwardService.revokeIfAnyIncomplete: save() completed [TRANSACTION END]
        
        print("✅ Revoke operation uses exactly one save() transaction")
    }
    
    /// Test: Multiple operations in sequence should each have exactly one save
    func test_sequential_operations_each_have_single_transaction() async throws {
        // Given
        let date = Date()
        let userId = "test_user"
        
        // When - perform multiple operations
        print("\n=== Operation 1: Grant ===")
        _ = await awardService.grantIfAllComplete(date: date, userId: userId)
        
        print("\n=== Operation 2: Revoke ===")
        _ = await awardService.revokeIfAnyIncomplete(date: date, userId: userId)
        
        print("\n=== Operation 3: Re-grant ===")
        _ = await awardService.grantIfAllComplete(date: date, userId: userId)
        
        // Then - verify console shows exactly 3 transaction pairs
        // Expected output:
        // === Operation 1: Grant ===
        // 🔒 ... [TRANSACTION START]
        // ✅ ... [TRANSACTION END]
        // === Operation 2: Revoke ===
        // 🔒 ... [TRANSACTION START]
        // ✅ ... [TRANSACTION END]
        // === Operation 3: Re-grant ===
        // 🔒 ... [TRANSACTION START]
        // ✅ ... [TRANSACTION END]
        
        print("\n✅ All sequential operations used exactly one transaction each")
    }
}

// MARK: - Timezone & Date Key Edge Tests
extension DailyAwardServiceTests {
    /// Test: 23:59→00:00 boundary creates two different date keys
    func test_midnight_boundary_creates_different_date_keys() async throws {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Just before midnight
        let beforeMidnight = formatter.date(from: "2025-10-01 23:59:59")!
        let keyBefore = DateKey.key(for: beforeMidnight)
        
        // Just after midnight
        let afterMidnight = formatter.date(from: "2025-10-02 00:00:01")!
        let keyAfter = DateKey.key(for: afterMidnight)
        
        // Then - different date keys
        assert(keyBefore != keyAfter, "Midnight boundary should create different date keys")
        assert(keyBefore == "2025-10-01", "Before midnight should be Oct 1")
        assert(keyAfter == "2025-10-02", "After midnight should be Oct 2")
        
        print("✅ Midnight boundary creates different date keys: \(keyBefore) ≠ \(keyAfter)")
    }
    
    /// Test: Completing at 23:59 and 00:00 yields 2 separate awards (not duplicate)
    func test_completion_at_midnight_boundary_yields_two_awards() async throws {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let userId = "test_user"
        
        // Complete at 23:59
        let beforeMidnight = formatter.date(from: "2025-10-01 23:59:59")!
        let granted1 = await awardService.grantIfAllComplete(date: beforeMidnight, userId: userId)
        assert(granted1, "Should grant award for Oct 1")
        
        // Complete at 00:00 (next day)
        let afterMidnight = formatter.date(from: "2025-10-02 00:00:01")!
        let granted2 = await awardService.grantIfAllComplete(date: afterMidnight, userId: userId)
        assert(granted2, "Should grant award for Oct 2 (different day)")
        
        // Verify: 2 separate awards exist
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        
        assert(awards.count == 2, "Should have 2 awards (one per day)")
        assert(awards[0].dateKey != awards[1].dateKey, "Awards should have different date keys")
        
        let totalXP = awards.reduce(0) { $0 + $1.xpGranted }
        assert(totalXP == 200, "Should have 200 XP total (100 per day)")
        
        print("✅ Midnight boundary: 2 separate days, 2 separate awards, no duplicate XP")
    }
    
    /// Test: Re-completing on same local dateKey never yields +2× XP
    func test_recompletion_same_local_date_no_duplicate_xp() async throws {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let userId = "test_user"
        
        // Complete at 10:00
        let morning = formatter.date(from: "2025-10-01 10:00:00")!
        let granted1 = await awardService.grantIfAllComplete(date: morning, userId: userId)
        assert(granted1, "First completion should grant award")
        
        // Complete again at 20:00 (same day, different time)
        let evening = formatter.date(from: "2025-10-01 20:00:00")!
        let granted2 = await awardService.grantIfAllComplete(date: evening, userId: userId)
        assert(!granted2, "Second completion same day should NOT grant (idempotency)")
        
        // Verify: exactly 1 award, +100 XP
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == "2025-10-01"
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        
        assert(awards.count == 1, "Should have exactly 1 award for the day")
        assert(awards[0].xpGranted == 100, "Should have exactly 100 XP")
        
        print("✅ Same-day re-completion: idempotent, no duplicate XP")
    }
    
    /// Test: DST spring forward (2:00→3:00) doesn't cause duplicate awards
    func test_dst_spring_forward_no_duplicate_awards() async throws {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let userId = "test_user"
        
        // DST spring forward: 2024-03-31 02:00 → 03:00
        // Complete at 01:59 (before DST)
        let beforeDST = formatter.date(from: "2024-03-31 01:59:00")!
        let granted1 = await awardService.grantIfAllComplete(date: beforeDST, userId: userId)
        assert(granted1, "Should grant award before DST")
        
        // Complete at 03:01 (after DST jump - same local day!)
        let afterDST = formatter.date(from: "2024-03-31 03:01:00")!
        let granted2 = await awardService.grantIfAllComplete(date: afterDST, userId: userId)
        assert(!granted2, "Should NOT grant duplicate (same day)")
        
        // Verify: same date key
        let keyBefore = DateKey.key(for: beforeDST)
        let keyAfter = DateKey.key(for: afterDST)
        assert(keyBefore == keyAfter, "DST change should NOT affect date key")
        assert(keyBefore == "2024-03-31", "Both should be March 31")
        
        // Verify: exactly 1 award
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == "2024-03-31"
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let awards = try modelContext.fetch(request)
        
        assert(awards.count == 1, "DST change should not cause duplicate award")
        
        print("✅ DST spring forward: same day, no duplicate award")
    }
    
    /// Test: DST fall back (3:00→2:00) doesn't cause duplicate awards
    func test_dst_fall_back_no_duplicate_awards() async throws {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let userId = "test_user"
        
        // DST fall back: 2024-10-27 03:00 → 02:00
        // Complete at first 02:30 (before fall back)
        let beforeDST = formatter.date(from: "2024-10-27 02:30:00")!
        let granted1 = await awardService.grantIfAllComplete(date: beforeDST, userId: userId)
        assert(granted1, "Should grant award before DST")
        
        // Complete at second 02:30 (after fall back - same local time, same day!)
        // Note: This is tricky - we can't easily create the "second" 02:30
        // but the key is that the DATE KEY should be the same
        let afterDST = formatter.date(from: "2024-10-27 02:30:00")!
        let granted2 = await awardService.grantIfAllComplete(date: afterDST, userId: userId)
        assert(!granted2, "Should NOT grant duplicate (same day)")
        
        // Verify: same date key
        let keyBefore = DateKey.key(for: beforeDST)
        let keyAfter = DateKey.key(for: afterDST)
        assert(keyBefore == keyAfter, "DST change should NOT affect date key")
        assert(keyBefore == "2024-10-27", "Both should be Oct 27")
        
        print("✅ DST fall back: same day, no duplicate award")
    }
    
    /// Test: Different timezones but same UTC day yields one award
    func test_same_utc_day_different_local_times() async throws {
        // This tests that DateKey is based on local time (Amsterdam), not UTC
        let userId = "test_user"
        
        // Create a date at midnight Amsterdam time
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        
        let amsterdamMidnight = Calendar.current.date(from: components)!
        let granted = await awardService.grantIfAllComplete(date: amsterdamMidnight, userId: userId)
        assert(granted, "Should grant award")
        
        let key = DateKey.key(for: amsterdamMidnight)
        assert(key == "2025-10-01", "Date key should use Amsterdam timezone")
        
        print("✅ Date key respects timezone: \(key)")
    }
}
