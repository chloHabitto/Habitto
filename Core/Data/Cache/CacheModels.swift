import Foundation
import SwiftData

/// SwiftData cache models for fast list views
///
/// Key Principles:
/// - ONE-WAY HYDRATION: Firestore → SwiftData cache only
/// - NEVER MUTATE: Cache is read-only, disposable
/// - LIST VIEWS: Use cache for performance
/// - DETAIL VIEWS: Read live from Firestore
///
/// These models mirror Firestore documents but are optimized for list views.
/// All writes go to Firestore first, then hydrate to cache via snapshot listeners.

// MARK: - Habit Cache

@Model
final class HabitCache {
    @Attribute(.unique) var id: String
    var name: String
    var color: String
    var type: String
    var createdAt: Date
    var active: Bool
    var lastSyncedAt: Date
    
    init(
        id: String,
        name: String,
        color: String,
        type: String,
        createdAt: Date,
        active: Bool,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.type = type
        self.createdAt = createdAt
        self.active = active
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// Hydrate from Firestore Habit model
    static func from(_ habit: Habit) -> HabitCache {
        HabitCache(
            id: habit.id,
            name: habit.name,
            color: habit.color,
            type: habit.type,
            createdAt: habit.createdAt,
            active: habit.active
        )
    }
    
    /// Convert to Habit model (for UI compatibility)
    func toHabit() -> Habit {
        Habit(
            id: id,
            name: name,
            color: color,
            type: type,
            createdAt: createdAt,
            active: active
        )
    }
}

// MARK: - Completion Cache

@Model
final class CompletionCache {
    @Attribute(.unique) var id: String  // habitId + localDate
    var habitId: String
    var localDate: String  // YYYY-MM-DD
    var count: Int
    var lastSyncedAt: Date
    
    init(
        habitId: String,
        localDate: String,
        count: Int,
        lastSyncedAt: Date = Date()
    ) {
        self.id = "\(habitId)_\(localDate)"
        self.habitId = habitId
        self.localDate = localDate
        self.count = count
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// Hydrate from Firestore Completion model
    static func from(habitId: String, localDate: String, completion: Completion) -> CompletionCache {
        CompletionCache(
            habitId: habitId,
            localDate: localDate,
            count: completion.count
        )
    }
}

// MARK: - Streak Cache

@Model
final class StreakCache {
    @Attribute(.unique) var habitId: String
    var current: Int
    var longest: Int
    var lastCompletionDate: String?
    var lastSyncedAt: Date
    
    init(
        habitId: String,
        current: Int,
        longest: Int,
        lastCompletionDate: String?,
        lastSyncedAt: Date = Date()
    ) {
        self.habitId = habitId
        self.current = current
        self.longest = longest
        self.lastCompletionDate = lastCompletionDate
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// Hydrate from Firestore Streak model
    static func from(habitId: String, streak: Streak) -> StreakCache {
        StreakCache(
            habitId: habitId,
            current: streak.current,
            longest: streak.longest,
            lastCompletionDate: streak.lastCompletionDate
        )
    }
}

// MARK: - XP State Cache

@Model
final class XPStateCache {
    @Attribute(.unique) var id: String  // Always "current"
    var totalXP: Int
    var level: Int
    var currentLevelXP: Int
    var lastUpdated: Date
    var lastSyncedAt: Date
    
    init(
        totalXP: Int,
        level: Int,
        currentLevelXP: Int,
        lastUpdated: Date,
        lastSyncedAt: Date = Date()
    ) {
        self.id = "current"
        self.totalXP = totalXP
        self.level = level
        self.currentLevelXP = currentLevelXP
        self.lastUpdated = lastUpdated
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// Hydrate from Firestore XPState model
    static func from(_ xpState: XPState) -> XPStateCache {
        XPStateCache(
            totalXP: xpState.totalXP,
            level: xpState.level,
            currentLevelXP: xpState.currentLevelXP,
            lastUpdated: xpState.lastUpdated
        )
    }
}

// MARK: - Cache Metadata

@Model
final class CacheMetadata {
    @Attribute(.unique) var key: String
    var lastFullSync: Date?
    var lastIncrementalSync: Date?
    var version: Int
    
    init(
        key: String,
        lastFullSync: Date? = nil,
        lastIncrementalSync: Date? = nil,
        version: Int = 1
    ) {
        self.key = key
        self.lastFullSync = lastFullSync
        self.lastIncrementalSync = lastIncrementalSync
        self.version = version
    }
}


