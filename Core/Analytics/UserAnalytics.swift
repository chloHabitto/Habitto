import Foundation
import SwiftUI

// MARK: - User Analytics
/// Tracks user behavior and engagement patterns
@MainActor
class UserAnalytics: ObservableObject {
    static let shared = UserAnalytics()
    
    // MARK: - Published Properties
    @Published var isTracking = false
    @Published var currentSession: UserSession = UserSession()
    @Published var userProfile: UserProfile = UserProfile()
    @Published var engagementMetrics: EngagementMetrics = EngagementMetrics()
    
    // MARK: - Private Properties
    private let analyticsStorage = AnalyticsStorage()
    private var sessionStartTime: Date?
    private var lastActivityTime: Date?
    private var activityTimer: Timer?
    
    private init() {
        loadUserProfile()
        loadEngagementMetrics()
    }
    
    // MARK: - Public Methods
    
    /// Start tracking user analytics
    func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        sessionStartTime = Date()
        lastActivityTime = Date()
        currentSession = UserSession()
        
        // Start activity monitoring
        startActivityMonitoring()
        
        // Record session start
        recordEvent(.sessionStart, metadata: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        print("📊 UserAnalytics: Started tracking")
    }
    
    /// Stop tracking user analytics
    func stopTracking() {
        activityTimer?.invalidate()
        activityTimer = nil
        isTracking = false
        
        // Record session end
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            recordEvent(.sessionEnd, metadata: [
                "duration": String(duration),
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
        
        // Save session data
        saveSessionData()
        
        print("📊 UserAnalytics: Stopped tracking")
    }
    
    /// Record a user event
    func recordEvent(_ event: UserEvent, metadata: [String: String] = [:]) {
        // Skip analytics during vacation mode
        if VacationManager.shared.isActive {
            print("📊 UserAnalytics: Skipping event during vacation mode - \(event.rawValue)")
            return
        }
        
        let eventData = UserEventData(
            type: event,
            timestamp: Date(),
            metadata: metadata
        )
        
        currentSession.events.append(eventData)
        updateEngagementMetrics(for: event)
        
        print("📊 UserAnalytics: Recorded event - \(event.rawValue)")
    }
    
    /// Record habit interaction
    func recordHabitInteraction(_ habitId: UUID, action: HabitAction, metadata: [String: String] = [:]) {
        // Skip analytics during vacation mode
        if VacationManager.shared.isActive {
            print("📊 UserAnalytics: Skipping habit interaction during vacation mode - \(action.rawValue) for habit \(habitId)")
            return
        }
        
        let interaction = HabitInteraction(
            habitId: habitId,
            action: action,
            timestamp: Date(),
            metadata: metadata
        )
        
        currentSession.habitInteractions.append(interaction)
        
        // Update habit-specific metrics
        updateHabitMetrics(habitId: habitId, action: action)
        
        print("📊 UserAnalytics: Recorded habit interaction - \(action.rawValue) for habit \(habitId)")
    }
    
    /// Record screen view
    func recordScreenView(_ screen: ScreenName, metadata: [String: String] = [:]) {
        // Skip analytics during vacation mode
        if VacationManager.shared.isActive {
            print("📊 UserAnalytics: Skipping screen view during vacation mode - \(screen.rawValue)")
            return
        }
        
        let screenView = ScreenView(
            screen: screen,
            timestamp: Date(),
            metadata: metadata
        )
        
        currentSession.screenViews.append(screenView)
        
        // Update screen metrics
        updateScreenMetrics(for: screen)
        
        print("📊 UserAnalytics: Recorded screen view - \(screen.rawValue)")
    }
    
    /// Record user engagement
    func recordEngagement(_ type: EngagementType, value: Double, metadata: [String: String] = [:]) {
        // Skip analytics during vacation mode
        if VacationManager.shared.isActive {
            print("📊 UserAnalytics: Skipping engagement tracking during vacation mode - \(type.rawValue): \(value)")
            return
        }
        
        let engagement = EngagementEvent(
            type: type,
            value: value,
            timestamp: Date(),
            metadata: metadata
        )
        
        currentSession.engagementEvents.append(engagement)
        updateEngagementScore()
        
        print("📊 UserAnalytics: Recorded engagement - \(type.rawValue): \(value)")
    }
    
    /// Get user insights
    func getUserInsights() -> UserInsights {
        return UserInsights(
            mostActiveTime: calculateMostActiveTime(),
            favoriteHabits: getFavoriteHabits(),
            completionRate: calculateCompletionRate(),
            streakPerformance: calculateStreakPerformance(),
            engagementScore: engagementMetrics.overallScore,
            usagePatterns: analyzeUsagePatterns()
        )
    }
    
    /// Get analytics summary
    func getAnalyticsSummary() -> AnalyticsSummary {
        return AnalyticsSummary(
            totalSessions: userProfile.totalSessions,
            totalTimeSpent: userProfile.totalTimeSpent,
            averageSessionDuration: userProfile.averageSessionDuration,
            habitsCreated: userProfile.habitsCreated,
            habitsCompleted: userProfile.habitsCompleted,
            engagementScore: engagementMetrics.overallScore,
            mostUsedFeature: getMostUsedFeature(),
            improvementAreas: getImprovementAreas()
        )
    }
    
    // MARK: - Private Methods
    
    private func startActivityMonitoring() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkActivity()
            }
        }
    }
    
    private func checkActivity() async {
        let now = Date()
        
        // Check if user is still active (within last 5 minutes)
        if let lastActivity = lastActivityTime, now.timeIntervalSince(lastActivity) > 300 {
            // User inactive for 5+ minutes, record as pause
            recordEvent(.sessionPause, metadata: [
                "inactive_duration": String(now.timeIntervalSince(lastActivity))
            ])
        } else {
            // User is active, update last activity time
            lastActivityTime = now
            recordEvent(.userActive, metadata: [:])
        }
    }
    
    private func updateEngagementMetrics(for event: UserEvent) {
        switch event {
        case .habitCreated:
            engagementMetrics.habitsCreated += 1
        case .habitCompleted:
            engagementMetrics.habitsCompleted += 1
        case .habitSkipped:
            engagementMetrics.habitsSkipped += 1
        case .streakAchieved:
            engagementMetrics.streaksAchieved += 1
        case .goalReached:
            engagementMetrics.goalsReached += 1
        case .featureUsed:
            engagementMetrics.featuresUsed += 1
        default:
            break
        }
        
        updateEngagementScore()
    }
    
    private func updateHabitMetrics(habitId: UUID, action: HabitAction) {
        if userProfile.habitMetrics[habitId] == nil {
            userProfile.habitMetrics[habitId] = HabitMetrics()
        }
        
        userProfile.habitMetrics[habitId]?.interactionCount += 1
        
        switch action {
        case .created:
            userProfile.habitsCreated += 1
        case .completed:
            userProfile.habitsCompleted += 1
            userProfile.habitMetrics[habitId]?.completionCount += 1
        case .skipped:
            userProfile.habitMetrics[habitId]?.skipCount += 1
        case .edited:
            userProfile.habitMetrics[habitId]?.editCount += 1
        case .deleted:
            userProfile.habitMetrics[habitId]?.deleteCount += 1
        }
    }
    
    private func updateScreenMetrics(for screen: ScreenName) {
        if userProfile.screenMetrics[screen] == nil {
            userProfile.screenMetrics[screen] = ScreenMetrics()
        }
        
        userProfile.screenMetrics[screen]?.viewCount += 1
        userProfile.screenMetrics[screen]?.lastViewed = Date()
    }
    
    private func updateEngagementScore() {
        let totalInteractions = engagementMetrics.habitsCreated + 
                               engagementMetrics.habitsCompleted + 
                               engagementMetrics.featuresUsed
        
        let completionRate = engagementMetrics.habitsCreated > 0 ? 
            Double(engagementMetrics.habitsCompleted) / Double(engagementMetrics.habitsCreated) : 0.0
        
        let streakRate = engagementMetrics.habitsCompleted > 0 ? 
            Double(engagementMetrics.streaksAchieved) / Double(engagementMetrics.habitsCompleted) : 0.0
        
        engagementMetrics.overallScore = min(1.0, (completionRate * 0.4 + streakRate * 0.3 + min(1.0, Double(totalInteractions) / 100.0) * 0.3))
    }
    
    private func calculateMostActiveTime() -> String {
        let hourCounts = currentSession.events.reduce(into: [Int: Int]()) { counts, event in
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            counts[hour, default: 0] += 1
        }
        
        let mostActiveHour = hourCounts.max(by: { $0.value < $1.value })?.key ?? 12
        return String(format: "%02d:00", mostActiveHour)
    }
    
    private func getFavoriteHabits() -> [UUID] {
        return userProfile.habitMetrics
            .sorted { $0.value.interactionCount > $1.value.interactionCount }
            .prefix(5)
            .map { $0.key }
    }
    
    private func calculateCompletionRate() -> Double {
        guard userProfile.habitsCreated > 0 else { return 0.0 }
        return Double(userProfile.habitsCompleted) / Double(userProfile.habitsCreated)
    }
    
    private func calculateStreakPerformance() -> Double {
        guard engagementMetrics.habitsCompleted > 0 else { return 0.0 }
        return Double(engagementMetrics.streaksAchieved) / Double(engagementMetrics.habitsCompleted)
    }
    
    private func analyzeUsagePatterns() -> [String: Any] {
        let totalSessions = userProfile.totalSessions
        let averageDuration = userProfile.averageSessionDuration
        
        return [
            "session_frequency": totalSessions > 0 ? "Regular" : "New User",
            "session_length": averageDuration > 300 ? "Long" : "Short",
            "engagement_level": engagementMetrics.overallScore > 0.7 ? "High" : engagementMetrics.overallScore > 0.4 ? "Medium" : "Low"
        ]
    }
    
    private func getMostUsedFeature() -> String {
        let featureCounts = userProfile.screenMetrics
            .sorted { $0.value.viewCount > $1.value.viewCount }
        
        return featureCounts.first?.key.rawValue ?? "Unknown"
    }
    
    private func getImprovementAreas() -> [String] {
        var areas: [String] = []
        
        if engagementMetrics.overallScore < 0.5 {
            areas.append("Engagement")
        }
        
        if calculateCompletionRate() < 0.3 {
            areas.append("Habit Completion")
        }
        
        if userProfile.averageSessionDuration < 60 {
            areas.append("Session Duration")
        }
        
        return areas
    }
    
    private func saveSessionData() {
        userProfile.totalSessions += 1
        userProfile.totalTimeSpent += currentSession.sessionDuration
        
        if userProfile.totalSessions > 0 {
            userProfile.averageSessionDuration = userProfile.totalTimeSpent / Double(userProfile.totalSessions)
        }
        
        analyticsStorage.saveUserProfile(userProfile)
        analyticsStorage.saveEngagementMetrics(engagementMetrics)
    }
    
    private func loadUserProfile() {
        userProfile = analyticsStorage.loadUserProfile()
    }
    
    private func loadEngagementMetrics() {
        engagementMetrics = analyticsStorage.loadEngagementMetrics()
    }
}

// MARK: - User Session
struct UserSession: Codable {
    var sessionId = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var sessionDuration: TimeInterval = 0
    
    var events: [UserEventData] = []
    var habitInteractions: [HabitInteraction] = []
    var screenViews: [ScreenView] = []
    var engagementEvents: [EngagementEvent] = []
}

// MARK: - User Profile
struct UserProfile: Codable {
    var userId = UUID()
    var totalSessions: Int = 0
    var totalTimeSpent: TimeInterval = 0
    var averageSessionDuration: TimeInterval = 0
    
    var habitsCreated: Int = 0
    var habitsCompleted: Int = 0
    
    var habitMetrics: [UUID: HabitMetrics] = [:]
    var screenMetrics: [ScreenName: ScreenMetrics] = [:]
    var lastUpdated: Date = Date()
}

// MARK: - Engagement Metrics
struct EngagementMetrics: Codable {
    var habitsCreated: Int = 0
    var habitsCompleted: Int = 0
    var habitsSkipped: Int = 0
    var streaksAchieved: Int = 0
    var goalsReached: Int = 0
    var featuresUsed: Int = 0
    var overallScore: Double = 0.0
}

// MARK: - User Event
enum UserEvent: String, Codable, CaseIterable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case sessionPause = "session_pause"
    case userActive = "user_active"
    case habitCreated = "habit_created"
    case habitCompleted = "habit_completed"
    case habitSkipped = "habit_skipped"
    case streakAchieved = "streak_achieved"
    case goalReached = "goal_reached"
    case featureUsed = "feature_used"
    case settingsChanged = "settings_changed"
    case dataExported = "data_exported"
    case dataImported = "data_imported"
}

// MARK: - User Event Data
struct UserEventData: Codable, Identifiable {
    let id: UUID
    let type: UserEvent
    let timestamp: Date
    let metadata: [String: String]
    
    init(type: UserEvent, timestamp: Date, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Habit Action
enum HabitAction: String, Codable, CaseIterable {
    case created = "created"
    case completed = "completed"
    case skipped = "skipped"
    case edited = "edited"
    case deleted = "deleted"
}

// MARK: - Habit Interaction
struct HabitInteraction: Codable, Identifiable {
    let id: UUID
    let habitId: UUID
    let action: HabitAction
    let timestamp: Date
    let metadata: [String: String]
    
    init(habitId: UUID, action: HabitAction, timestamp: Date, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.habitId = habitId
        self.action = action
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Screen Name
enum ScreenName: String, Codable, CaseIterable {
    case home = "home"
    case habits = "habits"
    case progress = "progress"
    case settings = "settings"
    case profile = "profile"
    case createHabit = "create_habit"
    case editHabit = "edit_habit"
    case habitDetail = "habit_detail"
    case overviewView = "overview_view"
    case vacationMode = "vacation_mode"
    case notifications = "notifications"
    case dataPrivacy = "data_privacy"
    case aboutUs = "about_us"
}

// MARK: - Screen View
struct ScreenView: Codable, Identifiable {
    let id: UUID
    let screen: ScreenName
    let timestamp: Date
    let metadata: [String: String]
    
    init(screen: ScreenName, timestamp: Date, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.screen = screen
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Engagement Type
enum EngagementType: String, Codable, CaseIterable {
    case timeSpent = "time_spent"
    case interactions = "interactions"
    case completions = "completions"
    case streaks = "streaks"
    case goals = "goals"
}

// MARK: - Engagement Event
struct EngagementEvent: Codable, Identifiable {
    let id: UUID
    let type: EngagementType
    let value: Double
    let timestamp: Date
    let metadata: [String: String]
    
    init(type: EngagementType, value: Double, timestamp: Date, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Habit Metrics
struct HabitMetrics: Codable {
    var interactionCount: Int = 0
    var completionCount: Int = 0
    var skipCount: Int = 0
    var editCount: Int = 0
    var deleteCount: Int = 0
    var lastInteracted: Date = Date()
}

// MARK: - Screen Metrics
struct ScreenMetrics: Codable {
    var viewCount: Int = 0
    var lastViewed: Date = Date()
    var averageTimeSpent: TimeInterval = 0
}

// MARK: - User Insights
struct UserInsights {
    let mostActiveTime: String
    let favoriteHabits: [UUID]
    let completionRate: Double
    let streakPerformance: Double
    let engagementScore: Double
    let usagePatterns: [String: Any]
}

// MARK: - Analytics Summary
struct AnalyticsSummary {
    let totalSessions: Int
    let totalTimeSpent: TimeInterval
    let averageSessionDuration: TimeInterval
    let habitsCreated: Int
    let habitsCompleted: Int
    let engagementScore: Double
    let mostUsedFeature: String
    let improvementAreas: [String]
}

// MARK: - Analytics Storage
class AnalyticsStorage {
    private let userDefaults = UserDefaults.standard
    private let userProfileKey = "UserProfile"
    private let engagementMetricsKey = "EngagementMetrics"
    
    func saveUserProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: userProfileKey)
        } catch {
            print("❌ AnalyticsStorage: Failed to save user profile - \(error.localizedDescription)")
        }
    }
    
    func loadUserProfile() -> UserProfile {
        guard let data = userDefaults.data(forKey: userProfileKey) else { return UserProfile() }
        
        do {
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("❌ AnalyticsStorage: Failed to load user profile - \(error.localizedDescription)")
            return UserProfile()
        }
    }
    
    func saveEngagementMetrics(_ metrics: EngagementMetrics) {
        do {
            let data = try JSONEncoder().encode(metrics)
            userDefaults.set(data, forKey: engagementMetricsKey)
        } catch {
            print("❌ AnalyticsStorage: Failed to save engagement metrics - \(error.localizedDescription)")
        }
    }
    
    func loadEngagementMetrics() -> EngagementMetrics {
        guard let data = userDefaults.data(forKey: engagementMetricsKey) else { return EngagementMetrics() }
        
        do {
            return try JSONDecoder().decode(EngagementMetrics.self, from: data)
        } catch {
            print("❌ AnalyticsStorage: Failed to load engagement metrics - \(error.localizedDescription)")
            return EngagementMetrics()
        }
    }
    
    func clearAnalytics() {
        userDefaults.removeObject(forKey: userProfileKey)
        userDefaults.removeObject(forKey: engagementMetricsKey)
    }
}
