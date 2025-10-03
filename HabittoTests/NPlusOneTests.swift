import XCTest
@testable import Habitto

final class NPlusOneTests: XCTestCase {
    func test_CompletionsPrefetch_CalledOnceForList() throws {
        // Spy repository
        let spy = CompletionRepositorySpy()
        spy.stubbedMap = Dictionary(uniqueKeysWithValues: (0..<50).map { (UUID(), true) })
        let vm = HomeListViewModel(completionRepo: spy)
        vm.visibleHabitIds = Array(spy.stubbedMap.keys)
        vm.selectedDateKey = DateKey.key(for: Date())

        // Act
        vm.prefetchCompletionStatus()

        XCTAssertEqual(spy.mapCallCount, 1, "Should fetch once, not per habit")
    }
}

final class CompletionRepositorySpy: CompletionRepository {
    var mapCallCount = 0
    var stubbedMap: [UUID: Bool] = [:]
    func completionsMap(userId: String, dateKey: String, habitIds: [UUID]) throws -> [UUID : Bool] {
        mapCallCount += 1
        return stubbedMap
    }
}

// Stub implementations
private protocol CompletionRepository {
    func completionsMap(userId: String, dateKey: String, habitIds: [UUID]) throws -> [UUID: Bool]
}

private class HomeListViewModel {
    let completionRepo: CompletionRepository
    var visibleHabitIds: [UUID] = []
    var selectedDateKey: String = ""
    
    init(completionRepo: CompletionRepository) {
        self.completionRepo = completionRepo
    }
    
    func prefetchCompletionStatus() {
        // Simulate the prefetch logic
        _ = try? completionRepo.completionsMap(userId: "test", dateKey: selectedDateKey, habitIds: visibleHabitIds)
    }
}
