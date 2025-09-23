import Foundation

// MARK: - Segmented Storage for Scalability

actor SegmentedHabitStore: ObservableObject {
    static let shared = SegmentedHabitStore()
    
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let mainHabitsURL: URL
    private let historyDirectoryURL: URL
    private let userId: String
    
    // Keep main file small (<5MB) - only current habits, no history
    private let maxMainFileSize = 5 * 1024 * 1024 // 5MB
    
    private init() {
        self.userId = "default_user" // In production, from auth
        self.documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.mainHabitsURL = documentsURL.appendingPathComponent("habits_main.json")
        self.historyDirectoryURL = documentsURL.appendingPathComponent("habit_history")
        
        // Create history directory
        try? fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Main Habits Storage (Small, Fast)
    
    func loadMainHabits() async -> [Habit] {
        do {
            let data = try Data(contentsOf: mainHabitsURL)
            let container = try JSONDecoder().decode(MainHabitsContainer.self, from: data)
            return container.habits
        } catch {
            print("⚠️ SegmentedHabitStore: Failed to load main habits: \(error)")
            return []
        }
    }
    
    func saveMainHabits(_ habits: [Habit]) async throws {
        let container = MainHabitsContainer(habits: habits, version: "1.0.0")
        let data = try JSONEncoder().encode(container)
        
        // Check if we're approaching size limits
        if data.count > maxMainFileSize {
            let suggestion = generateCleanupSuggestion(currentSize: data.count, limit: maxMainFileSize)
            throw SegmentedStorageError.dataSizeExceeded(
                current: data.count,
                limit: maxMainFileSize,
                suggestion: suggestion
            )
        }
        
        // Atomic write with same pattern as CrashSafeHabitStore
        try await atomicWrite(data: data, to: mainHabitsURL)
    }
    
    // MARK: - History Storage (Append-Only, Segmented)
    
    func appendCompletionHistory(habitId: UUID, date: Date, completion: Int) async throws {
        let monthKey = DateUtils.monthKey(for: date)
        let historyFileURL = historyDirectoryURL.appendingPathComponent("\(habitId.uuidString)_\(monthKey).json")
        
        // Load existing month data or create new
        let existingHistory = await loadMonthHistory(at: historyFileURL)
        
        let dateKey = DateUtils.dateKey(for: date)
        var updatedCompletions = existingHistory.completions
        updatedCompletions[dateKey] = completion
        
        let updatedHistory = MonthHistoryContainer(
            habitId: existingHistory.habitId,
            month: existingHistory.month,
            completions: updatedCompletions
        )
        
        // Append-only write (no need for complex atomic operations on history)
        let data = try JSONEncoder().encode(updatedHistory)
        try data.write(to: historyFileURL)
        
        print("📝 SegmentedHabitStore: Appended completion for \(habitId) on \(dateKey)")
    }
    
    func loadCompletionHistory(habitId: UUID, from startDate: Date, to endDate: Date) async -> [String: Int] {
        var allCompletions: [String: Int] = [:]
        
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            let monthKey = DateUtils.monthKey(for: currentDate)
            let historyFileURL = historyDirectoryURL.appendingPathComponent("\(habitId.uuidString)_\(monthKey).json")
            
            let monthHistory = await loadMonthHistory(at: historyFileURL)
            allCompletions.merge(monthHistory.completions) { _, new in new }
            
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? endDate
        }
        
        return allCompletions
    }
    
    private func loadMonthHistory(at url: URL) async -> MonthHistoryContainer {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(MonthHistoryContainer.self, from: data)
        } catch {
            return MonthHistoryContainer(habitId: UUID(), month: "", completions: [:])
        }
    }
    
    // MARK: - Atomic Write Helper
    
    private func atomicWrite(data: Data, to url: URL) async throws {
        let tempURL = url.deletingPathExtension().appendingPathExtension("tmp.\(UUID().uuidString)")
        
        defer { try? fileManager.removeItem(at: tempURL) }
        
        // Create empty file and write via handle
        fileManager.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        try fileHandle.write(contentsOf: data)
        try fileHandle.synchronize()
        try fileHandle.close()
        
        // Set protection and exclude from backup
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: tempURL.path
        )
        // Exclude temp file from backup
        try? (tempURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        
        // Atomic replace
        _ = try fileManager.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
        
        // Re-assert protection
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
    
    // MARK: - Cleanup and Maintenance
    
    func cleanupOldHistory(olderThanMonths: Int = 24) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -olderThanMonths, to: Date()) ?? Date()
        let cutoffKey = DateUtils.monthKey(for: cutoffDate)
        
        let historyFiles = try fileManager.contentsOfDirectory(at: historyDirectoryURL, includingPropertiesForKeys: [.creationDateKey])
        
        for fileURL in historyFiles {
            let filename = fileURL.lastPathComponent
            if let monthKey = extractMonthKey(from: filename),
               monthKey < cutoffKey {
                try fileManager.removeItem(at: fileURL)
                print("🗑️ SegmentedHabitStore: Cleaned up old history: \(filename)")
            }
        }
    }
    
    private func extractMonthKey(from filename: String) -> String? {
        // Extract month key from filename like "habitId_2024-01.json"
        let components = filename.components(separatedBy: "_")
        guard components.count >= 2 else { return nil }
        let monthPart = components[1].replacingOccurrences(of: ".json", with: "")
        return monthPart
    }
    
    private func generateCleanupSuggestion(currentSize: Int, limit: Int) -> String {
        let currentMB = currentSize / 1024 / 1024
        let limitMB = limit / 1024 / 1024
        let excessMB = currentMB - limitMB
        
        if excessMB < 2 {
            return "Main file is \(currentMB)MB (limit: \(limitMB)MB). Consider archiving completed habits or moving to SwiftData for larger datasets."
        } else if excessMB < 10 {
            return "Main file is \(currentMB)MB (limit: \(limitMB)MB). Archive old habits or enable SwiftData migration. Contact support if needed."
        } else {
            return "Main file is \(currentMB)MB (limit: \(limitMB)MB). Immediate cleanup required. Archive completed habits, delete old data, or upgrade to SwiftData. Contact support."
        }
    }
}

// MARK: - Data Containers

struct MainHabitsContainer: Codable {
    let version: String
    let habits: [Habit]
    let lastUpdated: Date
    
    init(habits: [Habit], version: String) {
        self.habits = habits
        self.version = version
        self.lastUpdated = Date()
    }
}

struct MonthHistoryContainer: Codable {
    let habitId: UUID
    let month: String // "2024-01"
    let completions: [String: Int] // dateKey -> completion count
    let lastUpdated: Date
    
    init(habitId: UUID, month: String, completions: [String: Int]) {
        self.habitId = habitId
        self.month = month
        self.completions = completions
        self.lastUpdated = Date()
    }
}

// MARK: - Segmented Storage Error

enum SegmentedStorageError: LocalizedError {
    case dataSizeExceeded(current: Int, limit: Int, suggestion: String)
    case fileSystemError(Error)
    case encodingError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .dataSizeExceeded(let current, let limit, let suggestion):
            return "Data size exceeded: \(current) bytes > \(limit) bytes limit. \(suggestion)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Date Utils Extension

extension DateUtils {
    static func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
