import Foundation
import SwiftData
import XCTest
@testable import Habitto

// MARK: - Streak Lookup Performance Benchmark
/// Benchmark comparing old vs new streak lookup performance
final class BenchmarkStreakLookup: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var streakService: StreakService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory SwiftData store for testing
        let schema = Schema([
            DailyAward.self,
            UserProgressData.self,
            AchievementData.self,
            CompletionRecord.self,
            MigrationState.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        streakService = StreakService.shared
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        streakService = nil
        try await super.tearDown()
    }
    
    // MARK: - Benchmark Tests
    
    func test_streakLookupPerformance_oldVsNew() async throws {
        let userId = "benchmark_user"
        let testDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: testDate)
        
        // Seed 365 days of awards (simulate a year of daily completions)
        try await seedDailyAwards(userId: userId, days: 365, endDate: testDate)
        
        // Benchmark old method (fetch all + filter)
        let oldMethodTimes = try await benchmarkOldMethod(userId: userId, context: modelContext)
        
        // Benchmark new method (single range query)
        let newMethodTimes = try await benchmarkNewMethod(userId: userId, upTo: todayKey, context: modelContext)
        
        // Calculate median times
        let oldMedian = calculateMedian(oldMethodTimes)
        let newMedian = calculateMedian(newMethodTimes)
        
        // Performance improvement
        let improvement = oldMedian / newMedian
        
        print("\n📊 STREAK LOOKUP PERFORMANCE BENCHMARK")
        print(String(repeating: "=", count: 50))
        print("Test Configuration:")
        print("  - User ID: \(userId)")
        print("  - Days seeded: 365")
        print("  - Test runs: 10 each method")
        print("  - End date: \(todayKey)")
        print("")
        print("Results:")
        print("  Old method (fetch all): \(String(format: "%.3f", oldMedian))s median")
        print("  New method (range query): \(String(format: "%.3f", newMedian))s median")
        print("  Performance improvement: \(String(format: "%.1f", improvement))x faster")
        print("")
        
        // Assert performance improvement
        XCTAssertGreaterThan(improvement, 2.0, "New method should be at least 2x faster")
        XCTAssertLessThan(newMedian, 0.1, "New method should complete in under 100ms")
        
        // Save benchmark results
        try await saveBenchmarkResults(
            oldMedian: oldMedian,
            newMedian: newMedian,
            improvement: improvement,
            testSeeds: 365,
            endDate: todayKey
        )
    }
    
    func test_streakLookupPerformance_variousDataSizes() async throws {
        let userId = "benchmark_user_various"
        let testDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: testDate)
        
        let testSizes = [30, 90, 180, 365] // 1 month, 3 months, 6 months, 1 year
        var results: [(size: Int, oldMedian: Double, newMedian: Double, improvement: Double)] = []
        
        for size in testSizes {
            // Clear previous data
            try await clearTestData(userId: userId)
            
            // Seed data
            try await seedDailyAwards(userId: userId, days: size, endDate: testDate)
            
            // Benchmark both methods
            let oldMethodTimes = try await benchmarkOldMethod(userId: userId, context: modelContext)
            let newMethodTimes = try await benchmarkNewMethod(userId: userId, upTo: todayKey, context: modelContext)
            
            let oldMedian = calculateMedian(oldMethodTimes)
            let newMedian = calculateMedian(newMethodTimes)
            let improvement = oldMedian / newMedian
            
            results.append((size: size, oldMedian: oldMedian, newMedian: newMedian, improvement: improvement))
            
            print("📊 Data size \(size) days: \(String(format: "%.1f", improvement))x improvement")
        }
        
        // Save comprehensive results
        try await saveComprehensiveBenchmarkResults(results: results, endDate: todayKey)
    }
    
    // MARK: - Helper Methods
    
    private func seedDailyAwards(userId: String, days: Int, endDate: Date) async throws {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: endDate) ?? endDate
            let dateKey = dateFormatter.string(from: date)
            
            let award = DailyAward(
                userId: userId,
                dateKey: dateKey,
                xpGranted: 10,
                allHabitsCompleted: true
            )
            
            modelContext.insert(award)
        }
        
        try modelContext.save()
        print("✅ Seeded \(days) daily awards for \(userId)")
    }
    
    private func benchmarkOldMethod(userId: String, context: ModelContext) async throws -> [Double] {
        var times: [Double] = []
        
        for _ in 0..<10 {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Old method: Fetch all awards and filter
            let request = FetchDescriptor<DailyAward>(
                predicate: #Predicate { $0.userId == userId && $0.allHabitsCompleted == true }
            )
            
            let allAwards = try context.fetch(request)
            let _ = allAwards.sorted { $0.dateKey < $1.dateKey }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            times.append(endTime - startTime)
        }
        
        return times
    }
    
    private func benchmarkNewMethod(userId: String, upTo dateKey: String, context: ModelContext) async throws -> [Double] {
        var times: [Double] = []
        
        for _ in 0..<10 {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // New method: Single range query
            let _ = try await streakService.consecutiveAwardDateKeys(
                userId: userId,
                upTo: dateKey,
                limit: 365,
                context: context
            )
            
            let endTime = CFAbsoluteTimeGetCurrent()
            times.append(endTime - startTime)
        }
        
        return times
    }
    
    private func calculateMedian(_ times: [Double]) -> Double {
        let sorted = times.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
    
    private func clearTestData(userId: String) async throws {
        // Clear existing awards for the user
        let request = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId }
        )
        let awards = try modelContext.fetch(request)
        
        for award in awards {
            modelContext.delete(award)
        }
        
        try modelContext.save()
    }
    
    private func saveBenchmarkResults(
        oldMedian: Double,
        newMedian: Double,
        improvement: Double,
        testSeeds: Int,
        endDate: String
    ) async throws {
        let benchmarkData = BenchmarkResult(
            testName: "streak_lookup_performance",
            timestamp: Date(),
            configuration: BenchmarkConfiguration(
                testSeeds: testSeeds,
                endDate: endDate,
                runs: 10
            ),
            oldMethod: MethodResult(
                medianTime: oldMedian,
                description: "Fetch all awards + filter"
            ),
            newMethod: MethodResult(
                medianTime: newMedian,
                description: "Single range query"
            ),
            improvement: improvement,
            codeUsed: getBenchmarkCode()
        )
        
        try await saveBenchmarkToFile(benchmarkData, filename: "streak_lookup_benchmark.md")
    }
    
    private func saveComprehensiveBenchmarkResults(
        results: [(size: Int, oldMedian: Double, newMedian: Double, improvement: Double)],
        endDate: String
    ) async throws {
        let comprehensiveData = ComprehensiveBenchmarkResult(
            testName: "streak_lookup_performance_various_sizes",
            timestamp: Date(),
            endDate: endDate,
            results: results.map { result in
                SizeBenchmarkResult(
                    dataSize: result.size,
                    oldMedian: result.oldMedian,
                    newMedian: result.newMedian,
                    improvement: result.improvement
                )
            },
            codeUsed: getBenchmarkCode()
        )
        
        try await saveComprehensiveBenchmarkToFile(comprehensiveData, filename: "streak_lookup_comprehensive_benchmark.md")
    }
    
    private func saveBenchmarkToFile(_ data: BenchmarkResult, filename: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let benchmarksDir = documentsPath.appendingPathComponent("benchmarks")
        
        try FileManager.default.createDirectory(at: benchmarksDir, withIntermediateDirectories: true)
        let fileURL = benchmarksDir.appendingPathComponent(filename)
        
        let content = generateBenchmarkMarkdown(data)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        print("📁 Benchmark results saved to: \(fileURL.path)")
    }
    
    private func saveComprehensiveBenchmarkToFile(_ data: ComprehensiveBenchmarkResult, filename: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let benchmarksDir = documentsPath.appendingPathComponent("benchmarks")
        
        try FileManager.default.createDirectory(at: benchmarksDir, withIntermediateDirectories: true)
        let fileURL = benchmarksDir.appendingPathComponent(filename)
        
        let content = generateComprehensiveBenchmarkMarkdown(data)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        print("📁 Comprehensive benchmark results saved to: \(fileURL.path)")
    }
    
    private func generateBenchmarkMarkdown(_ data: BenchmarkResult) -> String {
        return """
# Streak Lookup Performance Benchmark

**Test Name**: \(data.testName)  
**Timestamp**: \(data.timestamp)  
**Configuration**: \(data.configuration.testSeeds) seeds, \(data.configuration.runs) runs, end date: \(data.configuration.endDate)

## Results

| Method | Median Time | Description |
|--------|-------------|-------------|
| Old | \(String(format: "%.3f", data.oldMethod.medianTime))s | \(data.oldMethod.description) |
| New | \(String(format: "%.3f", data.newMethod.medianTime))s | \(data.newMethod.description) |

**Performance Improvement**: \(String(format: "%.1f", data.improvement))x faster

## Code Used

```swift
\(data.codeUsed)
```

## Test Seeds

- **User ID**: benchmark_user
- **Days seeded**: \(data.configuration.testSeeds)
- **End date**: \(data.configuration.endDate)
- **Award type**: DailyAward with allHabitsCompleted = true
- **XP granted**: 10 per award

---
*Generated by BenchmarkStreakLookup.swift*
"""
    }
    
    private func generateComprehensiveBenchmarkMarkdown(_ data: ComprehensiveBenchmarkResult) -> String {
        var markdown = """
# Comprehensive Streak Lookup Performance Benchmark

**Test Name**: \(data.testName)  
**Timestamp**: \(data.timestamp)  
**End Date**: \(data.endDate)

## Results by Data Size

| Data Size | Old Method | New Method | Improvement |
|-----------|------------|------------|-------------|
"""
        
        for result in data.results {
            markdown += """
| \(result.dataSize) days | \(String(format: "%.3f", result.oldMedian))s | \(String(format: "%.3f", result.newMedian))s | \(String(format: "%.1f", result.improvement))x |
"""
        }
        
        markdown += """

## Code Used

```swift
\(data.codeUsed)
```

## Test Configuration

- **User ID**: benchmark_user_various
- **Data sizes tested**: \(data.results.map { "\($0.dataSize)" }.joined(separator: ", ")) days
- **Test runs**: 10 per method per size
- **End date**: \(data.endDate)

---
*Generated by BenchmarkStreakLookup.swift*
"""
        
        return markdown
    }
    
    private func getBenchmarkCode() -> String {
        return """
// Old Method (fetch all + filter)
let request = FetchDescriptor<DailyAward>(
    predicate: #Predicate { $0.userId == userId && $0.allHabitsCompleted == true }
)
let allAwards = try context.fetch(request)
let _ = allAwards.sorted { $0.dateKey < $1.dateKey }

// New Method (single range query)
let consecutiveDates = try await streakService.consecutiveAwardDateKeys(
    userId: userId,
    upTo: dateKey,
    limit: 365,
    context: context
)
"""
    }
}

// MARK: - Benchmark Data Models

struct BenchmarkResult {
    let testName: String
    let timestamp: Date
    let configuration: BenchmarkConfiguration
    let oldMethod: MethodResult
    let newMethod: MethodResult
    let improvement: Double
    let codeUsed: String
}

struct BenchmarkConfiguration {
    let testSeeds: Int
    let endDate: String
    let runs: Int
}

struct MethodResult {
    let medianTime: Double
    let description: String
}

struct ComprehensiveBenchmarkResult {
    let testName: String
    let timestamp: Date
    let endDate: String
    let results: [SizeBenchmarkResult]
    let codeUsed: String
}

struct SizeBenchmarkResult {
    let dataSize: Int
    let oldMedian: Double
    let newMedian: Double
    let improvement: Double
}
