import Foundation
import SwiftUI

// MARK: - Lightweight Data Usage Analytics
/// Simple, on-demand storage analysis for habit tracking app
@MainActor
class DataUsageAnalytics: ObservableObject {
    static let shared = DataUsageAnalytics()
    
    // MARK: - Published Properties
    @Published var lastSnapshot: StorageSnapshot?
    @Published var optimizationSuggestions: [OptimizationSuggestion] = []
    
    // MARK: - Private Properties
    private var backgroundTask: Task<Void, Never>?
    
    private init() {
        // Load last snapshot if available
        loadLastSnapshot()
    }
    
    // MARK: - Public Methods
    
    /// Take a simple storage snapshot on-demand
    func takeStorageSnapshot() async -> StorageSnapshot {
        // Skip analytics during vacation mode
        if VacationManager.shared.isActive {
            print("📊 DataUsageAnalytics: Skipping storage snapshot during vacation mode")
            // Return cached snapshot if available, otherwise create minimal snapshot
            if let cached = lastSnapshot {
                return cached
            }
            return StorageSnapshot(
                id: UUID(),
                totalSize: 0,
                habitCount: 0,
                cacheSize: 0,
                lastCleanupDate: nil,
                timestamp: Date()
            )
        }
        
        let snapshot = await createSnapshot()
        
        // Update UI on main actor
        lastSnapshot = snapshot
        
        // Save for next app launch
        saveSnapshot(snapshot)
        
        return snapshot
    }
    
    /// Analyze storage and generate actionable suggestions
    func analyzeStorageOnDemand() async -> [OptimizationSuggestion] {
        // Skip analytics during vacation mode
        if VacationManager.shared.isActive {
            print("📊 DataUsageAnalytics: Skipping storage analysis during vacation mode")
            return []
        }
        
        let snapshot = await takeStorageSnapshot()
        let suggestions = generateActionableSuggestions(from: snapshot)
        
        optimizationSuggestions = suggestions
        return suggestions
    }
    
    /// Pause analytics when app goes to background
    func pauseTracking() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }
    
    /// Resume analytics when app becomes active (if needed)
    func resumeTracking() {
        // Only resume if explicitly needed for specific analysis
        // No continuous monitoring by default
    }
    
    // MARK: - Private Methods
    
    private func createSnapshot() async -> StorageSnapshot {
        var totalSize: Int64 = 0
        var habitCount = 0
        let cacheSize: Int64 = 0
        var lastCleanupDate: Date?
        
        // Measure SwiftData storage
        do {
            let habitRepository = HabitRepository.shared
            let habits = habitRepository.habits
            habitCount = habits.count
            
            // Rough estimate: each habit ~1KB, each completion record ~100 bytes
            let estimatedHabitSize = Int64(habitCount * 1024)
            let estimatedCompletionSize = Int64(habits.reduce(0) { total, habit in
                total + habit.completionHistory.count * 100
            })
            totalSize += estimatedHabitSize + estimatedCompletionSize
        }
        
        // Measure UserDefaults (simplified)
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "app_settings") {
            totalSize += Int64(data.count)
        }
        
        // Get last cleanup date from app settings
        lastCleanupDate = userDefaults.object(forKey: "last_cleanup_date") as? Date
        
        return StorageSnapshot(
            id: UUID(),
            totalSize: totalSize,
            habitCount: habitCount,
            cacheSize: cacheSize,
            lastCleanupDate: lastCleanupDate,
            timestamp: Date()
        )
    }
    
    private func generateActionableSuggestions(from snapshot: StorageSnapshot) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        // Only suggest cleanup if data is getting large (>10MB) or hasn't been cleaned in 30 days
        let tenMB: Int64 = 10 * 1024 * 1024
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        if snapshot.totalSize > tenMB {
            suggestions.append(OptimizationSuggestion(
                id: UUID(),
                type: .cleanup,
                priority: .medium,
                description: "App data is getting large (\(formatBytes(snapshot.totalSize))). Consider cleaning old completion records.",
                potentialSavings: snapshot.totalSize / 4, // Rough estimate
                isApplied: false
            ))
        }
        
        if let lastCleanup = snapshot.lastCleanupDate, lastCleanup < thirtyDaysAgo {
            suggestions.append(OptimizationSuggestion(
                id: UUID(),
                type: .maintenance,
                priority: .low,
                description: "Haven't cleaned up old data in a while. Regular cleanup helps keep the app running smoothly.",
                potentialSavings: snapshot.totalSize / 8,
                isApplied: false
            ))
        }
        
        // Only suggest if user has many habits (>50) - might want to archive some
        if snapshot.habitCount > 50 {
            suggestions.append(OptimizationSuggestion(
                id: UUID(),
                type: .organization,
                priority: .low,
                description: "You have \(snapshot.habitCount) habits. Consider archiving completed or inactive ones.",
                potentialSavings: 0, // No storage savings, just organization
                isApplied: false
            ))
        }
        
        return suggestions
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func saveSnapshot(_ snapshot: StorageSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: "last_storage_snapshot")
        } catch {
            print("📊 DataUsageAnalytics: Failed to save snapshot: \(error)")
        }
    }
    
    private func loadLastSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: "last_storage_snapshot") else { return }
        
        do {
            lastSnapshot = try JSONDecoder().decode(StorageSnapshot.self, from: data)
        } catch {
            print("📊 DataUsageAnalytics: Failed to load last snapshot: \(error)")
        }
    }
}

// MARK: - Simplified Data Models

struct StorageSnapshot: Codable, Identifiable {
    let id: UUID
    let totalSize: Int64
    let habitCount: Int
    let cacheSize: Int64
    let lastCleanupDate: Date?
    let timestamp: Date
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    var isHealthy: Bool {
        let tenMB: Int64 = 10 * 1024 * 1024
        return totalSize < tenMB
    }
}

struct OptimizationSuggestion: Codable, Identifiable {
    let id: UUID
    let type: OptimizationType
    let priority: OptimizationPriority
    let description: String
    let potentialSavings: Int64
    var isApplied: Bool
    
    var formattedSavings: String {
        guard potentialSavings > 0 else { return "No storage impact" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: potentialSavings)
    }
}

enum OptimizationType: String, Codable, CaseIterable {
    case cleanup = "cleanup"
    case maintenance = "maintenance"
    case organization = "organization"
    
    var displayName: String {
        switch self {
        case .cleanup: return "Storage Cleanup"
        case .maintenance: return "Maintenance"
        case .organization: return "Organization"
        }
    }
}

enum OptimizationPriority: Int, Codable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var priorityColor: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

// MARK: - Usage Examples

/*
 Usage Examples:
 
 // ✅ Simple on-demand analysis
 let snapshot = await DataUsageAnalytics.shared.takeStorageSnapshot()
 print("App size: \(snapshot.formattedSize)")
 
 // ✅ Get actionable suggestions
 let suggestions = await DataUsageAnalytics.shared.analyzeStorageOnDemand()
 for suggestion in suggestions {
     print("\(suggestion.type.displayName): \(suggestion.description)")
 }
 
 // ✅ Check if storage is healthy
 if snapshot.isHealthy {
     print("Storage is in good shape!")
 }
 
 // ✅ App lifecycle management
 func applicationDidEnterBackground() {
     DataUsageAnalytics.shared.pauseTracking()
 }
 
 func applicationDidBecomeActive() {
     // Only analyze if user explicitly requests it
     // No automatic continuous monitoring
 }
 */