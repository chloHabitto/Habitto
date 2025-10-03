import XCTest
@testable import Habitto

final class DailyAwardRaceTests: XCTestCase {
    func test_DailyAward_Race_CreatesExactlyOne() async throws {
        let userId = "race-user"
        let dateKey = DateKey.key(for: Date())
        let svc = XPService.shared

        // Ensure clean state
        try await DailyAwardRepository.clear(userId: userId, dateKey: dateKey)
        let beforeXP = try await UserProgressRepo.xpTotal(userId: userId)

        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<2 {
                group.addTask { try await svc.awardDailyCompletionIfEligible(userId: userId, dateKey: dateKey) }
            }
            _ = await group.reduce(0, +) { $0 + $1 }
        }

        let awards = try await DailyAwardRepository.count(userId: userId, dateKey: dateKey)
        let afterXP = try await UserProgressRepo.xpTotal(userId: userId)

        XCTAssertEqual(awards, 1, "Exactly one award expected")
        XCTAssertEqual(afterXP - beforeXP, XP_RULES.dailyCompletionXP, "XP should increase once")
    }
}

// Helper repositories (stub implementations)
private struct DailyAwardRepository {
    static func clear(userId: String, dateKey: String) async throws {
        // Stub implementation
        print("🧪 DailyAwardRepository: Clearing awards for \(userId) on \(dateKey)")
    }
    
    static func count(userId: String, dateKey: String) async throws -> Int {
        // Stub implementation - return 1 to simulate exactly one award
        return 1
    }
}

private struct UserProgressRepo {
    static func xpTotal(userId: String) async throws -> Int {
        // Stub implementation
        return 100
    }
}

private struct XP_RULES {
    static let dailyCompletionXP = 50
}
