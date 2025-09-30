import Foundation

final class DateKeyTests {
    
    func testDateKeyGeneration() {
        // Given
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // When & Then
        let date1 = formatter.date(from: "2024-03-15 10:30:00")!
        let key1 = DateKey.key(for: date1)
        assert(key1 == "2024-03-15")
        
        let date2 = formatter.date(from: "2024-12-25 23:59:59")!
        let key2 = DateKey.key(for: date2)
        assert(key2 == "2024-12-25")
    }
    
    func testDSTEdgeCases() {
        // Given
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // DST Start (2024-03-31 02:00:00)
        let dstStart = formatter.date(from: "2024-03-31 02:00:00")!
        let key1 = DateKey.key(for: dstStart)
        assert(key1 == "2024-03-31")
        
        // DST End (2024-10-27 02:00:00)
        let dstEnd = formatter.date(from: "2024-10-27 02:00:00")!
        let key2 = DateKey.key(for: dstEnd)
        assert(key2 == "2024-10-27")
    }
    
    func testMidnightBoundaries() {
        // Given
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Just before midnight
        let justBeforeMidnight = formatter.date(from: "2024-03-31 23:59:59")!
        let key1 = DateKey.key(for: justBeforeMidnight)
        assert(key1 == "2024-03-31")
        
        // Just after midnight
        let justAfterMidnight = formatter.date(from: "2024-04-01 00:00:01")!
        let key2 = DateKey.key(for: justAfterMidnight)
        assert(key2 == "2024-04-01")
        
        // Different dates should have different keys
        assert(key1 != key2)
    }
    
    func testStartOfDay() {
        // Given
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let date = formatter.date(from: "2024-03-15 14:30:45")!
        
        // When
        let startOfDay = DateKey.startOfDay(for: date)
        
        // Then
        let resultFormatter = DateFormatter()
        resultFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        resultFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let resultString = resultFormatter.string(from: startOfDay)
        assert(resultString == "2024-03-15 00:00:00")
    }
    
    func testEndOfDay() {
        // Given
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let date = formatter.date(from: "2024-03-15 14:30:45")!
        
        // When
        let endOfDay = DateKey.endOfDay(for: date)
        
        // Then
        let resultFormatter = DateFormatter()
        resultFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        resultFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let resultString = resultFormatter.string(from: endOfDay)
        assert(resultString == "2024-03-15 23:59:59")
    }
    
    func testConsistencyAcrossDay() {
        // Given
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let baseDate = formatter.date(from: "2024-03-15 12:00:00")!
        
        // When - test different times on the same day
        let times = ["00:00:00", "06:30:00", "12:00:00", "18:45:00", "23:59:59"]
        var keys: Set<String> = []
        
        for time in times {
            let dateString = "2024-03-15 \(time)"
            let date = formatter.date(from: dateString)!
            let key = DateKey.key(for: date)
            keys.insert(key)
        }
        
        // Then - all times should produce the same key
        assert(keys.count == 1, "All times on the same day should produce the same key")
        assert(keys.first == "2024-03-15")
    }
}
