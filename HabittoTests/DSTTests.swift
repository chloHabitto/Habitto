import XCTest
@testable import Habitto

final class DSTTests: XCTestCase {
    
    func test_DST_Forward_2024_March31() throws {
        // Europe/Amsterdam DST forward transition: March 31, 2024 (2:00 AM → 3:00 AM)
        let transitionDate = Date(timeIntervalSince1970: 1711843200) // March 31, 2024 2:00 AM UTC
        
        let dateKey = DateKey.key(for: transitionDate)
        let dateKeyBefore = DateKey.key(for: transitionDate.addingTimeInterval(-3600)) // 1 hour before
        let dateKeyAfter = DateKey.key(for: transitionDate.addingTimeInterval(3600))   // 1 hour after
        
        print("🧪 DST Forward 2024:")
        print("  Transition: \(transitionDate)")
        print("  Before: \(dateKeyBefore)")
        print("  During: \(dateKey)")
        print("  After: \(dateKeyAfter)")
        
        // All should generate the same dateKey since they're on the same calendar day in Amsterdam timezone
        XCTAssertEqual(dateKeyBefore, "2024-03-31", "Hour before DST should be same date")
        XCTAssertEqual(dateKey, "2024-03-31", "During DST transition should be same date")
        XCTAssertEqual(dateKeyAfter, "2024-03-31", "Hour after DST should be same date")
        
        print("✅ DST Forward 2024 test PASSED")
    }
    
    func test_DST_Backward_2024_October27() throws {
        // Europe/Amsterdam DST backward transition: October 27, 2024 (3:00 AM → 2:00 AM)
        let transitionDate = Date(timeIntervalSince1970: 1730008800) // October 27, 2024 3:00 AM UTC
        
        let dateKey = DateKey.key(for: transitionDate)
        let dateKeyBefore = DateKey.key(for: transitionDate.addingTimeInterval(-3600)) // 1 hour before
        let dateKeyAfter = DateKey.key(for: transitionDate.addingTimeInterval(3600))   // 1 hour after
        
        print("🧪 DST Backward 2024:")
        print("  Transition: \(transitionDate)")
        print("  Before: \(dateKeyBefore)")
        print("  During: \(dateKey)")
        print("  After: \(dateKeyAfter)")
        
        // All should generate the same dateKey since they're on the same calendar day in Amsterdam timezone
        XCTAssertEqual(dateKeyBefore, "2024-10-27", "Hour before DST should be same date")
        XCTAssertEqual(dateKey, "2024-10-27", "During DST transition should be same date")
        XCTAssertEqual(dateKeyAfter, "2024-10-27", "Hour after DST should be same date")
        
        print("✅ DST Backward 2024 test PASSED")
    }
    
    func test_DST_Forward_2025_March30() throws {
        // Europe/Amsterdam DST forward transition: March 30, 2025 (2:00 AM → 3:00 AM)
        let transitionDate = Date(timeIntervalSince1970: 1743292800) // March 30, 2025 2:00 AM UTC
        
        let dateKey = DateKey.key(for: transitionDate)
        let dateKeyBefore = DateKey.key(for: transitionDate.addingTimeInterval(-3600)) // 1 hour before
        let dateKeyAfter = DateKey.key(for: transitionDate.addingTimeInterval(3600))   // 1 hour after
        
        print("🧪 DST Forward 2025:")
        print("  Transition: \(transitionDate)")
        print("  Before: \(dateKeyBefore)")
        print("  During: \(dateKey)")
        print("  After: \(dateKeyAfter)")
        
        // All should generate the same dateKey since they're on the same calendar day in Amsterdam timezone
        XCTAssertEqual(dateKeyBefore, "2025-03-30", "Hour before DST should be same date")
        XCTAssertEqual(dateKey, "2025-03-30", "During DST transition should be same date")
        XCTAssertEqual(dateKeyAfter, "2025-03-30", "Hour after DST should be same date")
        
        print("✅ DST Forward 2025 test PASSED")
    }
    
    func test_DST_Backward_2025_October26() throws {
        // Europe/Amsterdam DST backward transition: October 26, 2025 (3:00 AM → 2:00 AM)
        let transitionDate = Date(timeIntervalSince1970: 1761458400) // October 26, 2025 3:00 AM UTC
        
        let dateKey = DateKey.key(for: transitionDate)
        let dateKeyBefore = DateKey.key(for: transitionDate.addingTimeInterval(-3600)) // 1 hour before
        let dateKeyAfter = DateKey.key(for: transitionDate.addingTimeInterval(3600))   // 1 hour after
        
        print("🧪 DST Backward 2025:")
        print("  Transition: \(transitionDate)")
        print("  Before: \(dateKeyBefore)")
        print("  During: \(dateKey)")
        print("  After: \(dateKeyAfter)")
        
        // All should generate the same dateKey since they're on the same calendar day in Amsterdam timezone
        XCTAssertEqual(dateKeyBefore, "2025-10-26", "Hour before DST should be same date")
        XCTAssertEqual(dateKey, "2025-10-26", "During DST transition should be same date")
        XCTAssertEqual(dateKeyAfter, "2025-10-26", "Hour after DST should be same date")
        
        print("✅ DST Backward 2025 test PASSED")
    }
}
