import Foundation

// MARK: - HabitRepository Protocol

/// Protocol defining the interface for habit data operations
/// Supports both real-time streaming and one-time operations
protocol HabitRepositoryProtocol {
    /// Create a new habit
    func create(_ habit: Habit) async throws
    
    /// Update an existing habit
    func update(_ habit: Habit) async throws
    
    /// Delete a habit by ID
    func delete(id: String) async throws
    
    /// Get a single habit with real-time updates
    func habit(by id: String) -> AsyncThrowingStream<Habit?, Error>
    
    /// Get all habits with real-time updates
    func habits() -> AsyncThrowingStream<[Habit], Error>
    
    /// Get habits for a specific date
    func habits(for date: Date) async throws -> [Habit]
    
    /// Mark a habit as completed for a specific date
    func markComplete(habitId: String, date: Date, count: Int) async throws -> Int
    
    /// Get completion count for a habit on a specific date
    func getCompletionCount(habitId: String, date: Date) async throws -> Int
}

// MARK: - AsyncThrowingStream Extensions

extension AsyncThrowingStream {
    /// Get the first value from the stream
    func firstValue() async throws -> Element? {
        var iterator = makeAsyncIterator()
        return try await iterator.next()
    }
}

extension AsyncThrowingStream {
    /// Transform elements in the stream
    func map<T>(_ transform: @escaping (Element) async throws -> T) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream<T, Error> { continuation in
            Task {
                do {
                    for try await value in self {
                        let transformed = try await transform(value)
                        continuation.yield(transformed)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
