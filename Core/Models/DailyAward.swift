import Foundation
import SwiftData

@Model
public class DailyAward {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var dateKey: String
    public var xpGranted: Int
    public var createdAt: Date
    
    // Computed property for composite unique key
    public var uniqueKey: String {
        return "\(userId)#\(dateKey)"
    }
    
    public init(userId: String, dateKey: String, xpGranted: Int) {
        self.id = UUID()
        self.userId = userId
        self.dateKey = dateKey
        self.xpGranted = xpGranted
        self.createdAt = Date()
    }
}

// MARK: - App-level unique constraint guard
extension DailyAward {
    /// Validates that no duplicate award exists for the same user and date
    public static func validateUniqueConstraint(userId: String, dateKey: String, in context: ModelContext) -> Bool {
        let predicate = #Predicate<DailyAward> { award in
            award.userId == userId && award.dateKey == dateKey
        }
        
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        let existingAwards = (try? context.fetch(request)) ?? []
        
        return existingAwards.isEmpty
    }
}
