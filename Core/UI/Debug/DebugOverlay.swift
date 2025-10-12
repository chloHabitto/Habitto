import SwiftUI

/// Debug overlay showing telemetry counters and operational metrics
///
/// Activated by triple-tapping anywhere in the app.
/// Shows real-time counters for:
/// - Firestore writes (ok/failed)
/// - Security rules denials
/// - Transaction retries
/// - XP awards
/// - Streak updates
/// - Completions
///
/// Usage:
/// ```swift
/// @State private var showDebugOverlay = false
///
/// var body: some View {
///     ContentView()
///         .debugOverlay(isPresented: $showDebugOverlay)
///         .onTapGesture(count: 3) {
///             showDebugOverlay.toggle()
///         }
/// }
/// ```
struct DebugOverlay: View {
    @StateObject private var telemetry = TelemetryService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    summaryCard
                    
                    // Firestore Writes
                    metricCard(
                        title: "Firestore Writes",
                        metric: telemetry.getSummary().firestoreWrites,
                        icon: "externaldrive.fill",
                        color: .blue
                    )
                    
                    // XP Awards
                    metricCard(
                        title: "XP Awards",
                        metric: telemetry.getSummary().xpAwards,
                        icon: "star.fill",
                        color: .yellow
                    )
                    
                    // Streak Updates
                    metricCard(
                        title: "Streak Updates",
                        metric: telemetry.getSummary().streakUpdates,
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    // Completions
                    metricCard(
                        title: "Completions",
                        metric: telemetry.getSummary().completions,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    // Other Metrics
                    otherMetricsCard
                }
                .padding()
            }
            .navigationTitle("Debug Telemetry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        telemetry.resetCounters()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overview", systemImage: "chart.bar.fill")
                .font(.headline)
            
            let summary = telemetry.getSummary()
            
            if summary.hasIssues {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Issues Detected")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All Systems Operational")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Quick Stats
            HStack(spacing: 20) {
                quickStat(
                    title: "Writes",
                    value: "\(telemetry.totalFirestoreWrites)",
                    color: .blue
                )
                
                quickStat(
                    title: "Denials",
                    value: "\(telemetry.rulesDenials)",
                    color: telemetry.rulesDenials > 0 ? .red : .green
                )
                
                quickStat(
                    title: "Retries",
                    value: "\(telemetry.transactionRetries)",
                    color: telemetry.transactionRetries > 5 ? .orange : .green
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func quickStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Metric Card
    
    private func metricCard(
        title: String,
        metric: OperationMetric,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                // Success Rate Badge
                Text(metric.successPercentage)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        metric.successRate >= 0.95 ? Color.green :
                        metric.successRate >= 0.8 ? Color.orange : Color.red
                    )
                    .cornerRadius(4)
            }
            
            // Metrics
            HStack(spacing: 16) {
                metricValue(
                    label: "Success",
                    value: "\(metric.success)",
                    color: .green
                )
                
                metricValue(
                    label: "Failed",
                    value: "\(metric.failed)",
                    color: .red
                )
                
                metricValue(
                    label: "Total",
                    value: "\(metric.total)",
                    color: .secondary
                )
            }
            
            // Progress Bar
            if metric.total > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(height: 8)
                        
                        // Success
                        Rectangle()
                            .fill(Color.green)
                            .frame(
                                width: geometry.size.width * metric.successRate,
                                height: 8
                            )
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func metricValue(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Other Metrics Card
    
    private var otherMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Other Metrics", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            
            Divider()
            
            // Rules Denials
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.red)
                Text("Rules Denials")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(telemetry.rulesDenials)")
                    .font(.title3.bold())
                    .foregroundColor(telemetry.rulesDenials > 0 ? .red : .green)
            }
            
            Divider()
            
            // Transaction Retries
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.orange)
                Text("Transaction Retries")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(telemetry.transactionRetries)")
                    .font(.title3.bold())
                    .foregroundColor(telemetry.transactionRetries > 5 ? .orange : .green)
            }
            
            if telemetry.transactionRetries > 5 {
                Text("⚠️ High retry count may indicate contention or network issues")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - View Extension

extension View {
    /// Add debug overlay with three-tap gesture to activate
    func debugOverlay(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            DebugOverlay()
        }
    }
    
    /// Add three-tap gesture to toggle debug overlay
    func withDebugGesture(showDebugOverlay: Binding<Bool>) -> some View {
        self.onTapGesture(count: 3) {
            showDebugOverlay.wrappedValue.toggle()
            HabittoLogger.debug.info("Debug overlay toggled: \(showDebugOverlay.wrappedValue)")
        }
    }
}

// MARK: - Preview

#Preview {
    DebugOverlay()
}

