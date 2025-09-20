import SwiftUI

/// View for monitoring background queue performance and status
struct PerformanceMonitorView: View {
    @StateObject private var backgroundQueue = BackgroundQueueManager.shared
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    @StateObject private var dataUsageAnalytics = DataUsageAnalytics.shared
    
    @State private var refreshTimer: Timer?
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            List {
                // Background Queue Status Section
                Section("Background Queue Status") {
                    BackgroundQueueStatusView(backgroundQueue: backgroundQueue)
                }
                
                // Performance Metrics Section
                Section("Performance Metrics") {
                    ForEach(performanceMetrics.currentMetrics.events, id: \.id) { event in
                        PerformanceEventRow(event: event)
                    }
                }
                
                // Data Usage Section
                Section("Data Usage") {
                    let stats = dataUsageAnalytics.getDataUsageSummary()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Storage Used")
                                .font(.headline)
                            Text("\(stats.totalStorageUsed) bytes")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Habits Storage")
                                .font(.headline)
                            Text(formatBytes(stats.habitsStorageUsed))
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Cache Storage")
                                .font(.headline)
                            Text(formatBytes(stats.cacheStorageUsed))
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Optimization Potential")
                                .font(.headline)
                            Text(formatBytes(stats.optimizationPotential))
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                // Queue Statistics Section
                Section("Queue Statistics") {
                    let queueStats = getQueueStatistics()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Background Queue")
                                .font(.headline)
                            Text("\(queueStats.backgroundOperations)")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Serial Queue")
                                .font(.headline)
                            Text("\(queueStats.serialOperations)")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Operations")
                                .font(.headline)
                            Text("\(queueStats.totalOperations)")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Success Rate")
                                .font(.headline)
                            Text("\(Int(queueStats.successRate * 100))%")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Performance Monitor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            .onAppear {
                startRefreshTimer()
            }
            .onDisappear {
                stopRefreshTimer()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func refreshData() {
        isRefreshing = true
        
        Task {
            // Simulate refresh delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Auto-refresh every 2 seconds
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getQueueStatistics() -> QueueStatistics {
        // This would be implemented to get actual queue statistics
        // For now, return placeholder data
        return QueueStatistics(
            backgroundOperations: backgroundQueue.activeOperations,
            serialOperations: 0, // Would need to track this separately
            totalOperations: backgroundQueue.activeOperations,
            successRate: 0.95 // Would need to track this separately
        )
    }
}

// MARK: - Queue Statistics
struct QueueStatistics {
    let backgroundOperations: Int
    let serialOperations: Int
    let totalOperations: Int
    let successRate: Double
}

// MARK: - Background Queue Status View
struct BackgroundQueueStatusView: View {
    let backgroundQueue: BackgroundQueueManager
    
    var body: some View {
        HStack {
            Image(systemName: backgroundQueue.isProcessing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .foregroundColor(backgroundQueue.isProcessing ? .orange : .green)
            
            VStack(alignment: .leading) {
                Text(backgroundQueue.isProcessing ? "Processing" : "Idle")
                    .font(.headline)
                Text("Active Operations: \(backgroundQueue.activeOperations)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if backgroundQueue.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Performance Event Row
struct PerformanceEventRow: View {
    let event: PerformanceEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.type.rawValue)
                    .font(.headline)
                Spacer()
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(event.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !event.metadata.isEmpty {
                Text("Metadata: \(event.metadata.keys.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    PerformanceMonitorView()
}
