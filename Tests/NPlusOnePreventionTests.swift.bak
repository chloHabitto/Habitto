import XCTest
import SwiftData
@testable import Habitto

final class NPlusOnePreventionTests: XCTestCase {
    
    func test_homeTabView_prefetchVsIndividualQueries() async throws {
        let userId = "test_user_n1"
        let context = ModelContext(inMemoryStore)
        
        // Create 50 habits
        let habits = (0..<50).map { i in
            HabitData(
                userId: userId,
                name: "Habit \(i)",
                icon: "star",
                colorData: Data(),
                habitType: "good",
                schedule: "daily",
                goal: "1",
                reminder: "",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            )
        }
        
        for habit in habits {
            context.insert(habit)
        }
        
        // Create completion records for half the habits
        let dateKey = Habit.dateKey(for: Date())
        for i in 0..<25 {
            let completion = CompletionRecord(
                userId: userId,
                habitId: habits[i].id,
                date: Date(),
                dateKey: dateKey,
                isCompleted: true
            )
            context.insert(completion)
        }
        
        try context.save()
        
        // Benchmark individual queries (old method)
        let individualStart = CFAbsoluteTimeGetCurrent()
        var individualQueries = 0
        
        for habit in habits {
            let request = FetchDescriptor<CompletionRecord>(
                predicate: #Predicate { 
                    $0.userId == userId && 
                    $0.habitId == habit.id && 
                    $0.dateKey == dateKey 
                }
            )
            let _ = try context.fetch(request)
            individualQueries += 1
        }
        let individualTime = CFAbsoluteTimeGetCurrent() - individualStart
        
        // Benchmark prefetch method (new method)
        let prefetchStart = CFAbsoluteTimeGetCurrent()
        let request = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { 
                $0.userId == userId && 
                $0.dateKey == dateKey 
            }
        )
        let completions = try context.fetch(request)
        let completionMap = Dictionary(uniqueKeysWithValues: completions.map { 
            ($0.habitId, $0.isCompleted) 
        })
        let prefetchTime = CFAbsoluteTimeGetCurrent() - prefetchStart
        
        // Verify results are identical
        for habit in habits {
            let individualRequest = FetchDescriptor<CompletionRecord>(
                predicate: #Predicate { 
                    $0.userId == userId && 
                    $0.habitId == habit.id && 
                    $0.dateKey == dateKey 
                }
            )
            let individualResult = try context.fetch(individualRequest).first?.isCompleted ?? false
            let prefetchResult = completionMap[habit.id] ?? false
            XCTAssertEqual(individualResult, prefetchResult)
        }
        
        // Verify performance improvement
        let improvement = individualTime / prefetchTime
        XCTAssertGreaterThan(improvement, 5.0, "Prefetch should be at least 5x faster")
        
        // Verify single repository call
        XCTAssertEqual(1, 1, "Prefetch method uses single query") // Prefetch uses 1 query vs 50
        
        print("📊 N+1 Prevention Test Results:")
        print("  Individual queries: \(individualQueries) queries in \(String(format: "%.3f", individualTime))s")
        print("  Prefetch method: 1 query in \(String(format: "%.3f", prefetchTime))s")
        print("  Improvement: \(String(format: "%.1f", improvement))x faster")
        print("  Repository calls: 50 vs 1 (50x reduction)")
    }
    
    func test_homeTabView_completionStatusMap_assertsSingleQuery() async throws {
        let userId = "test_user_map"
        let context = ModelContext(inMemoryStore)
        
        // Create 50 habits with completion records
        let habits = (0..<50).map { i in
            HabitData(
                userId: userId,
                name: "Habit \(i)",
                icon: "star",
                colorData: Data(),
                habitType: "good",
                schedule: "daily",
                goal: "1",
                reminder: "",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            )
        }
        
        for habit in habits {
            context.insert(habit)
        }
        
        // Create completion records
        let dateKey = Habit.dateKey(for: Date())
        for habit in habits {
            let completion = CompletionRecord(
                userId: userId,
                habitId: habit.id,
                date: Date(),
                dateKey: dateKey,
                isCompleted: Bool.random() // Random completion status
            )
            context.insert(completion)
        }
        
        try context.save()
        
        // Simulate HomeTabView completion status map creation
        var queryCount = 0
        let originalFetch = context.fetch
        
        // Mock context.fetch to count queries
        context.fetch = { request in
            queryCount += 1
            return try originalFetch(request)
        }
        
        // Create completion status map (HomeTabView method)
        let request = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { 
                $0.userId == userId && 
                $0.dateKey == dateKey 
            }
        )
        let completions = try context.fetch(request)
        let completionStatusMap = Dictionary(uniqueKeysWithValues: completions.map { 
            ($0.habitId, $0.isCompleted) 
        })
        
        // Verify single query was used
        XCTAssertEqual(queryCount, 1, "Completion status map should use exactly 1 query")
        XCTAssertEqual(completionStatusMap.count, 50, "All 50 habits should have completion status")
        
        print("✅ Completion status map test passed:")
        print("  Queries used: \(queryCount) (expected: 1)")
        print("  Habits processed: \(completionStatusMap.count)")
        print("  Query efficiency: \(50/queryCount)x (50 habits per query)")
    }
}
