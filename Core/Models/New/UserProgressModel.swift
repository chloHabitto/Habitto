import Foundation
import SwiftData

/// UserProgressModel tracks XP, levels, and achievements for one user
///
/// **Design Philosophy:**
/// - XP is the single source of truth
/// - Level is ALWAYS calculated from XP (no double-bumping)
/// - All XP changes are logged in transactions (audit trail)
///
/// **XP System:**
/// - Base XP per habit: 100 * currentLevel
/// - Level up threshold: level * 1000 XP
/// - Example: Level 1→2 needs 1000 XP, Level 2→3 needs 2000 XP
@Model
final class UserProgressModel {
    // MARK: - Identity
    
    @Attribute(.unique) var id: UUID
    
    /// User ID for multi-user support
    @Attribute(.index) var userId: String
    
    // MARK: - XP Data
    
    /// Total XP accumulated (source of truth)
    var totalXP: Int
    
    /// Current level (calculated from totalXP)
    var currentLevel: Int
    
    /// XP accumulated within current level
    /// **Example:** Level 2 needs 2000 XP. If totalXP = 1500, then xpForCurrentLevel = 500
    var xpForCurrentLevel: Int
    
    /// XP needed to reach next level
    /// **Example:** Level 2 needs 2000 XP total, so xpForNextLevel = 2000
    var xpForNextLevel: Int
    
    // MARK: - Relationships
    
    /// All XP transactions (append-only audit log)
    @Relationship(deleteRule: .cascade) var xpTransactions: [XPTransactionModel]
    
    /// Unlocked achievements
    @Relationship(deleteRule: .cascade) var achievements: [AchievementModel]
    
    // MARK: - Metadata
    
    /// Last time XP was updated
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: String,
        totalXP: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.totalXP = totalXP
        self.currentLevel = 1
        self.xpForCurrentLevel = 0
        self.xpForNextLevel = Self.xpRequiredForLevel(1)
        self.xpTransactions = []
        self.achievements = []
        self.lastUpdated = Date()
        
        // Calculate level from XP
        updateLevelProgress()
    }
    
    // MARK: - Level Calculation (Linear System)
    
    /// Calculate XP required to reach a specific level
    /// **Formula:** level * 1000
    /// - Level 1→2: 1000 XP
    /// - Level 2→3: 2000 XP
    /// - Level 10→11: 10000 XP
    static func xpRequiredForLevel(_ level: Int) -> Int {
        return level * 1000
    }
    
    /// Calculate cumulative XP needed to reach a level
    /// **Example:** To reach level 3: 1000 + 2000 = 3000 XP total
    static func cumulativeXPForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        
        var total = 0
        for lvl in 1..<level {
            total += xpRequiredForLevel(lvl)
        }
        return total
    }
    
    /// Calculate level from total XP
    /// **Algorithm:** Find highest level where cumulative XP <= totalXP
    static func calculateLevel(fromXP totalXP: Int) -> Int {
        guard totalXP > 0 else { return 1 }
        
        var level = 1
        var cumulativeXP = 0
        
        while cumulativeXP + xpRequiredForLevel(level) <= totalXP {
            cumulativeXP += xpRequiredForLevel(level)
            level += 1
        }
        
        return level
    }
    
    /// Calculate XP per habit at current level
    /// **Formula:** 100 * currentLevel
    func xpPerHabit() -> Int {
        return 100 * currentLevel
    }
    
    // MARK: - Level Progress Update
    
    /// Recalculate level and progress from current totalXP
    /// **Called after every XP change**
    func updateLevelProgress() {
        // Calculate level from XP
        let newLevel = Self.calculateLevel(fromXP: totalXP)
        currentLevel = newLevel
        
        // Calculate XP within current level
        let currentLevelStartXP = Self.cumulativeXPForLevel(newLevel)
        let nextLevelStartXP = Self.cumulativeXPForLevel(newLevel + 1)
        
        xpForCurrentLevel = totalXP - currentLevelStartXP
        xpForNextLevel = Self.xpRequiredForLevel(newLevel)
        
        lastUpdated = Date()
    }
    
    // MARK: - XP Management
    
    /// Add XP with transaction logging
    /// **Important:** This is the ONLY way to add XP (maintains audit trail)
    func addXP(_ amount: Int, reason: String, timestamp: Date = Date()) {
        guard amount > 0 else {
            print("⚠️ Attempted to add non-positive XP: \(amount)")
            return
        }
        
        let oldLevel = currentLevel
        
        // Add XP
        totalXP += amount
        
        // Create transaction record
        let transaction = XPTransactionModel(
            userId: userId,
            amount: amount,
            reason: reason,
            timestamp: timestamp
        )
        xpTransactions.append(transaction)
        
        // Recalculate level
        updateLevelProgress()
        
        // Check if leveled up
        if currentLevel > oldLevel {
            print("🎉 Level up! \(oldLevel) → \(currentLevel)")
            // Note: No bonus XP for level up (to prevent inflation)
        }
        
        print("✅ Added \(amount) XP: \(reason) | Total: \(totalXP) | Level: \(currentLevel)")
    }
    
    /// Remove XP with transaction logging
    /// **Use case:** Undo daily completion when day becomes incomplete
    func removeXP(_ amount: Int, reason: String, timestamp: Date = Date()) {
        guard amount > 0 else {
            print("⚠️ Attempted to remove non-positive XP: \(amount)")
            return
        }
        
        let oldLevel = currentLevel
        
        // Remove XP (don't go below 0)
        totalXP = max(0, totalXP - amount)
        
        // Create transaction record (negative amount)
        let transaction = XPTransactionModel(
            userId: userId,
            amount: -amount,
            reason: reason,
            timestamp: timestamp
        )
        xpTransactions.append(transaction)
        
        // Recalculate level
        updateLevelProgress()
        
        // Check if leveled down
        if currentLevel < oldLevel {
            print("⚠️ Level down: \(oldLevel) → \(currentLevel)")
        }
        
        print("⚠️ Removed \(amount) XP: \(reason) | Total: \(totalXP) | Level: \(currentLevel)")
    }
    
    /// Set XP to specific value (for migrations/corrections)
    /// **Use case:** Data migration, admin corrections
    func setXP(_ amount: Int, reason: String) {
        let difference = amount - totalXP
        
        if difference > 0 {
            addXP(difference, reason: reason)
        } else if difference < 0 {
            removeXP(abs(difference), reason: reason)
        }
        // If difference == 0, no change needed
    }
    
    // MARK: - Achievement Management
    
    /// Unlock an achievement
    func unlockAchievement(
        achievementId: String,
        title: String,
        description: String,
        xpAwarded: Int = 0
    ) {
        let achievement = AchievementModel(
            userId: userId,
            achievementId: achievementId,
            title: title,
            description: description,
            unlockedAt: Date(),
            xpAwarded: xpAwarded
        )
        
        achievements.append(achievement)
        
        // Award XP if applicable
        if xpAwarded > 0 {
            addXP(xpAwarded, reason: "Achievement: \(title)")
        }
        
        print("🏆 Achievement unlocked: \(title) (+\(xpAwarded) XP)")
    }
    
    /// Check if achievement is unlocked
    func hasAchievement(_ achievementId: String) -> Bool {
        achievements.contains { $0.achievementId == achievementId }
    }
}

// MARK: - Display Helpers

extension UserProgressModel {
    /// Progress percentage to next level (0.0 - 1.0)
    var levelProgressPercentage: Double {
        guard xpForNextLevel > 0 else { return 0.0 }
        return Double(xpForCurrentLevel) / Double(xpForNextLevel)
    }
    
    /// Formatted total XP (e.g., "1.5K")
    var formattedTotalXP: String {
        if totalXP >= 1000 {
            return String(format: "%.1fK", Double(totalXP) / 1000.0)
        } else {
            return "\(totalXP)"
        }
    }
    
    /// XP remaining to next level
    var xpToNextLevel: Int {
        xpForNextLevel - xpForCurrentLevel
    }
}

// MARK: - Validation

extension UserProgressModel {
    /// Validate XP data
    func validate() -> [String] {
        var errors: [String] = []
        
        if totalXP < 0 {
            errors.append("Total XP cannot be negative")
        }
        
        if currentLevel < 1 {
            errors.append("Current level must be >= 1")
        }
        
        if xpForCurrentLevel < 0 {
            errors.append("XP for current level cannot be negative")
        }
        
        if xpForNextLevel <= 0 {
            errors.append("XP for next level must be > 0")
        }
        
        // Verify level calculation matches totalXP
        let expectedLevel = Self.calculateLevel(fromXP: totalXP)
        if currentLevel != expectedLevel {
            errors.append("Level mismatch: stored=\(currentLevel), expected=\(expectedLevel)")
        }
        
        // Verify XP transaction sum matches totalXP
        let transactionSum = xpTransactions.reduce(0) { $0 + $1.amount }
        if transactionSum != totalXP {
            errors.append("XP transaction sum (\(transactionSum)) doesn't match totalXP (\(totalXP))")
        }
        
        return errors
    }
    
    var isValid: Bool {
        validate().isEmpty
    }
}

