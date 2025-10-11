import Foundation
import SwiftData

// MARK: - DailyAward

@Model
public final class DailyAward {
  // MARK: Lifecycle

  public init(userId: String, dateKey: String, xpGranted: Int, allHabitsCompleted: Bool = true) {
    self.id = UUID()
    self.userId = userId
    self.dateKey = dateKey
    self.xpGranted = xpGranted
    self.allHabitsCompleted = allHabitsCompleted
    self.createdAt = Date()
    self.userIdDateKey = "\(userId)#\(dateKey)"
  }

  // MARK: Public

  @Attribute(.unique) public var id: UUID
  public var userId: String
  public var dateKey: String
  public var xpGranted: Int
  public var allHabitsCompleted: Bool
  public var createdAt: Date

  /// Unique constraint on (userId, dateKey)
  @Attribute(.unique) public var userIdDateKey: String

  /// Computed property for composite unique key
  public var uniqueKey: String {
    "\(userId)#\(dateKey)"
  }
}

// MARK: - App-level unique constraint guard

extension DailyAward {
  /// Validates that no duplicate award exists for the same user and date
  public static func validateUniqueConstraint(
    userId: String,
    dateKey: String,
    in context: ModelContext) -> Bool
  {
    let predicate = #Predicate<DailyAward> { award in
      award.userId == userId && award.dateKey == dateKey
    }

    let request = FetchDescriptor<DailyAward>(predicate: predicate)
    let existingAwards = (try? context.fetch(request)) ?? []

    return existingAwards.isEmpty
  }
}
