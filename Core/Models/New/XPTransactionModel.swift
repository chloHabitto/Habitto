import Foundation
import SwiftData

/// XPTransactionModel provides append-only audit log of all XP changes
///
/// **Design Philosophy:**
/// - Never delete transactions (immutable history)
/// - Sum of all transactions = UserProgress.totalXP
/// - Provides accountability and debugging
///
/// **Transaction Types:**
/// - Positive amounts: XP awarded
/// - Negative amounts: XP removed (undo scenarios)
@Model
final class XPTransactionModel {
    // MARK: - Identity
    
    @Attribute(.unique) var id: UUID
    
    /// User ID (indexed for fast user queries)
    @Attribute(.index) var userId: String
    
    // MARK: - Transaction Data
    
    /// XP amount (positive = award, negative = removal)
    var amount: Int
    
    /// Human-readable reason (e.g., "Daily completion for 2024-10-19")
    var reason: String
    
    /// When transaction occurred
    @Attribute(.index) var timestamp: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: String,
        amount: Int,
        reason: String,
        timestamp: Date
    ) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.reason = reason
        self.timestamp = timestamp
    }
    
    // MARK: - Computed Properties
    
    /// Is this an XP award (positive) or removal (negative)?
    var isAward: Bool {
        amount > 0
    }
    
    var isRemoval: Bool {
        amount < 0
    }
    
    /// Display string for UI
    var displayString: String {
        let sign = amount > 0 ? "+" : ""
        return "\(sign)\(amount) XP: \(reason)"
    }
}

// MARK: - Query Helpers

extension XPTransactionModel {
    /// Get transactions for date range
    static func transactionsInRange(
        from startDate: Date,
        to endDate: Date,
        userId: String,
        modelContext: ModelContext
    ) throws -> [XPTransactionModel] {
        let predicate = #Predicate<XPTransactionModel> { transaction in
            transaction.userId == userId &&
            transaction.timestamp >= startDate &&
            transaction.timestamp <= endDate
        }
        
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Get total XP awarded in date range
    static func totalXPInRange(
        from startDate: Date,
        to endDate: Date,
        userId: String,
        modelContext: ModelContext
    ) throws -> Int {
        let transactions = try transactionsInRange(
            from: startDate,
            to: endDate,
            userId: userId,
            modelContext: modelContext
        )
        
        return transactions.reduce(0) { $0 + $1.amount }
    }
}

