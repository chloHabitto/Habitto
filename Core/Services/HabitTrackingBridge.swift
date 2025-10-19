import Foundation
import SwiftData

/// Bridge between old UI and new architecture
///
/// **Purpose:**
/// - Provides backward-compatible API
/// - Routes to new services when feature flags enabled
/// - Falls back to old system when flags disabled
/// - Enables gradual migration and A/B testing
///
/// **Usage:**
/// ```swift
/// let bridge = HabitTrackingBridge(userId: currentUserId)
/// try bridge.markCompleted(habit: &habit, for: Date())
/// ```
@MainActor
class HabitTrackingBridge {
    
    // MARK: - Properties
    
    private let featureFlags = NewArchitectureFlags.shared
    private var serviceContainer: ServiceContainer?
    private let userId: String
    
    // MARK: - Initialization
    
    /// Initialize bridge for a user
    /// - Parameter userId: The user ID to track habits for
    init(userId: String) {
        self.userId = userId
        
        print("🌉 HabitTrackingBridge: Initializing for user '\(userId)'...")
        
        // Try to initialize new services
        do {
            self.serviceContainer = try ServiceContainer(userId: userId)
            print("✅ HabitTrackingBridge: New services ready")
        } catch {
            print("⚠️ HabitTrackingBridge: Failed to init services: \(error)")
            print("   Will fall back to old system if new features enabled")
        }
    }
    
    // MARK: - Progress Tracking
    
    /// Mark habit as completed
    ///
    /// **Routes based on feature flag:**
    /// - If `useNewProgressTracking` enabled → uses new ServiceContainer
    /// - Otherwise → uses old Habit.markCompleted()
    ///
    /// **Dual-write strategy:**
    /// - Updates both old and new systems
    /// - Ensures data consistency during migration
    func markCompleted(habit: inout Habit, for date: Date) throws {
        let dateKey = DateUtils.dateKey(for: date)
        
        if featureFlags.useNewProgressTracking, let container = serviceContainer {
            // ✅ Use new system
            print("🆕 Bridge: Using NEW progress tracking for '\(habit.name)' on \(dateKey)")
            
            do {
                // Convert old Habit to new HabitModel
                let habitModel = try convertToHabitModel(habit)
                
                // Use new services
                let result = try container.completeHabit(habitModel, on: date)
                
                // Dual-write: Also update old habit for backward compatibility
                habit.markCompleted(for: date)
                
                // Log results
                print("  ✅ Progress updated")
                if result.allHabitsComplete {
                    print("  🎉 All habits complete! +\(result.xpAwarded) XP")
                    if result.streakUpdated {
                        print("  🔥 Streak updated")
                    }
                }
            } catch {
                print("  ❌ New system failed: \(error)")
                print("  📦 Falling back to old system")
                habit.markCompleted(for: date)
            }
            
        } else {
            // 📦 Use old system
            print("📦 Bridge: Using OLD progress tracking for '\(habit.name)' on \(dateKey)")
            habit.markCompleted(for: date)
        }
    }
    
    /// Mark habit as incomplete (undo)
    ///
    /// **Routes based on feature flag:**
    /// - If `useNewProgressTracking` enabled → uses new ServiceContainer
    /// - Otherwise → uses old Habit.markIncomplete()
    func markIncomplete(habit: inout Habit, for date: Date) throws {
        let dateKey = DateUtils.dateKey(for: date)
        
        if featureFlags.useNewProgressTracking, let container = serviceContainer {
            // ✅ Use new system
            print("🆕 Bridge: Using NEW progress tracking (undo) for '\(habit.name)' on \(dateKey)")
            
            do {
                let habitModel = try convertToHabitModel(habit)
                let result = try container.uncompleteHabit(habitModel, on: date)
                
                // Dual-write: Also update old habit
                habit.markIncomplete(for: date)
                
                // Log results
                print("  ⬇️ Progress decremented")
                if result.xpRemoved > 0 {
                    print("  💔 Lost \(result.xpRemoved) XP")
                    if result.streakBroken {
                        print("  🔄 Streak recalculated")
                    }
                }
            } catch {
                print("  ❌ New system failed: \(error)")
                print("  📦 Falling back to old system")
                habit.markIncomplete(for: date)
            }
            
        } else {
            // 📦 Use old system
            print("📦 Bridge: Using OLD progress tracking (undo) for '\(habit.name)' on \(dateKey)")
            habit.markIncomplete(for: date)
        }
    }
    
    // MARK: - Dashboard Stats (Optional)
    
    /// Get dashboard stats from new system
    /// - Returns: Stats if new system enabled, nil otherwise
    func getDashboardStats(on date: Date = Date()) -> DashboardStats? {
        guard featureFlags.useNewArchitecture, let container = serviceContainer else {
            return nil
        }
        
        do {
            return try container.getDashboardStats(on: date)
        } catch {
            print("⚠️ Bridge: Failed to get dashboard stats: \(error)")
            return nil
        }
    }
    
    // MARK: - Conversion Helpers
    
    /// Convert old Habit struct to new HabitModel
    private func convertToHabitModel(_ habit: Habit) throws -> HabitModel {
        // Parse schedule from legacy string
        let schedule = HabitSchedule.fromLegacyString(habit.schedule)
        
        // Parse goal string (e.g., "5 times", "30 minutes")
        let goalComponents = parseGoalString(habit.goal)
        
        // Create HabitModel
        let habitModel = HabitModel(
            id: habit.id,
            userId: userId,
            name: habit.name,
            habitDescription: habit.description,
            icon: habit.icon,
            color: habit.colorValue,
            habitType: habit.habitType,
            goalCount: goalComponents.count,
            goalUnit: goalComponents.unit,
            schedule: schedule,
            baselineCount: habit.habitType == .breaking ? habit.baseline : nil,
            baselineUnit: habit.habitType == .breaking ? goalComponents.unit : nil,
            startDate: habit.startDate,
            endDate: habit.endDate
        )
        
        return habitModel
    }
    
    /// Parse goal string into count and unit
    /// - Examples: "5 times" → (5, "times"), "30 minutes" → (30, "minutes")
    private func parseGoalString(_ goalString: String) -> (count: Int, unit: String) {
        let trimmed = goalString.trimmingCharacters(in: .whitespaces)
        let components = trimmed.components(separatedBy: " ")
        
        // Extract count (first number)
        let count = components.compactMap { Int($0) }.first ?? 1
        
        // Extract unit (word after number, or everything after first space)
        if let numberIndex = components.firstIndex(where: { Int($0) != nil }),
           numberIndex + 1 < components.count {
            // Join all words after the number
            let unitComponents = components[(numberIndex + 1)...]
            let unit = unitComponents.joined(separator: " ")
            return (count, unit.isEmpty ? "time" : unit)
        }
        
        // Fallback: if no number found, try to parse differently
        // "times" → (1, "times")
        if components.count == 1 {
            return (1, components[0])
        }
        
        return (count, "time")
    }
}

// MARK: - Errors

enum BridgeError: LocalizedError {
    case serviceContainerNotInitialized
    case conversionFailed(String)
    case oldHabitNotFound
    
    var errorDescription: String? {
        switch self {
        case .serviceContainerNotInitialized:
            return "Service container not initialized"
        case .conversionFailed(let reason):
            return "Failed to convert habit: \(reason)"
        case .oldHabitNotFound:
            return "Old habit not found"
        }
    }
}

