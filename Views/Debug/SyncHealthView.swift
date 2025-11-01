import SwiftUI

#if DEBUG
/// Debug view to display sync health metrics
struct SyncHealthView: View {
    @State private var todayMetrics: SyncHealthSummary?
    @State private var weekMetrics: SyncHealthSummary?
    @State private var healthStatus: SyncHealthStatus = .healthy
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading metrics...")
                            .padding()
                    } else {
                        // Health Status Card
                        healthStatusCard
                        
                        // Today's Metrics
                        if let todayMetrics = todayMetrics {
                            metricsCard(title: "Today", metrics: todayMetrics)
                        }
                        
                        // Last 7 Days Metrics
                        if let weekMetrics = weekMetrics {
                            metricsCard(title: "Last 7 Days", metrics: weekMetrics)
                        }
                        
                        // Actions
                        actionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Sync Health Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by sheet
                    }
                }
            }
            .onAppear {
                loadMetrics()
            }
        }
    }
    
    private var healthStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall Health")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            
            Text(healthStatusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusBadge: some View {
        Text(healthStatusText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch healthStatus {
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .unhealthy:
            return .red
        }
    }
    
    private var healthStatusText: String {
        switch healthStatus {
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .unhealthy:
            return "Unhealthy"
        }
    }
    
    private var healthStatusDescription: String {
        switch healthStatus {
        case .healthy:
            return "Sync is operating normally with high success rate and low latency."
        case .degraded:
            return "Sync performance is below optimal. Check metrics for details."
        case .unhealthy:
            return "Sync is experiencing issues. Investigate failures and latency."
        }
    }
    
    private func metricsCard(title: String, metrics: SyncHealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            // Success Rate
            metricRow(
                label: "Success Rate",
                value: String(format: "%.1f%%", metrics.successRate * 100),
                color: metrics.successRate >= 0.99 ? .green : metrics.successRate >= 0.95 ? .orange : .red
            )
            
            // Total Syncs
            metricRow(
                label: "Total Syncs",
                value: "\(metrics.totalSyncs)",
                color: .primary
            )
            
            // Successful/Failed
            HStack(spacing: 20) {
                metricRow(
                    label: "Successful",
                    value: "\(metrics.successfulSyncs)",
                    color: .green
                )
                metricRow(
                    label: "Failed",
                    value: "\(metrics.failedSyncs)",
                    color: .red
                )
            }
            
            // Latency Percentiles
            VStack(alignment: .leading, spacing: 8) {
                Text("Latency Percentiles")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                metricRow(
                    label: "P50",
                    value: String(format: "%.2fs", metrics.p50Latency),
                    color: .primary
                )
                metricRow(
                    label: "P95",
                    value: String(format: "%.2fs", metrics.p95Latency),
                    color: metrics.p95Latency > 5.0 ? .orange : .primary
                )
                metricRow(
                    label: "P99",
                    value: String(format: "%.2fs", metrics.p99Latency),
                    color: metrics.p99Latency > 10.0 ? .red : .primary
                )
            }
            
            // Items Synced
            if metrics.totalItemsSynced > 0 {
                metricRow(
                    label: "Items Synced",
                    value: "\(metrics.totalItemsSynced)",
                    color: .primary
                )
            }
            
            // Conflicts Resolved
            if metrics.conflictsResolved > 0 {
                metricRow(
                    label: "Conflicts Resolved",
                    value: "\(metrics.conflictsResolved)",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func metricRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                loadMetrics()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Metrics")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: {
                Task { @MainActor in
                    if let userId = AuthenticationManager.shared.currentUser?.uid {
                        SyncHealthMonitor.shared.cleanupOldMetrics(userId: userId)
                        loadMetrics()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Cleanup Old Metrics (>30 days)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray4))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    private func loadMetrics() {
        isLoading = true
        
        Task { @MainActor in
            guard let userId = AuthenticationManager.shared.currentUser?.uid else {
                isLoading = false
                return
            }
            
            todayMetrics = SyncHealthMonitor.shared.getTodayMetrics(userId: userId)
            weekMetrics = SyncHealthMonitor.shared.getMetricsForLastDays(7, userId: userId)
            healthStatus = SyncHealthMonitor.shared.getHealthStatus(userId: userId)
            
            isLoading = false
        }
    }
}

#Preview {
    SyncHealthView()
}
#endif

