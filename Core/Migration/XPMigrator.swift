import Foundation
import SwiftData

/// XPMigrator converts XPManager data to UserProgressModel + XPTransactionModel
///
/// **Old XP System (UserDefaults):**
/// - "total_xp" → totalXP
/// - "current_level" → currentLevel  
/// - "xp_history" → Array of XP transactions (if available)
///
/// **New XP System (SwiftData):**
/// - UserProgressModel (total XP, level, etc.)
/// - XPTransactionModel (append-only audit log)
@MainActor
class XPMigrator {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let userId: String
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
    }
    
    // MARK: - Migration
    
    struct XPMigrationResult {
        var userProgressCreated: Bool = false
        var totalXP: Int = 0
        var currentLevel: Int = 0
        var transactionsCreated: Int = 0
    }
    
    func migrate(dryRun: Bool) async throws -> XPMigrationResult {
        var result = XPMigrationResult()
        
        print("⭐ Migrating XP data...")
        
        // Read from XPManager's UserDefaults storage
        let totalXP = UserDefaults.standard.integer(forKey: "total_xp_\(userId)")
        let currentLevel = UserDefaults.standard.integer(forKey: "current_level_\(userId)")
        
        print("📊 Found XP: \(totalXP), Level: \(currentLevel)")
        
        // Recalculate level from XP (in case of inconsistencies)
        let calculatedLevel = UserProgressModel.calculateLevel(fromXP: totalXP)
        
        if calculatedLevel != currentLevel {
            print("⚠️ Level mismatch: stored=\(currentLevel), calculated=\(calculatedLevel). Using calculated.")
        }
        
        // Calculate XP for current level and next level
        let xpForCurrentLevel = UserProgressModel.calculateXPForLevel(calculatedLevel)
        let xpForNextLevel = UserProgressModel.calculateXPForLevel(calculatedLevel + 1)
        
        // Create UserProgressModel
        let userProgress = UserProgressModel(
            userId: userId,
            totalXP: totalXP,
            currentLevel: calculatedLevel,
            xpForCurrentLevel: xpForCurrentLevel,
            xpForNextLevel: xpForNextLevel
        )
        
        if !dryRun {
            modelContext.insert(userProgress)
        }
        
        result.userProgressCreated = true
        result.totalXP = totalXP
        result.currentLevel = calculatedLevel
        
        // Migrate XP transactions (if available)
        let transactionCount = try migrateXPTransactions(
            userProgress: userProgress,
            dryRun: dryRun
        )
        
        result.transactionsCreated = transactionCount
        
        print("✅ XP migrated: \(totalXP) XP, Level \(calculatedLevel), \(transactionCount) transactions")
        
        return result
    }
    
    // MARK: - XP Transaction Migration
    
    /// Migrate XP transaction history
    /// If no history exists, create a single "Initial migration" transaction
    private func migrateXPTransactions(
        userProgress: UserProgressModel,
        dryRun: Bool
    ) throws -> Int {
        var transactionCount = 0
        
        // Try to load XP history from UserDefaults
        // Format: Array of [date: String, amount: Int, reason: String]
        if let historyData = UserDefaults.standard.data(forKey: "xp_history_\(userId)"),
           let history = try? JSONDecoder().decode([[String: Any]].self, from: historyData) {
            
            // Migrate each transaction
            for entry in history {
                guard let dateString = entry["date"] as? String,
                      let amount = entry["amount"] as? Int,
                      let reason = entry["reason"] as? String,
                      let date = parseDate(dateString) else {
                    continue
                }
                
                let transaction = XPTransactionModel(
                    userId: userId,
                    amount: amount,
                    reason: reason,
                    timestamp: date
                )
                
                if !dryRun {
                    modelContext.insert(transaction)
                }
                
                transactionCount += 1
            }
            
            print("✅ Migrated \(transactionCount) XP transactions from history")
            
        } else {
            // No history found - create single migration transaction
            let transaction = XPTransactionModel(
                userId: userId,
                amount: userProgress.totalXP,
                reason: "Initial migration from old system",
                timestamp: Date()
            )
            
            if !dryRun {
                modelContext.insert(transaction)
            }
            
            transactionCount = 1
            
            print("ℹ️ No XP history found - created single migration transaction")
        }
        
        return transactionCount
    }
    
    // MARK: - Helpers
    
    /// Parse date string from old format
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try alternate format
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

