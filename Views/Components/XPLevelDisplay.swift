import SwiftUI

// MARK: - XP Level Display Component
struct XPLevelDisplay: View {
    @ObservedObject var xpService: XPService
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Level and XP Info
            HStack(spacing: 16) {
                // Level Badge
                VStack(spacing: 4) {
                    Text("Level")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.text04)
                    
                    Text("\(xpService.userProgress.currentLevel)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.text01)
                }
                .frame(width: 60)
                
                // XP Progress Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("XP Progress")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.text04)
                        
                        Spacer()
                        
                        Text("\(xpService.userProgress.xpForCurrentLevel)/\(xpService.userProgress.xpForNextLevel)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.text04)
                    }
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.surfaceDim)
                                .frame(height: 8)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressGradient)
                                .frame(width: progressWidth(for: geometry.size.width), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    // Total XP
                    Text("\(xpService.userProgress.totalXP) total XP")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.text04)
                }
            }
            
            // Recent XP Transactions (if any)
            if !xpService.recentTransactions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.text04)
                    
                    ForEach(Array(xpService.recentTransactions.prefix(3)), id: \.id) { transaction in
                        HStack(spacing: 8) {
                            // XP Icon
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow500)
                            
                            // Description
                            Text(transaction.description)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.text02)
                            
                            Spacer()
                            
                            // XP Amount
                            Text("+\(transaction.amount)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green500)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Computed Properties
    
    private var progressWidth: (CGFloat) -> CGFloat {
        return { totalWidth in
            let progress = xpService.userProgress.levelProgress
            return totalWidth * CGFloat(progress)
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue400, Color.blue500],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - XP Level Display Compact Version
struct XPLevelDisplayCompact: View {
    @ObservedObject var xpService: XPService
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Level Badge
            VStack(spacing: 2) {
                Text("Level")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.text04)
                
                Text("\(xpService.userProgress.currentLevel)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.text01)
            }
            .frame(width: 40)
            
            // XP Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(xpService.userProgress.totalXP) XP")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.text01)
                    
                    Spacer()
                    
                    Text("\(xpService.userProgress.xpForCurrentLevel)/\(xpService.userProgress.xpForNextLevel)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.text04)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.surfaceDim)
                            .frame(height: 4)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressGradient)
                            .frame(width: progressWidth(for: geometry.size.width), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Computed Properties
    
    private var progressWidth: (CGFloat) -> CGFloat {
        return { totalWidth in
            let progress = xpService.userProgress.levelProgress
            return totalWidth * CGFloat(progress)
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue400, Color.blue500],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - XP Transaction Row
struct XPTransactionRow: View {
    let transaction: XPTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on reason
            Image(systemName: iconForReason(transaction.reason))
                .font(.system(size: 14))
                .foregroundColor(colorForReason(transaction.reason))
                .frame(width: 20)
            
            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.text01)
                
                Text(formatTimestamp(transaction.timestamp))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.text04)
            }
            
            Spacer()
            
            // XP Amount
            Text("+\(transaction.amount)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func iconForReason(_ reason: XPRewardReason) -> String {
        switch reason {
        case .completeHabit:
            return "checkmark.circle.fill"
        case .completeAllHabits:
            return "star.fill"
        case .streakBonus:
            return "flame.fill"
        case .levelUp:
            return "arrow.up.circle.fill"
        case .achievement:
            return "trophy.fill"
        case .perfectWeek:
            return "calendar.badge.checkmark"
        case .firstHabit:
            return "star.circle.fill"
        case .comeback:
            return "arrow.clockwise.circle.fill"
        }
    }
    
    private func colorForReason(_ reason: XPRewardReason) -> Color {
        switch reason {
        case .completeHabit:
            return .blue500
        case .completeAllHabits:
            return .yellow500
        case .streakBonus:
            return .orange500
        case .levelUp:
            return .purple500
        case .achievement:
            return .green500
        case .perfectWeek:
            return .blue500
        case .firstHabit:
            return .yellow500
        case .comeback:
            return .green500
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 20) {
        XPLevelDisplay(xpService: XPService.shared)
        
        XPLevelDisplayCompact(xpService: XPService.shared)
        
        XPTransactionRow(transaction: XPTransaction(
            amount: 15,
            reason: .completeHabit,
            habitName: "Morning Exercise",
            description: "Completed Morning Exercise"
        ))
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
