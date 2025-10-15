import Foundation
import OSLog

// MARK: - Dual-Write Habit Repository

/// Repository that writes to both primary (Firestore) and secondary (CloudKit) systems
/// Primary writes are synchronous and blocking; secondary writes are fire-and-forget
final class DualWriteHabitRepository: HabitRepositoryProtocol {
    
    // MARK: - Properties
    
    private let primary: HabitRepositoryProtocol
    private let secondary: HabitRepositoryProtocol
    private let fallbackReads: Bool
    
    // MARK: - Initialization
    
    init(primary: HabitRepositoryProtocol, secondary: HabitRepositoryProtocol, fallbackReads: Bool) {
        self.primary = primary
        self.secondary = secondary
        self.fallbackReads = fallbackReads
        
        logger.info("🔀 DualWriteHabitRepository initialized with fallbackReads: \(fallbackReads)")
    }
    
    // MARK: - HabitRepository Implementation
    
    func create(_ habit: Habit) async throws {
        logger.info("🔀 DualWrite: Creating habit \(habit.id)")
        
        // Primary write (blocking)
        try await primary.create(habit)
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.create.primary", primarySuccess: true, secondarySuccess: false, duration: 0.0)
        
        // Secondary write (fire-and-forget)
        Task {
            do {
                try await secondary.create(habit)
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.create.secondary", primarySuccess: false, secondarySuccess: true, duration: 0.0)
                logger.debug("🔀 DualWrite: Secondary create succeeded for habit \(habit.id)")
            } catch {
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.create.secondary", primarySuccess: false, secondarySuccess: false, duration: 0.0)
                logger.warning("🔀 DualWrite: Secondary create failed for habit \(habit.id): \(error.localizedDescription)")
                CrashlyticsService.shared.recordError(error)
            }
        }
        
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.create", primarySuccess: true, secondarySuccess: true, duration: 0.0)
    }
    
    func update(_ habit: Habit) async throws {
        logger.info("🔀 DualWrite: Updating habit \(habit.id)")
        
        // Primary write (blocking)
        try await primary.update(habit)
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.update.primary", primarySuccess: true, secondarySuccess: false, duration: 0.0)
        
        // Secondary write (fire-and-forget)
        Task {
            do {
                try await secondary.update(habit)
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.update.secondary", primarySuccess: false, secondarySuccess: true, duration: 0.0)
                logger.debug("🔀 DualWrite: Secondary update succeeded for habit \(habit.id)")
            } catch {
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.update.secondary", primarySuccess: false, secondarySuccess: false, duration: 0.0)
                logger.warning("🔀 DualWrite: Secondary update failed for habit \(habit.id): \(error.localizedDescription)")
                CrashlyticsService.shared.recordError(error)
            }
        }
        
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.update", primarySuccess: true, secondarySuccess: true, duration: 0.0)
    }
    
    func delete(id: String) async throws {
        logger.info("🔀 DualWrite: Deleting habit \(id)")
        
        // Primary write (blocking)
        try await primary.delete(id: id)
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.delete.primary", primarySuccess: true, secondarySuccess: false, duration: 0.0)
        
        // Secondary write (fire-and-forget)
        Task {
            do {
                try await secondary.delete(id: id)
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.delete.secondary", primarySuccess: false, secondarySuccess: true, duration: 0.0)
                logger.debug("🔀 DualWrite: Secondary delete succeeded for habit \(id)")
            } catch {
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.delete.secondary", primarySuccess: false, secondarySuccess: false, duration: 0.0)
                logger.warning("🔀 DualWrite: Secondary delete failed for habit \(id): \(error.localizedDescription)")
                CrashlyticsService.shared.recordError(error)
            }
        }
        
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.delete", primarySuccess: true, secondarySuccess: true, duration: 0.0)
    }
    
    func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
        // Read from primary first
        let primaryStream = primary.habit(by: id)
        
        // If fallback reads are enabled, check secondary if primary returns nil
        if fallbackReads {
            return AsyncThrowingStream<Habit?, Error> { continuation in
                Task {
                    do {
                        for try await value in primaryStream {
                            if let value = value {
                                continuation.yield(value)
                            } else {
                                // Try to read from secondary
                                if let secondaryValue = try? await secondary.habit(by: id).firstValue() {
                                    continuation.yield(secondaryValue)
                                } else {
                                    continuation.yield(nil)
                                }
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            return primaryStream
        }
    }
    
    func habits() -> AsyncThrowingStream<[Habit], Error> {
        // Read from primary first
        let primaryStream = primary.habits()
        
        // If fallback reads are enabled, check secondary if primary returns empty
        if fallbackReads {
            return AsyncThrowingStream<[Habit], Error> { continuation in
                Task {
                    do {
                        for try await value in primaryStream {
                            if value.isEmpty {
                                // Try to read from secondary
                                if let secondaryValue = try? await secondary.habits().firstValue() {
                                    continuation.yield(secondaryValue)
                                } else {
                                    continuation.yield(value)
                                }
                            } else {
                                continuation.yield(value)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            return primaryStream
        }
    }
    
    func habits(for date: Date) async throws -> [Habit] {
        do {
            return try await primary.habits(for: date)
        } catch {
            if fallbackReads {
                logger.info("🔀 DualWrite: Primary habits(for:) failed, trying secondary")
                return try await secondary.habits(for: date)
            }
            throw error
        }
    }
    
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
        logger.info("🔀 DualWrite: Marking complete habit \(habitId)")
        
        // Primary write (blocking)
        let result = try await primary.markComplete(habitId: habitId, date: date, count: count)
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.markComplete.primary", primarySuccess: true, secondarySuccess: false, duration: 0.0)
        
        // Secondary write (fire-and-forget)
        Task {
            do {
                _ = try await secondary.markComplete(habitId: habitId, date: date, count: count)
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.markComplete.secondary", primarySuccess: false, secondarySuccess: true, duration: 0.0)
                logger.debug("🔀 DualWrite: Secondary markComplete succeeded for habit \(habitId)")
            } catch {
                MigrationTelemetryService.shared.trackDualWrite(operation: "habit.markComplete.secondary", primarySuccess: false, secondarySuccess: false, duration: 0.0)
                logger.warning("🔀 DualWrite: Secondary markComplete failed for habit \(habitId): \(error.localizedDescription)")
                CrashlyticsService.shared.recordError(error)
            }
        }
        
        MigrationTelemetryService.shared.trackDualWrite(operation: "habit.markComplete", primarySuccess: true, secondarySuccess: true, duration: 0.0)
        return result
    }
    
    func getCompletionCount(habitId: String, date: Date) async throws -> Int {
        do {
            return try await primary.getCompletionCount(habitId: habitId, date: date)
        } catch {
            if fallbackReads {
                logger.info("🔀 DualWrite: Primary getCompletionCount failed, trying secondary")
                return try await secondary.getCompletionCount(habitId: habitId, date: date)
            }
            throw error
        }
    }
}

// MARK: - Logging

private let logger = Logger(subsystem: "com.habitto.app", category: "DualWriteHabitRepository")
