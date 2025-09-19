import SwiftUI

// MARK: - Analytics Dashboard
/// Displays performance metrics, user analytics, and data usage insights
@MainActor
struct AnalyticsDashboard: View {
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    @StateObject private var userAnalytics = UserAnalytics.shared
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    @State private var selectedTab: AnalyticsTab = .performance
    @State private var showingOptimizationSheet = false
    @State private var showingInsightsSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Analytics Tab", selection: $selectedTab) {
                    ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    PerformanceView()
                        .tag(AnalyticsTab.performance)
                    
                    UserAnalyticsView()
                        .tag(AnalyticsTab.user)
                    
                    DataUsageView()
                        .tag(AnalyticsTab.dataUsage)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Optimization Recommendations") {
                            showingOptimizationSheet = true
                        }
                        
                        Button("User Insights") {
                            showingInsightsSheet = true
                        }
                        
                        Button("Export Data") {
                            exportAnalyticsData()
                        }
                        
                        Button("Clear Data", role: .destructive) {
                            clearAnalyticsData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingOptimizationSheet) {
            OptimizationRecommendationsView()
        }
        .sheet(isPresented: $showingInsightsSheet) {
            UserInsightsView()
        }
        .onAppear {
            startAnalyticsTracking()
        }
        .onDisappear {
            stopAnalyticsTracking()
        }
    }
    
    private func startAnalyticsTracking() {
        performanceMetrics.startMonitoring()
        userAnalytics.startTracking()
        dataUsageAnalytics.startTracking()
    }
    
    private func stopAnalyticsTracking() {
        performanceMetrics.stopMonitoring()
        userAnalytics.stopTracking()
        dataUsageAnalytics.stopTracking()
    }
    
    private func exportAnalyticsData() {
        // Implementation would export analytics data
        print("📊 AnalyticsDashboard: Exporting analytics data")
    }
    
    private func clearAnalyticsData() {
        // Implementation would clear analytics data
        print("📊 AnalyticsDashboard: Clearing analytics data")
    }
}

// MARK: - Analytics Tab
enum AnalyticsTab: CaseIterable {
    case performance
    case user
    case dataUsage
    
    var title: String {
        switch self {
        case .performance: return "Performance"
        case .user: return "User"
        case .dataUsage: return "Data Usage"
        }
    }
}

// MARK: - Performance View
struct PerformanceView: View {
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Performance Summary Card
                PerformanceSummaryCard()
                
                // Memory Usage Card
                MemoryUsageCard()
                
                // Operation Timings Card
                OperationTimingsCard()
                
                // Events Card
                EventsCard()
            }
            .padding()
        }
    }
}

// MARK: - Performance Summary Card
struct PerformanceSummaryCard: View {
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Performance Summary")
                    .font(.headline)
                Spacer()
                Text("Score: \(Int(performanceMetrics.getPerformanceSummary().overallScore * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            let summary = performanceMetrics.getPerformanceSummary()
            
            VStack(alignment: .leading, spacing: 8) {
                PerformanceMetricRow(
                    title: "Data Load Time",
                    value: String(format: "%.3fs", summary.averageDataLoadTime),
                    color: summary.averageDataLoadTime < 0.1 ? .green : .orange
                )
                
                PerformanceMetricRow(
                    title: "Data Save Time",
                    value: String(format: "%.3fs", summary.averageDataSaveTime),
                    color: summary.averageDataSaveTime < 0.1 ? .green : .orange
                )
                
                PerformanceMetricRow(
                    title: "UI Render Time",
                    value: String(format: "%.3fs", summary.averageUIRenderTime),
                    color: summary.averageUIRenderTime < 0.016 ? .green : .orange
                )
                
                PerformanceMetricRow(
                    title: "Error Rate",
                    value: String(format: "%.1f%%", summary.errorRate * 100),
                    color: summary.errorRate < 0.01 ? .green : .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Performance Metric Row
struct PerformanceMetricRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Memory Usage Card
struct MemoryUsageCard: View {
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.purple)
                Text("Memory Usage")
                    .font(.headline)
                Spacer()
                Text("\(Int(performanceMetrics.currentMetrics.memoryUsage))MB")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Usage")
                    Spacer()
                    Text("\(Int(performanceMetrics.currentMetrics.memoryUsage))MB")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Peak Usage")
                    Spacer()
                    Text("\(Int(performanceMetrics.currentMetrics.peakMemoryUsage))MB")
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("Efficiency")
                    Spacer()
                    let efficiency = performanceMetrics.getPerformanceSummary().memoryEfficiency
                    Text("\(Int(efficiency * 100))%")
                        .fontWeight(.medium)
                        .foregroundColor(efficiency > 0.7 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Operation Timings Card
struct OperationTimingsCard: View {
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.green)
                Text("Operation Timings")
                    .font(.headline)
                Spacer()
            }
            
            let metrics = performanceMetrics.currentMetrics
            
            VStack(alignment: .leading, spacing: 8) {
                OperationTimingRow(
                    operation: "Data Loads",
                    count: metrics.dataLoadCount,
                    averageTime: metrics.averageTimings["dataLoad"] ?? 0
                )
                
                OperationTimingRow(
                    operation: "Data Saves",
                    count: metrics.dataSaveCount,
                    averageTime: metrics.averageTimings["dataSave"] ?? 0
                )
                
                OperationTimingRow(
                    operation: "UI Renders",
                    count: metrics.uiRenderCount,
                    averageTime: metrics.averageTimings["uiRender"] ?? 0
                )
                
                OperationTimingRow(
                    operation: "User Actions",
                    count: metrics.userActionCount,
                    averageTime: 0
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Operation Timing Row
struct OperationTimingRow: View {
    let operation: String
    let count: Int
    let averageTime: TimeInterval
    
    var body: some View {
        HStack {
            Text(operation)
                .font(.subheadline)
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if averageTime > 0 {
                Text("(\(String(format: "%.3fs", averageTime)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Events Card
struct EventsCard: View {
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.orange)
                Text("Recent Events")
                    .font(.headline)
                Spacer()
            }
            
            let recentEvents = performanceMetrics.currentMetrics.events.suffix(5)
            
            if recentEvents.isEmpty {
                Text("No events recorded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(recentEvents), id: \.id) { event in
                    HStack {
                        Circle()
                            .fill(event.type.color)
                            .frame(width: 8, height: 8)
                        Text(event.description)
                            .font(.subheadline)
                        Spacer()
                        Text(event.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - User Analytics View
struct UserAnalyticsView: View {
    @StateObject private var userAnalytics = UserAnalytics.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // User Summary Card
                UserSummaryCard()
                
                // Engagement Card
                EngagementCard()
                
                // Session Card
                SessionCard()
                
                // Habits Card
                HabitsCard()
            }
            .padding()
        }
    }
}

// MARK: - User Summary Card
struct UserSummaryCard: View {
    @StateObject private var userAnalytics = UserAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                Text("User Summary")
                    .font(.headline)
                Spacer()
            }
            
            let summary = userAnalytics.getAnalyticsSummary()
            
            VStack(alignment: .leading, spacing: 8) {
                UserMetricRow(
                    title: "Total Sessions",
                    value: "\(summary.totalSessions)"
                )
                
                UserMetricRow(
                    title: "Total Time Spent",
                    value: formatDuration(summary.totalTimeSpent)
                )
                
                UserMetricRow(
                    title: "Average Session",
                    value: formatDuration(summary.averageSessionDuration)
                )
                
                UserMetricRow(
                    title: "Habits Created",
                    value: "\(summary.habitsCreated)"
                )
                
                UserMetricRow(
                    title: "Habits Completed",
                    value: "\(summary.habitsCompleted)"
                )
                
                UserMetricRow(
                    title: "Engagement Score",
                    value: "\(Int(summary.engagementScore * 100))%",
                    color: summary.engagementScore > 0.7 ? .green : .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - User Metric Row
struct UserMetricRow: View {
    let title: String
    let value: String
    let color: Color?
    
    init(title: String, value: String, color: Color? = nil) {
        self.title = title
        self.value = value
        self.color = color
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Engagement Card
struct EngagementCard: View {
    @StateObject private var userAnalytics = UserAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Engagement")
                    .font(.headline)
                Spacer()
                Text("\(Int(userAnalytics.engagementMetrics.overallScore * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            let metrics = userAnalytics.engagementMetrics
            
            VStack(alignment: .leading, spacing: 8) {
                EngagementMetricRow(
                    title: "Habits Created",
                    value: "\(metrics.habitsCreated)"
                )
                
                EngagementMetricRow(
                    title: "Habits Completed",
                    value: "\(metrics.habitsCompleted)"
                )
                
                EngagementMetricRow(
                    title: "Streaks Achieved",
                    value: "\(metrics.streaksAchieved)"
                )
                
                EngagementMetricRow(
                    title: "Goals Reached",
                    value: "\(metrics.goalsReached)"
                )
                
                EngagementMetricRow(
                    title: "Features Used",
                    value: "\(metrics.featuresUsed)"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Engagement Metric Row
struct EngagementMetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Session Card
struct SessionCard: View {
    @StateObject private var userAnalytics = UserAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.green)
                Text("Current Session")
                    .font(.headline)
                Spacer()
            }
            
            let session = userAnalytics.currentSession
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.subheadline)
                    Spacer()
                    Text(formatDuration(session.sessionDuration))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Events")
                        .font(.subheadline)
                    Spacer()
                    Text("\(session.events.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Habit Interactions")
                        .font(.subheadline)
                    Spacer()
                    Text("\(session.habitInteractions.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Screen Views")
                        .font(.subheadline)
                    Spacer()
                    Text("\(session.screenViews.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Habits Card
struct HabitsCard: View {
    @StateObject private var userAnalytics = UserAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Habits")
                    .font(.headline)
                Spacer()
            }
            
            let profile = userAnalytics.userProfile
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Created")
                        .font(.subheadline)
                    Spacer()
                    Text("\(profile.habitsCreated)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Total Completed")
                        .font(.subheadline)
                    Spacer()
                    Text("\(profile.habitsCompleted)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Completion Rate")
                        .font(.subheadline)
                    Spacer()
                    let rate = profile.habitsCreated > 0 ? Double(profile.habitsCompleted) / Double(profile.habitsCreated) : 0
                    Text("\(Int(rate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(rate > 0.7 ? .green : .orange)
                }
                
                HStack {
                    Text("Active Habits")
                        .font(.subheadline)
                    Spacer()
                    Text("\(profile.habitMetrics.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Data Usage View
struct DataUsageView: View {
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Storage Usage Card
                StorageUsageCard()
                
                // Operations Card
                OperationsCard()
                
                // Optimization Card
                OptimizationCard()
            }
            .padding()
        }
    }
}

// MARK: - Storage Usage Card
struct StorageUsageCard: View {
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.blue)
                Text("Storage Usage")
                    .font(.headline)
                Spacer()
                Text(formatBytes(dataUsageAnalytics.currentUsage.totalStorageUsed))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            let usage = dataUsageAnalytics.currentUsage
            
            VStack(alignment: .leading, spacing: 8) {
                StorageUsageRow(
                    title: "Habits Data",
                    usage: usage.habitsStorageUsed,
                    total: usage.totalStorageUsed
                )
                
                StorageUsageRow(
                    title: "Cache Data",
                    usage: usage.cacheStorageUsed,
                    total: usage.totalStorageUsed
                )
                
                StorageUsageRow(
                    title: "Metadata",
                    usage: usage.metadataStorageUsed,
                    total: usage.totalStorageUsed
                )
                
                StorageUsageRow(
                    title: "Unused Data",
                    usage: usage.unusedDataSize,
                    total: usage.totalStorageUsed,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Storage Usage Row
struct StorageUsageRow: View {
    let title: String
    let usage: Int64
    let total: Int64
    let color: Color?
    
    init(title: String, usage: Int64, total: Int64, color: Color? = nil) {
        self.title = title
        self.usage = usage
        self.total = total
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(formatBytes(usage))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            if total > 0 {
                ProgressView(value: Double(usage), total: Double(total))
                    .progressViewStyle(LinearProgressViewStyle(tint: color ?? .blue))
            }
        }
    }
}

// MARK: - Operations Card
struct OperationsCard: View {
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.green)
                Text("Operations")
                    .font(.headline)
                Spacer()
            }
            
            let usage = dataUsageAnalytics.currentUsage
            
            VStack(alignment: .leading, spacing: 8) {
                OperationRow(
                    title: "Data Loads",
                    count: usage.habitLoadCount,
                    size: usage.habitLoadSize
                )
                
                OperationRow(
                    title: "Data Saves",
                    count: usage.habitSaveCount,
                    size: usage.habitSaveSize
                )
                
                OperationRow(
                    title: "Cache Reads",
                    count: usage.cacheReadCount,
                    size: 0
                )
                
                OperationRow(
                    title: "Cache Writes",
                    count: usage.cacheWriteCount,
                    size: 0
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Operation Row
struct OperationRow: View {
    let title: String
    let count: Int
    let size: Int64
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if size > 0 {
                Text("(\(formatBytes(size)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Optimization Card
struct OptimizationCard: View {
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.orange)
                Text("Optimization")
                    .font(.headline)
                Spacer()
            }
            
            let recommendations = dataUsageAnalytics.getOptimizationRecommendations()
            
            if recommendations.isEmpty {
                Text("No optimization recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(recommendations.prefix(3)), id: \.type) { recommendation in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(recommendation.description)
                                .font(.subheadline)
                            Spacer()
                            Text(formatBytes(recommendation.potentialSavings))
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text(String(recommendation.priority.rawValue).capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(recommendation.priority.color)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Optimization Recommendations View
struct OptimizationRecommendationsView: View {
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataUsageAnalytics.getOptimizationRecommendations(), id: \.type) { recommendation in
                    OptimizationRecommendationRow(recommendation: recommendation)
                }
            }
            .navigationTitle("Optimization Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Optimization Recommendation Row
struct OptimizationRecommendationRow: View {
    let recommendation: OptimizationRecommendation
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.description)
                    .font(.subheadline)
                Spacer()
                Text(formatBytes(recommendation.potentialSavings))
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            HStack {
                Text(String(recommendation.priority.rawValue).capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(recommendation.priority.color)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Apply") {
                    Task {
                        await dataUsageAnalytics.applyOptimization(recommendation)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User Insights View
struct UserInsightsView: View {
    @StateObject private var userAnalytics = UserAnalytics.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    let insights = userAnalytics.getUserInsights()
                    
                    // Most Active Time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Most Active Time")
                            .font(.headline)
                        Text("\(insights.mostActiveTime)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Completion Rate
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completion Rate")
                            .font(.headline)
                        Text("\(Int(insights.completionRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(insights.completionRate > 0.7 ? .green : .orange)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Engagement Score
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Engagement Score")
                            .font(.headline)
                        Text("\(Int(insights.engagementScore * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(insights.engagementScore > 0.7 ? .green : .orange)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("User Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension EventType {
    var color: Color {
        switch self {
        case .dataLoad, .dataSave:
            return .blue
        case .uiRender:
            return .green
        case .networkRequest:
            return .purple
        case .error:
            return .red
        case .userAction:
            return .orange
        }
    }
}

extension OptimizationPriority {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

// MARK: - Helper Functions

private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    let seconds = Int(duration) % 60
    
    if hours > 0 {
        return String(format: "%dh %dm", hours, minutes)
    } else if minutes > 0 {
        return String(format: "%dm %ds", minutes, seconds)
    } else {
        return String(format: "%ds", seconds)
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useKB, .useBytes]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

#Preview {
    AnalyticsDashboard()
}
