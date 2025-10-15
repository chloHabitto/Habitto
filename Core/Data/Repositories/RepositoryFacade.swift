import Foundation
import OSLog

// MARK: - Repository Facade

/// Central facade for providing the correct repository implementation based on feature flags
struct RepositoryFacade {
    
    // MARK: - Repository Providers
    
    /// Get the appropriate habit repository based on current feature flags
    static func habits() -> HabitRepositoryProtocol {
        if MigrationFeatureFlags.dualWriteEnabled {
            logger.info("🔀 RepositoryFacade: Using DualWriteHabitRepository")
            return DualWriteHabitRepository(
                primary: FirestoreHabitRepository(),
                secondary: CloudKitHabitRepository(),
                fallbackReads: MigrationFeatureFlags.legacyReadFallbackEnabled
            )
        } else {
            logger.info("🔥 RepositoryFacade: Using FirestoreHabitRepository (primary only)")
            return FirestoreHabitRepository()
        }
    }
    
    /// Get the appropriate completion repository
    static func completions() -> CompletionRepository {
        if MigrationFeatureFlags.dualWriteEnabled {
            logger.info("🔀 RepositoryFacade: Using DualWriteCompletionRepository")
            return DualWriteCompletionRepository(
                primary: FirestoreCompletionRepository(),
                secondary: CloudKitCompletionRepository(),
                fallbackReads: MigrationFeatureFlags.legacyReadFallbackEnabled
            )
        } else {
            logger.info("🔥 RepositoryFacade: Using FirestoreCompletionRepository (primary only)")
            return FirestoreCompletionRepository()
        }
    }
    
    /// Get the appropriate XP repository
    static func xp() -> XPRepository {
        if MigrationFeatureFlags.dualWriteEnabled {
            logger.info("🔀 RepositoryFacade: Using DualWriteXPRepository")
            return DualWriteXPRepository(
                primary: FirestoreXPRepository(),
                secondary: CloudKitXPRepository(),
                fallbackReads: MigrationFeatureFlags.legacyReadFallbackEnabled
            )
        } else {
            logger.info("🔥 RepositoryFacade: Using FirestoreXPRepository (primary only)")
            return FirestoreXPRepository()
        }
    }
    
    /// Get the appropriate streak repository
    static func streaks() -> StreakRepository {
        if MigrationFeatureFlags.dualWriteEnabled {
            logger.info("🔀 RepositoryFacade: Using DualWriteStreakRepository")
            return DualWriteStreakRepository(
                primary: FirestoreStreakRepository(),
                secondary: CloudKitStreakRepository(),
                fallbackReads: MigrationFeatureFlags.legacyReadFallbackEnabled
            )
        } else {
            logger.info("🔥 RepositoryFacade: Using FirestoreStreakRepository (primary only)")
            return FirestoreStreakRepository()
        }
    }
}

// MARK: - Repository Protocols

protocol CompletionRepository {
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int
    func getCompletionCount(habitId: String, date: Date) async throws -> Int
    func completions(for habitId: String, from startDate: Date, to endDate: Date) async throws -> [CompletionRecord]
}

protocol XPRepository {
    func awardXP(_ amount: Int, reason: String, habitId: String?) async throws
    func getTotalXP() async throws -> Int
    func getXPHistory(limit: Int) async throws -> [XPLedgerEntry]
}

protocol StreakRepository {
    func updateStreak(for habitId: String, date: Date, isComplete: Bool) async throws
    func getCurrentStreak(for habitId: String) async throws -> Int
    func getLongestStreak(for habitId: String) async throws -> Int
}

// MARK: - Placeholder CloudKit Repository (Legacy)

/// Placeholder for CloudKit habit repository (legacy)
final class CloudKitHabitRepository: HabitRepositoryProtocol {
    func create(_ habit: Habit) async throws {
        logger.warning("CloudKitHabitRepository: Create called (legacy)")
    }
    
    func update(_ habit: Habit) async throws {
        logger.warning("CloudKitHabitRepository: Update called (legacy)")
    }
    
    func delete(id: String) async throws {
        logger.warning("CloudKitHabitRepository: Delete called (legacy)")
    }
    
    func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(nil)
            continuation.finish()
        }
    }
    
    func habits() -> AsyncThrowingStream<[Habit], Error> {
        AsyncThrowingStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
    }
    
    func habits(for date: Date) async throws -> [Habit] {
        return []
    }
    
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
        return 0
    }
    
    func getCompletionCount(habitId: String, date: Date) async throws -> Int {
        return 0
    }
}

// MARK: - Placeholder Repository Implementations (To be implemented later)

final class DualWriteCompletionRepository: CompletionRepository {
    private let primary: CompletionRepository
    private let secondary: CompletionRepository
    private let fallbackReads: Bool
    
    init(primary: CompletionRepository, secondary: CompletionRepository, fallbackReads: Bool) {
        self.primary = primary
        self.secondary = secondary
        self.fallbackReads = fallbackReads
    }
    
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
        let result = try await primary.markComplete(habitId: habitId, date: date, count: count)
        
        // Fire-and-forget secondary write
        Task {
            try? await secondary.markComplete(habitId: habitId, date: date, count: count)
        }
        
        return result
    }
    
    func getCompletionCount(habitId: String, date: Date) async throws -> Int {
        do {
            return try await primary.getCompletionCount(habitId: habitId, date: date)
        } catch {
            if fallbackReads {
                return try await secondary.getCompletionCount(habitId: habitId, date: date)
            }
            throw error
        }
    }
    
    func completions(for habitId: String, from startDate: Date, to endDate: Date) async throws -> [CompletionRecord] {
        do {
            return try await primary.completions(for: habitId, from: startDate, to: endDate)
        } catch {
            if fallbackReads {
                return try await secondary.completions(for: habitId, from: startDate, to: endDate)
            }
            throw error
        }
    }
}

final class FirestoreCompletionRepository: CompletionRepository {
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
        // TODO: Implement Firestore completion tracking
        return count
    }
    
    func getCompletionCount(habitId: String, date: Date) async throws -> Int {
        // TODO: Implement Firestore completion count retrieval
        return 0
    }
    
    func completions(for habitId: String, from startDate: Date, to endDate: Date) async throws -> [CompletionRecord] {
        // TODO: Implement Firestore completion history
        return []
    }
}

final class CloudKitCompletionRepository: CompletionRepository {
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
        return 0
    }
    
    func getCompletionCount(habitId: String, date: Date) async throws -> Int {
        return 0
    }
    
    func completions(for habitId: String, from startDate: Date, to endDate: Date) async throws -> [CompletionRecord] {
        return []
    }
}

final class DualWriteXPRepository: XPRepository {
    private let primary: XPRepository
    private let secondary: XPRepository
    private let fallbackReads: Bool
    
    init(primary: XPRepository, secondary: XPRepository, fallbackReads: Bool) {
        self.primary = primary
        self.secondary = secondary
        self.fallbackReads = fallbackReads
    }
    
    func awardXP(_ amount: Int, reason: String, habitId: String?) async throws {
        try await primary.awardXP(amount, reason: reason, habitId: habitId)
        
        Task {
            try? await secondary.awardXP(amount, reason: reason, habitId: habitId)
        }
    }
    
    func getTotalXP() async throws -> Int {
        do {
            return try await primary.getTotalXP()
        } catch {
            if fallbackReads {
                return try await secondary.getTotalXP()
            }
            throw error
        }
    }
    
    func getXPHistory(limit: Int) async throws -> [XPLedgerEntry] {
        do {
            return try await primary.getXPHistory(limit: limit)
        } catch {
            if fallbackReads {
                return try await secondary.getXPHistory(limit: limit)
            }
            throw error
        }
    }
}

final class FirestoreXPRepository: XPRepository {
    func awardXP(_ amount: Int, reason: String, habitId: String?) async throws {
        // TODO: Implement Firestore XP tracking
    }
    
    func getTotalXP() async throws -> Int {
        // TODO: Implement Firestore XP retrieval
        return 0
    }
    
    func getXPHistory(limit: Int) async throws -> [XPLedgerEntry] {
        // TODO: Implement Firestore XP history
        return []
    }
}

final class CloudKitXPRepository: XPRepository {
    func awardXP(_ amount: Int, reason: String, habitId: String?) async throws {
        // No-op for legacy
    }
    
    func getTotalXP() async throws -> Int {
        return 0
    }
    
    func getXPHistory(limit: Int) async throws -> [XPLedgerEntry] {
        return []
    }
}

final class DualWriteStreakRepository: StreakRepository {
    private let primary: StreakRepository
    private let secondary: StreakRepository
    private let fallbackReads: Bool
    
    init(primary: StreakRepository, secondary: StreakRepository, fallbackReads: Bool) {
        self.primary = primary
        self.secondary = secondary
        self.fallbackReads = fallbackReads
    }
    
    func updateStreak(for habitId: String, date: Date, isComplete: Bool) async throws {
        try await primary.updateStreak(for: habitId, date: date, isComplete: isComplete)
        
        Task {
            try? await secondary.updateStreak(for: habitId, date: date, isComplete: isComplete)
        }
    }
    
    func getCurrentStreak(for habitId: String) async throws -> Int {
        do {
            return try await primary.getCurrentStreak(for: habitId)
        } catch {
            if fallbackReads {
                return try await secondary.getCurrentStreak(for: habitId)
            }
            throw error
        }
    }
    
    func getLongestStreak(for habitId: String) async throws -> Int {
        do {
            return try await primary.getLongestStreak(for: habitId)
        } catch {
            if fallbackReads {
                return try await secondary.getLongestStreak(for: habitId)
            }
            throw error
        }
    }
}

final class FirestoreStreakRepository: StreakRepository {
    func updateStreak(for habitId: String, date: Date, isComplete: Bool) async throws {
        // TODO: Implement Firestore streak tracking
    }
    
    func getCurrentStreak(for habitId: String) async throws -> Int {
        // TODO: Implement Firestore streak retrieval
        return 0
    }
    
    func getLongestStreak(for habitId: String) async throws -> Int {
        // TODO: Implement Firestore longest streak retrieval
        return 0
    }
}

final class CloudKitStreakRepository: StreakRepository {
    func updateStreak(for habitId: String, date: Date, isComplete: Bool) async throws {
        // No-op for legacy
    }
    
    func getCurrentStreak(for habitId: String) async throws -> Int {
        return 0
    }
    
    func getLongestStreak(for habitId: String) async throws -> Int {
        return 0
    }
}

// MARK: - Logging

private let logger = Logger(subsystem: "com.habitto.app", category: "RepositoryFacade")