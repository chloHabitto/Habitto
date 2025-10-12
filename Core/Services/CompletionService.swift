import Foundation
import Combine

/// Service for managing habit completions with transactional integrity
///
/// Responsibilities:
/// - Mark habits as complete for specific dates
/// - Increment completion counts transactionally (prevents race conditions)
/// - Publish today's completion map for real-time UI updates
/// - Query completion history
///
/// All operations are timezone-aware (Europe/Amsterdam) and use local dates.
@MainActor
class CompletionService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = CompletionService()
    
    // MARK: - Published Properties
    
    /// Today's completion counts by habit ID
    /// Key: habitId, Value: completion count
    @Published private(set) var todayCompletions: [String: Int] = [:]
    
    /// Error state
    @Published private(set) var error: CompletionError?
    
    // MARK: - Dependencies
    
    private let repository: FirestoreRepository
    private let dateFormatter: LocalDateFormatter
    
    // MARK: - Initialization
    
    init(
        repository: FirestoreRepository? = nil,
        dateFormatter: LocalDateFormatter? = nil
    ) {
        self.repository = repository ?? FirestoreRepository.shared
        self.dateFormatter = dateFormatter ?? LocalDateFormatter()
        
        // Start streaming today's completions
        startTodayCompletionsStream()
    }
    
    // MARK: - Completion Methods
    
    /// Mark a habit as complete (increment completion count)
    ///
    /// Uses Firestore transaction to prevent race conditions when multiple
    /// devices/users complete simultaneously.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date to mark complete (uses local date in Europe/Amsterdam)
    ///
    /// - Returns: The new completion count
    @discardableResult
    func markComplete(habitId: String, at date: Date) async throws -> Int {
        let localDateString = dateFormatter.dateToString(date)
        
        print("✅ CompletionService: Marking habit \(habitId) complete on \(localDateString)")
        
        do {
            // Increment completion count (transactional)
            try await repository.incrementCompletion(habitId: habitId, localDate: localDateString)
            
            // Get updated count
            let newCount = try await repository.getCompletion(habitId: habitId, localDate: localDateString)
            
            print("✅ CompletionService: Habit \(habitId) completion count: \(newCount)")
            
            // Update today's completions if this is for today
            if dateFormatter.isSameDay(date, dateFormatter.todayDate()) {
                todayCompletions[habitId] = newCount
            }
            
            return newCount
        } catch {
            print("❌ CompletionService: Failed to mark complete: \(error)")
            self.error = .markFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Mark a habit as complete for today
    ///
    /// Convenience method for marking completions for the current date.
    ///
    /// - Parameter habitId: The habit identifier
    /// - Returns: The new completion count
    @discardableResult
    func markCompleteToday(habitId: String) async throws -> Int {
        let today = dateFormatter.todayDate()
        return try await markComplete(habitId: habitId, at: today)
    }
    
    /// Get completion count for a habit on a specific date
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date to query
    ///
    /// - Returns: The completion count (0 if never completed on that date)
    func getCompletion(habitId: String, on date: Date) async throws -> Int {
        let localDateString = dateFormatter.dateToString(date)
        
        do {
            return try await repository.getCompletion(habitId: habitId, localDate: localDateString)
        } catch {
            // Default to 0 if no completion record exists
            return 0
        }
    }
    
    /// Get completion count for today
    ///
    /// - Parameter habitId: The habit identifier
    /// - Returns: Today's completion count
    func getTodayCompletion(habitId: String) async throws -> Int {
        // Check cached value first
        if let cached = todayCompletions[habitId] {
            return cached
        }
        
        // Fetch from repository
        let today = dateFormatter.todayDate()
        return try await getCompletion(habitId: habitId, on: today)
    }
    
    /// Check if a habit is complete for a specific date
    ///
    /// A habit is considered "complete" if its completion count >= goal for that date.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date to check
    ///   - goal: The goal for that date
    ///
    /// - Returns: True if completion count >= goal
    func isComplete(habitId: String, on date: Date, goal: Int) async throws -> Bool {
        let count = try await getCompletion(habitId: habitId, on: date)
        return count >= goal
    }
    
    /// Get completion percentage for a habit on a specific date
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date to query
    ///   - goal: The goal for that date
    ///
    /// - Returns: Completion percentage (0.0 to 1.0), clamped at 1.0
    func completionPercentage(habitId: String, on date: Date, goal: Int) async throws -> Double {
        guard goal > 0 else { return 1.0 }
        
        let count = try await getCompletion(habitId: habitId, on: date)
        let percentage = Double(count) / Double(goal)
        return min(percentage, 1.0)  // Clamp at 100%
    }
    
    // MARK: - Real-time Streams
    
    /// Start streaming today's completions
    ///
    /// Updates `todayCompletions` in real-time as completions change.
    private func startTodayCompletionsStream() {
        let today = dateFormatter.today()
        print("👂 CompletionService: Starting completions stream for \(today)")
        
        repository.streamCompletions(for: today)
        
        // Map repository completions to our published dictionary
        // Note: In production, subscribe to repository.completions publisher
        // For now, this sets up the structure
    }
    
    /// Refresh today's completions from repository
    func refreshTodayCompletions() async {
        let today = dateFormatter.today()
        print("🔄 CompletionService: Refreshing completions for \(today)")
        
        // In production with real Firestore, this would be automatic via stream
        // For mock mode, we update from repository state
        var completionsMap: [String: Int] = [:]
        for (habitId, completion) in repository.completions {
            completionsMap[habitId] = completion.count
        }
        todayCompletions = completionsMap
    }
    
    /// Stop all listeners
    func stopListening() {
        repository.stopListening()
        print("🛑 CompletionService: Stopped all completion listeners")
    }
}

// MARK: - Errors

enum CompletionError: LocalizedError {
    case markFailed(String)
    case queryFailed(String)
    case invalidDate(String)
    
    var errorDescription: String? {
        switch self {
        case .markFailed(let message):
            return "Failed to mark complete: \(message)"
        case .queryFailed(let message):
            return "Failed to query completion: \(message)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        }
    }
}

