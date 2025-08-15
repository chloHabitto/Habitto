import SwiftUI

struct VacationSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vacationManager: VacationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Status Card
                    currentStatusCard
                    
                    // Statistics Cards
                    statisticsSection
                    
                    // History Section
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.surface2)
            .navigationTitle("Vacation Summary")
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
    
    // MARK: - Current Status Card
    private var currentStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image("Icon-Vacation")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.navy200)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(vacationManager.isActive ? "Currently on Vacation" : "Not on Vacation")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.text01)
                    
                    if vacationManager.isActive {
                        if let current = vacationManager.current {
                            Text("Started \(formatDate(current.start))")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.text04)
                        }
                    } else {
                        Text("All habits are active")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.text04)
                    }
                }
                
                Spacer()
                
                // Status Indicator
                Circle()
                    .fill(vacationManager.isActive ? Color.navy200 : Color.grey400)
                    .frame(width: 12, height: 12)
            }
            
            if vacationManager.isActive {
                Divider()
                
                HStack {
                    Text("Progress paused")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("Streaks frozen")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.text02)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Total Vacation Days
                statCard(
                    title: "Total Days",
                    value: "\(totalVacationDays)",
                    icon: "Icon-Calendar_Filled",
                    color: .navy200
                )
                
                // Current Streak
                statCard(
                    title: "Current Streak",
                    value: "\(currentStreak)",
                    icon: "Icon-Fire_Filled",
                    color: .warning
                )
                
                // Longest Vacation
                statCard(
                    title: "Longest Vacation",
                    value: "\(longestVacationDays) days",
                    icon: "Icon-Trophy_Filled",
                    color: .warning
                )
                
                // Average Vacation
                statCard(
                    title: "Average Length",
                    value: "\(averageVacationDays) days",
                    icon: "Icon-ChartBar_Filled",
                    color: .success
                )
            }
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Vacation History")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            if vacationManager.history.isEmpty {
                VStack(spacing: 12) {
                    Image("Icon-Calendar_Filled")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundColor(.grey400)
                    
                    Text("No vacation history yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text03)
                    
                    Text("Your vacation periods will appear here")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text04)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vacationManager.history.sorted(by: { $0.start > $1.start })) { period in
                        vacationHistoryRow(period)
                    }
                }
            }
        }
    }
    
    // MARK: - Vacation History Row
    private func vacationHistoryRow(_ period: VacationPeriod) -> some View {
        HStack(spacing: 16) {
            // Date Range
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(period.start))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                
                if let end = period.end {
                    Text("to \(formatDate(end))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text03)
                } else {
                    Text("Ongoing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.navy200)
                }
            }
            
            Spacer()
            
            // Duration
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(periodDuration(period)) days")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.text01)
                
                Text("Duration")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.text04)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
    }
    
    // MARK: - Stat Card
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.text01)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.text03)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var totalVacationDays: Int {
        let historyDays = vacationManager.history.reduce(0) { total, period in
            total + periodDuration(period)
        }
        let currentDays = vacationManager.current.map { periodDuration($0) } ?? 0
        return historyDays + currentDays
    }
    
    private var currentStreak: Int {
        // This would need to be implemented based on your streak logic
        // For now, returning a placeholder
        return 0
    }
    
    private var longestVacationDays: Int {
        vacationManager.history.map { periodDuration($0) }.max() ?? 0
    }
    
    private var averageVacationDays: Int {
        let periods = vacationManager.history
        guard !periods.isEmpty else { return 0 }
        
        let totalDays = periods.reduce(0) { total, period in
            total + periodDuration(period)
        }
        return totalDays / periods.count
    }
    
    private func periodDuration(_ period: VacationPeriod) -> Int {
        let endDate = period.end ?? Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: period.start, to: endDate)
        return max(1, components.day ?? 1) // Minimum 1 day
    }
}

#Preview {
    VacationSummaryView()
        .environmentObject(VacationManager.shared)
}
