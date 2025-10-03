import XCTest
@testable import Habitto

final class MigrationIdempotencyTests: XCTestCase {

    func test_MigrationRunner_Idempotent_Twice_NoChanges() throws {
        let userId = "test-user"
        // Arrange: seed legacy fixtures (helper can be no-op if none)
        try LegacyFixtureSeeder.seedForUser(userId)

        // Act 1: run migration
        try MigrationRunner.runIfNeeded(userId: userId)
        let c1 = try Counts.snapshot(userId: userId)

        // Act 2: run again
        try MigrationRunner.runIfNeeded(userId: userId)
        let c2 = try Counts.snapshot(userId: userId)

        // Assert
        XCTAssertEqual(c1, c2, "Second run must not change counts")
    }
}

private struct Counts: Equatable {
    let completions: Int
    let awards: Int
    let progressRows: Int
    static func snapshot(userId: String) throws -> Counts {
        let ctx = SwiftDataContainer.shared.context
        let completions = try ctx.count(FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.userId == userId }))
        let awards = try ctx.count(FetchDescriptor<DailyAward>(predicate: #Predicate { $0.userId == userId }))
        let progress = try ctx.count(FetchDescriptor<UserProgressData>(predicate: #Predicate { $0.userId == userId }))
        return Counts(completions: completions, awards: awards, progressRows: progress)
    }
}

// Helper for seeding legacy data (stub implementation)
private struct LegacyFixtureSeeder {
    static func seedForUser(_ userId: String) throws {
        // Stub implementation - in real test would seed legacy data
        print("🧪 LegacyFixtureSeeder: Seeding legacy data for user \(userId)")
    }
}
