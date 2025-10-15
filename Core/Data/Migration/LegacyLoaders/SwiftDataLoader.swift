import Foundation
import SwiftData
import OSLog

// Import the protocol from BackfillJob
protocol LegacyAggregateLoaderProtocol {
    func enumerate(from lastKey: String?) async throws -> [LegacyDataItem]
}

// MARK: - SwiftData Legacy Loader

/// Loads legacy data from SwiftData models for migration to Firestore
@MainActor
final class SwiftDataLoader: LegacyAggregateLoaderProtocol {
    
    private let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftDataLoader")
    
    init(modelContainer: ModelContainer? = nil) {
        // Use existing SwiftData container or create a new one
        if let container = modelContainer {
            self.modelContainer = container
        } else {
            // TODO: Get the actual SwiftData container from your existing setup
            // This should connect to your existing SwiftDataContainer
            self.modelContainer = try! ModelContainer(for: HabitData.self)
        }
        
        logger.info("🔧 SwiftDataLoader: Initialized with SwiftData container")
    }
    
    // MARK: - LegacyAggregateLoader Implementation
    
    func enumerate(from lastKey: String?) async throws -> [LegacyDataItem] {
        // TODO: Get actual userId from authentication context
        let userId = "current_user_id" // Placeholder
        return try await enumerateItems(for: userId, from: lastKey)
    }
    
    func enumerateItems(for userId: String, from lastKey: String?) async throws -> [LegacyDataItem] {
        logger.info("📥 SwiftDataLoader: Enumerating items for user \(userId) from key: \(lastKey ?? "start")")
        
        var allItems: [LegacyDataItem] = []
        
        // Load habits
        let habits = try await loadHabits(for: userId, from: lastKey)
        allItems.append(contentsOf: habits)
        
        // Load completions
        let completions = try await loadCompletions(for: userId, from: lastKey)
        allItems.append(contentsOf: completions)
        
        // Load XP data
        let xpData = try await loadXPData(for: userId, from: lastKey)
        allItems.append(contentsOf: xpData)
        
        // Load streaks
        let streaks = try await loadStreaks(for: userId, from: lastKey)
        allItems.append(contentsOf: streaks)
        
        // Sort by stable key for consistent ordering
        allItems.sort { $0.stableKey < $1.stableKey }
        
        logger.info("📥 SwiftDataLoader: Loaded \(allItems.count) total items for user \(userId)")
        return allItems
    }
    
    func getItemCount(for userId: String) async throws -> Int {
        let context = modelContainer.mainContext
        
        // Count habits
        let habitDescriptor = FetchDescriptor<HabitData>(
            predicate: #Predicate<HabitData> { $0.userId == userId }
        )
        let habitCount = try context.fetchCount(habitDescriptor)
        
        // Count completions
        let completionDescriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate<CompletionRecord> { completion in
                // This assumes CompletionRecord has a way to link to userId
                // You may need to adjust this based on your actual model structure
                true // Placeholder - implement based on your actual relationship
            }
        )
        let completionCount = try context.fetchCount(completionDescriptor)
        
        // Count XP ledger entries
        let xpDescriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate<UsageRecord> { _ in
                true // Placeholder - implement based on your actual model
            }
        )
        let xpCount = try context.fetchCount(xpDescriptor)
        
        let total = habitCount + completionCount + xpCount
        logger.debug("📊 SwiftDataLoader: Estimated \(total) items for user \(userId)")
        return total
    }
    
    // MARK: - Private Loading Methods
    
    private func loadHabits(for userId: String, from lastKey: String?) async throws -> [LegacyDataItem] {
        let context = modelContainer.mainContext
        
        let descriptor = FetchDescriptor<HabitData>(
            predicate: #Predicate<HabitData> { $0.userId == userId },
            sortBy: [SortDescriptor(\.id)]
        )
        
        // Apply pagination if lastKey is provided
        if lastKey != nil {
            // TODO: Implement proper pagination based on your model structure
            // This is a placeholder - you'll need to adjust based on how you want to paginate
        }
        
        let habits = try context.fetch(descriptor)
        
        return habits.compactMap { habit in
            LegacyDataItem(
                type: .habit,
                stableKey: habit.id.uuidString,
                data: mapHabitToDictionary(habit),
                userId: userId,
                createdAt: habit.createdAt,
                updatedAt: habit.updatedAt
            )
        }
    }
    
    private func loadCompletions(for userId: String, from lastKey: String?) async throws -> [LegacyDataItem] {
        let context = modelContainer.mainContext
        
        let descriptor = FetchDescriptor<CompletionRecord>(
            sortBy: [SortDescriptor<CompletionRecord>(\.date)]
        )
        
        let completions = try context.fetch(descriptor)
        
        return completions.compactMap { completion in
            // Generate stable key based on habit ID and date
            let dateKey = ISO8601DateHelper.shared.string(from: completion.date)
            let stableKey = "\(completion.habitId.uuidString)_\(dateKey)"
            
            return LegacyDataItem(
                type: .completion,
                stableKey: stableKey,
                data: mapCompletionToDictionary(completion),
                userId: userId,
                createdAt: completion.createdAt
            )
        }
    }
    
    private func loadXPData(for userId: String, from lastKey: String?) async throws -> [LegacyDataItem] {
        let context = modelContainer.mainContext
        var items: [LegacyDataItem] = []
        
        // Load XP state
        let xpStateDescriptor = FetchDescriptor<UserProgressData>()
        let xpStates = try context.fetch(xpStateDescriptor)
        
        for xpState in xpStates {
            let item = LegacyDataItem(
                type: .xpState,
                stableKey: "xp_state_\(userId)",
                data: mapXPStateToDictionary(xpState),
                userId: userId,
                createdAt: xpState.createdAt,
                updatedAt: xpState.updatedAt
            )
            items.append(item)
        }
        
        // Load XP ledger entries
        let xpLedgerDescriptor = FetchDescriptor<UsageRecord>(
            sortBy: [SortDescriptor<UsageRecord>(\.createdAt)]
        )
        let xpLedgerEntries = try context.fetch(xpLedgerDescriptor)
        
        for (index, entry) in xpLedgerEntries.enumerated() {
            let item = LegacyDataItem(
                type: .xpLedger,
                stableKey: "xp_ledger_\(index)_\(entry.createdAt.timeIntervalSince1970)",
                data: mapXPEntryToDictionary(entry),
                userId: userId,
                createdAt: entry.createdAt
            )
            items.append(item)
        }
        
        return items
    }
    
    private func loadStreaks(for userId: String, from lastKey: String?) async throws -> [LegacyDataItem] {
        // TODO: Implement streak loading based on your actual streak model
        // This is a placeholder - you may need to calculate streaks from completion data
        return []
    }
    
    // MARK: - Data Mapping Methods
    
    private func mapHabitToDictionary(_ habit: HabitData) -> [String: Any] {
        return [
            "id": habit.id.uuidString,
            "userId": habit.userId,
            "name": habit.name,
            "habitDescription": habit.habitDescription,
            "icon": habit.icon,
            "colorData": habit.colorData as Any,
            "habitType": habit.habitType,
            "schedule": habit.schedule,
            "goal": habit.goal,
            "reminder": habit.reminder,
            "startDate": habit.startDate,
            "endDate": habit.endDate as Any,
            "createdAt": habit.createdAt,
            "updatedAt": habit.updatedAt
        ]
    }
    
    private func mapCompletionToDictionary(_ completion: CompletionRecord) -> [String: Any] {
        return [
            "userId": completion.userId,
            "habitId": completion.habitId.uuidString,
            "date": completion.date,
            "dateKey": completion.dateKey,
            "isCompleted": completion.isCompleted,
            "createdAt": completion.createdAt,
            "userIdHabitIdDateKey": completion.userIdHabitIdDateKey
        ]
    }
    
    private func mapXPStateToDictionary(_ xpState: UserProgressData) -> [String: Any] {
        return [
            "userId": xpState.userId,
            "xpTotal": xpState.xpTotal,
            "level": xpState.level,
            "xpForCurrentLevel": xpState.xpForCurrentLevel,
            "xpForNextLevel": xpState.xpForNextLevel,
            "dailyXP": xpState.dailyXP,
            "lastCompletedDate": xpState.lastCompletedDate as Any,
            "streakDays": xpState.streakDays,
            "createdAt": xpState.createdAt
        ]
    }
    
    private func mapXPEntryToDictionary(_ entry: UsageRecord) -> [String: Any] {
        return [
            "key": entry.key,
            "value": entry.value,
            "createdAt": entry.createdAt
        ]
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
