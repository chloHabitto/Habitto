import Foundation
import SwiftData

/// Service for managing XP (Experience Points) and user leveling
/// **Responsibilities:**
/// - Award XP for daily habit completion
/// - Remove XP when progress is undone
/// - Calculate user levels from XP
/// - Track XP transactions (audit log)
@MainActor
class XPService {
    
    // MARK: - Constants
    
    /// Base XP awarded per completed day (50 XP)
    private static let baseXPPerDay: Int = 50
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("✅ XPService: Initialized")
    }
    
    // MARK: - User Progress
    
    /// Get or create user progress record
    /// **Returns:** UserProgressModel for the user
    func getOrCreateProgress(for userId: String) throws -> UserProgressModel {
        // Try to find existing progress
        let descriptor = FetchDescriptor<UserProgressModel>(
            predicate: #Predicate { progress in
                progress.userId == userId
            }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            print("📊 XPService: Found existing progress for user '\(userId)'")
            return existing
        }
        
        // Create new progress
        let progress = UserProgressModel(userId: userId, totalXP: 0)
        modelContext.insert(progress)
        try modelContext.save()
        
        print("✨ XPService: Created new progress for user '\(userId)'")
        return progress
    }
    
    // MARK: - XP Award/Removal
    
    /// Award XP for completing all habits on a date
    /// **Returns:** Amount of XP awarded
    /// **Side effects:**
    /// - Creates XP transaction
    /// - Updates user level if needed
    func awardDailyCompletion(
        for userId: String,
        on date: Date,
        habits: [HabitModel]
    ) throws -> Int {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        // Check if XP already awarded for this date
        if try hasAwardedXP(for: userId, on: normalizedDate) {
            print("⚠️ XPService: XP already awarded for \(dateKey) - skipping")
            return 0
        }
        
        let userProgress = try getOrCreateProgress(for: userId)
        let oldXP = userProgress.totalXP
        let oldLevel = userProgress.currentLevel
        
        // Calculate XP to award
        let xpAmount = Self.baseXPPerDay
        let reason = "Daily completion for \(dateKey)"
        
        // Add XP
        userProgress.addXP(xpAmount, reason: reason)
        
        // Create transaction record
        let transaction = XPTransactionModel(
        userId: userId,
            amount: xpAmount,
            reason: reason,
            timestamp: Date()
        )
        modelContext.insert(transaction)
        
        try modelContext.save()
        
        let newXP = userProgress.totalXP
        let newLevel = userProgress.currentLevel
        
        print("⭐ XPService: Awarded \(xpAmount) XP for \(dateKey)")
        print("   User XP: \(oldXP) → \(newXP)")
        if newLevel > oldLevel {
            print("   🎉 LEVEL UP! \(oldLevel) → \(newLevel)")
        }

      return xpAmount
    }
    
    /// Remove XP for a date (when progress is undone)
    /// **Returns:** Amount of XP removed
    /// **Side effects:**
    /// - Creates negative XP transaction
    /// - Updates user level if needed
    func removeDailyCompletion(
        for userId: String,
        on date: Date
    ) throws -> Int {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        // Check if XP was awarded for this date
        guard let transaction = try findTransaction(for: userId, on: normalizedDate) else {
            print("ℹ️ XPService: No XP transaction found for \(dateKey) - skipping removal")
      return 0
    }

        let userProgress = try getOrCreateProgress(for: userId)
        let oldXP = userProgress.totalXP
        let oldLevel = userProgress.currentLevel
        
        let xpAmount = transaction.amount
        let reason = "Reversal for \(dateKey) (day incomplete)"
        
        // Remove XP
        userProgress.removeXP(xpAmount, reason: reason)
        
        // Create reversal transaction
        let reversal = XPTransactionModel(
        userId: userId,
            amount: -xpAmount,
            reason: reason,
            timestamp: Date()
        )
        modelContext.insert(reversal)
        
        try modelContext.save()
        
        let newXP = userProgress.totalXP
        let newLevel = userProgress.currentLevel
        
        print("❌ XPService: Removed \(xpAmount) XP for \(dateKey)")
        print("   User XP: \(oldXP) → \(newXP)")
        if newLevel < oldLevel {
            print("   ⬇️ Level decreased: \(oldLevel) → \(newLevel)")
        }

      return xpAmount
    }
    
    // MARK: - Transaction Queries
    
    /// Check if XP has been awarded for a specific date
    private func hasAwardedXP(
        for userId: String,
        on date: Date
    ) throws -> Bool {
        return try findTransaction(for: userId, on: date) != nil
    }
    
    /// Find XP transaction for a specific date
    /// **Returns:** XPTransactionModel if found, nil otherwise
    private func findTransaction(
        for userId: String,
        on date: Date
    ) throws -> XPTransactionModel? {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        // Fetch all transactions for this user
        let descriptor = FetchDescriptor<XPTransactionModel>(
            predicate: #Predicate { transaction in
                transaction.userId == userId && transaction.amount > 0
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let transactions = try modelContext.fetch(descriptor)
        
        // Find transaction matching the date in reason
        return transactions.first { transaction in
            transaction.reason.contains(dateKey)
        }
    }
    
    /// Get all XP transactions for a user
    func getTransactionHistory(
        for userId: String,
        limit: Int? = nil
    ) throws -> [XPTransactionModel] {
        var descriptor = FetchDescriptor<XPTransactionModel>(
            predicate: #Predicate { transaction in
                transaction.userId == userId
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Level Calculations
    
    /// Calculate XP required for a specific level
    /// **Formula:** 1000 * level (Level 1 = 1000 XP, Level 2 = 2000 XP, etc.)
    nonisolated static func xpRequiredForLevel(_ level: Int) -> Int {
        return UserProgressModel.xpRequiredForLevel(level)
    }
    
    /// Calculate cumulative XP needed to reach a level
    /// **Example:** To reach level 3, you need 1000 + 2000 = 3000 total XP
    nonisolated static func cumulativeXPForLevel(_ level: Int) -> Int {
        return UserProgressModel.cumulativeXPForLevel(level)
    }
    
    /// Calculate level from total XP
    /// **Example:** 2500 XP = Level 2 (need 3000 for level 3)
    nonisolated static func calculateLevel(fromXP totalXP: Int) -> Int {
        return UserProgressModel.calculateLevel(fromXP: totalXP)
    }
    
    // MARK: - User Stats
    
    /// Get user's current XP and level information
    func getUserStats(for userId: String) throws -> UserStats {
        let userProgress = try getOrCreateProgress(for: userId)
        
        // Calculate progress to next level
        let progressToNext = userProgress.xpForNextLevel > 0 
            ? Double(userProgress.xpForCurrentLevel) / Double(userProgress.xpForNextLevel)
            : 0.0
        
        return UserStats(
            totalXP: userProgress.totalXP,
            currentLevel: userProgress.currentLevel,
            xpForCurrentLevel: userProgress.xpForCurrentLevel,
            xpForNextLevel: userProgress.xpForNextLevel,
            progressToNextLevel: progressToNext
        )
    }
    
    /// Get total XP earned in a date range
    func getTotalXPEarned(
        for userId: String,
        from startDate: Date,
        to endDate: Date
    ) throws -> Int {
        let descriptor = FetchDescriptor<XPTransactionModel>(
            predicate: #Predicate { transaction in
                transaction.userId == userId &&
                transaction.timestamp >= startDate &&
                transaction.timestamp <= endDate &&
                transaction.amount > 0
            }
        )
        
        let transactions = try modelContext.fetch(descriptor)
        return transactions.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Manual Adjustments
    
    /// Manually add XP (for admin/testing purposes)
    func addXP(
        _ amount: Int,
        to userId: String,
        reason: String
    ) throws {
        let userProgress = try getOrCreateProgress(for: userId)
        let oldXP = userProgress.totalXP
        
        userProgress.addXP(amount, reason: reason)
        
        let transaction = XPTransactionModel(
        userId: userId,
            amount: amount,
            reason: reason,
            timestamp: Date()
        )
        modelContext.insert(transaction)
        
        try modelContext.save()
        
        print("➕ XPService: Manually added \(amount) XP - \(oldXP) → \(userProgress.totalXP)")
    }
    
    /// Manually remove XP (for admin/testing purposes)
    func removeXP(
        _ amount: Int,
        from userId: String,
        reason: String
    ) throws {
        let userProgress = try getOrCreateProgress(for: userId)
        let oldXP = userProgress.totalXP
        
        userProgress.removeXP(amount, reason: reason)
        
        let transaction = XPTransactionModel(
            userId: userId,
            amount: -amount,
            reason: reason,
            timestamp: Date()
        )
        modelContext.insert(transaction)

    try modelContext.save()
        
        print("➖ XPService: Manually removed \(amount) XP - \(oldXP) → \(userProgress.totalXP)")
    }
    
    /// Reset user's XP to zero (for testing)
    func resetXP(for userId: String) throws {
        let userProgress = try getOrCreateProgress(for: userId)
        let oldXP = userProgress.totalXP
        
        userProgress.setXP(0, reason: "XP reset")
        
        let transaction = XPTransactionModel(
            userId: userId,
            amount: -oldXP,
            reason: "XP reset",
            timestamp: Date()
        )
        modelContext.insert(transaction)
        
        try modelContext.save()
        
        print("🔄 XPService: Reset XP from \(oldXP) to 0")
    }
}

// MARK: - Result Types

/// User XP and level statistics
struct UserStats {
    let totalXP: Int
    let currentLevel: Int
    let xpForCurrentLevel: Int
    let xpForNextLevel: Int
    let progressToNextLevel: Double
    
    var description: String {
        return "Level \(currentLevel) - \(totalXP) XP (\(Int(progressToNextLevel * 100))% to next)"
    }
    
    var nextLevelXP: Int {
        return XPService.cumulativeXPForLevel(currentLevel + 1)
    }
    
    var xpUntilNextLevel: Int {
        return nextLevelXP - totalXP
    }
}

// MARK: - Errors

enum XPServiceError: LocalizedError {
    case userNotFound
    case invalidAmount
    case transactionNotFound
    case insufficientXP
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidAmount:
            return "Invalid XP amount"
        case .transactionNotFound:
            return "Transaction not found"
        case .insufficientXP:
            return "Insufficient XP"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
