import XCTest
@testable import Habitto

/// Tests for XP data isolation during sign-out
/// Verifies that XP data is properly cleared when users sign out
final class XPSignOutTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var xpManager: XPManager!
    
    override func setUp() {
        super.setUp()
        
        // Create fresh instances for testing
        authManager = AuthenticationManager.shared
        xpManager = XPManager.shared
        
        // Clear any existing test data
        xpManager.clearXPData()
    }
    
    override func tearDown() {
        // Clean up after tests
        xpManager.clearXPData()
        super.tearDown()
    }
    
    // MARK: - Sign-Out XP Clearing Tests
    
    func testSignOutClearsXPData() {
        // Given: User has XP data
        xpManager.userProgress.totalXP = 1000
        xpManager.userProgress.currentLevel = 5
        xpManager.userProgress.dailyXP = 100
        xpManager.recentTransactions = [
            XPTransaction(amount: 50, reason: .completeHabit, description: "Test transaction")
        ]
        
        // Verify initial state
        XCTAssertEqual(xpManager.userProgress.totalXP, 1000)
        XCTAssertEqual(xpManager.userProgress.currentLevel, 5)
        XCTAssertEqual(xpManager.userProgress.dailyXP, 100)
        XCTAssertEqual(xpManager.recentTransactions.count, 1)
        
        // When: User signs out
        authManager.signOut()
        
        // Then: XP data should be cleared
        XCTAssertEqual(xpManager.userProgress.totalXP, 0, "Total XP should be cleared on sign-out")
        XCTAssertEqual(xpManager.userProgress.currentLevel, 1, "Level should reset to 1 on sign-out")
        XCTAssertEqual(xpManager.userProgress.dailyXP, 0, "Daily XP should be cleared on sign-out")
        XCTAssertEqual(xpManager.recentTransactions.count, 0, "Recent transactions should be cleared on sign-out")
    }
    
    func testClearXPDataMethod() {
        // Given: User has XP data
        xpManager.userProgress.totalXP = 500
        xpManager.userProgress.currentLevel = 3
        xpManager.recentTransactions = [
            XPTransaction(amount: 25, reason: .streakBonus, description: "Streak bonus")
        ]
        
        // Verify initial state
        XCTAssertEqual(xpManager.userProgress.totalXP, 500)
        XCTAssertEqual(xpManager.userProgress.currentLevel, 3)
        XCTAssertEqual(xpManager.recentTransactions.count, 1)
        
        // When: clearXPData is called directly
        xpManager.clearXPData()
        
        // Then: All XP data should be reset to defaults
        XCTAssertEqual(xpManager.userProgress.totalXP, 0, "Total XP should be reset to 0")
        XCTAssertEqual(xpManager.userProgress.currentLevel, 1, "Level should reset to 1")
        XCTAssertEqual(xpManager.userProgress.dailyXP, 0, "Daily XP should be reset to 0")
        XCTAssertEqual(xpManager.recentTransactions.count, 0, "Recent transactions should be empty")
    }
    
    func testUserDefaultsKeysAreCleared() {
        // Given: XP data exists in UserDefaults
        let userDefaults = UserDefaults.standard
        let userProgressKey = "user_progress"
        let transactionsKey = "recent_xp_transactions"
        let dailyAwardsKey = "daily_xp_awards"
        
        // Set some test data in UserDefaults
        userDefaults.set("test_data", forKey: userProgressKey)
        userDefaults.set("test_transactions", forKey: transactionsKey)
        userDefaults.set("test_awards", forKey: dailyAwardsKey)
        
        // Verify keys exist
        XCTAssertNotNil(userDefaults.object(forKey: userProgressKey))
        XCTAssertNotNil(userDefaults.object(forKey: transactionsKey))
        XCTAssertNotNil(userDefaults.object(forKey: dailyAwardsKey))
        
        // When: clearXPData is called
        xpManager.clearXPData()
        
        // Then: Keys should be removed from UserDefaults
        XCTAssertNil(userDefaults.object(forKey: userProgressKey), "user_progress key should be removed")
        XCTAssertNil(userDefaults.object(forKey: transactionsKey), "recent_xp_transactions key should be removed")
        XCTAssertNil(userDefaults.object(forKey: dailyAwardsKey), "daily_xp_awards key should be removed")
    }
    
    func testMultipleSignOutsDoNotCauseIssues() {
        // Given: User signs out multiple times
        xpManager.userProgress.totalXP = 200
        
        // When: Sign out first time
        authManager.signOut()
        XCTAssertEqual(xpManager.userProgress.totalXP, 0)
        
        // When: Sign out again (should not cause issues)
        authManager.signOut()
        XCTAssertEqual(xpManager.userProgress.totalXP, 0)
        
        // When: Sign out third time (should still work)
        authManager.signOut()
        XCTAssertEqual(xpManager.userProgress.totalXP, 0)
        
        // Then: System should remain stable
        XCTAssertEqual(xpManager.userProgress.currentLevel, 1)
        XCTAssertEqual(xpManager.userProgress.dailyXP, 0)
        XCTAssertEqual(xpManager.recentTransactions.count, 0)
    }
}
