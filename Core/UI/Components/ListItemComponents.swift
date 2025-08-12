import SwiftUI

// MARK: - List Item Components
struct ListItemComponents {
    
    // MARK: - Habit List Item
    struct HabitListItem: View {
        let habit: Habit
        let showProgress: Bool
        let showStreak: Bool
        let onTap: () -> Void
        let onMoreTap: (() -> Void)?
        
        init(
            habit: Habit,
            showProgress: Bool = true,
            showStreak: Bool = true,
            onTap: @escaping () -> Void,
            onMoreTap: (() -> Void)? = nil
        ) {
            self.habit = habit
            self.showProgress = showProgress
            self.showStreak = showStreak
            self.onTap = onTap
            self.onMoreTap = onMoreTap
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Habit icon
                    HabitIconView(habit: habit)
                        .frame(width: 38, height: 54)
                    
                    // Habit details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .font(.appBodyLarge)
                            .foregroundColor(.text01)
                            .lineLimit(1)
                        
                        if !habit.description.isEmpty {
                            Text(habit.description)
                                .font(.appBodySmall)
                                .foregroundColor(.text02)
                                .lineLimit(2)
                        }
                        
                        if showStreak {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.appLabelSmall)
                                    .foregroundColor(.red500)
                                
                                Text("\(habit.streak) day streak")
                                    .font(.appLabelSmall)
                                    .foregroundColor(.text02)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Progress or more button
                    if showProgress {
                        VStack(alignment: .trailing, spacing: 4) {
                            if let goal = parseGoal(from: habit.goal) {
                                Text("\(goal.amount) \(goal.unit)")
                                    .font(.appLabelSmall)
                                    .foregroundColor(.text02)
                            }
                            
                            if let onMoreTap = onMoreTap {
                                Button(action: onMoreTap) {
                                    Image(systemName: "ellipsis")
                                        .font(.appLabelMedium)
                                        .foregroundColor(.text03)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private func parseGoal(from goalString: String) -> (amount: Int, unit: String)? {
            let components = goalString.components(separatedBy: " ")
            guard components.count >= 2,
                  let amount = Int(components[0]) else {
                return nil
            }
            
            let unit = components[1]
            return (amount: amount, unit: unit)
        }
    }
    
    // MARK: - Progress List Item
    struct ProgressListItem: View {
        let title: String
        let subtitle: String?
        let progress: Double
        let progressColor: Color
        let icon: String?
        let iconColor: Color
        let onTap: () -> Void
        
        init(
            title: String,
            subtitle: String? = nil,
            progress: Double,
            progressColor: Color = .primary,
            icon: String? = nil,
            iconColor: Color = .primary,
            onTap: @escaping () -> Void
        ) {
            self.title = title
            self.subtitle = subtitle
            self.progress = progress
            self.progressColor = progressColor
            self.icon = icon
            self.iconColor = iconColor
            self.onTap = onTap
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Icon (if provided)
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.appTitleMedium)
                            .foregroundColor(iconColor)
                            .frame(width: 24, height: 24)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.appBodyLarge)
                            .foregroundColor(.text01)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.appBodySmall)
                                .foregroundColor(.text02)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Progress indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.appLabelMedium)
                            .foregroundColor(.text01)
                        
                        ProgressChartComponents.ProgressBar(
                            progress: progress,
                            height: 4,
                            primaryColor: progressColor,
                            secondaryColor: .primaryContainer
                        )
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Metric List Item
    struct MetricListItem: View {
        let title: String
        let value: String
        let subtitle: String?
        let icon: String
        let iconColor: Color
        let backgroundColor: Color
        let onTap: (() -> Void)?
        
        init(
            title: String,
            value: String,
            subtitle: String? = nil,
            icon: String,
            iconColor: Color = .primary,
            backgroundColor: Color = .surfaceDim,
            onTap: (() -> Void)? = nil
        ) {
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.icon = icon
            self.iconColor = iconColor
            self.backgroundColor = backgroundColor
            self.onTap = onTap
        }
        
        var body: some View {
            Group {
                if let onTap = onTap {
                    Button(action: onTap) {
                        contentView
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    contentView
                }
            }
        }
        
        private var contentView: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.appTitleMedium)
                        .foregroundColor(iconColor)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.appTitleLargeEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(title)
                        .font(.appTitleSmall)
                        .foregroundColor(.text02)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.appBodySmall)
                            .foregroundColor(.text03)
                    }
                }
            }
            .padding(16)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Action List Item
    struct ActionListItem: View {
        let title: String
        let subtitle: String?
        let icon: String
        let iconColor: Color
        let backgroundColor: Color
        let onTap: () -> Void
        let showChevron: Bool
        
        init(
            title: String,
            subtitle: String? = nil,
            icon: String,
            iconColor: Color = .primary,
            backgroundColor: Color = .surface,
            onTap: @escaping () -> Void,
            showChevron: Bool = true
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.iconColor = iconColor
            self.backgroundColor = backgroundColor
            self.onTap = onTap
            self.showChevron = showChevron
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: icon)
                        .font(.appTitleMedium)
                        .foregroundColor(iconColor)
                        .frame(width: 24, height: 24)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.appBodyLarge)
                            .foregroundColor(.text01)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.appBodySmall)
                                .foregroundColor(.text02)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Chevron
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.appLabelSmall)
                            .foregroundColor(.text03)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Empty State Item
    struct EmptyStateItem: View {
        let title: String
        let subtitle: String
        let icon: String
        let iconColor: Color
        let actionTitle: String?
        let action: (() -> Void)?
        
        init(
            title: String,
            subtitle: String,
            icon: String,
            iconColor: Color = .text03,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.iconColor = iconColor
            self.actionTitle = actionTitle
            self.action = action
        }
        
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(iconColor)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                        .multilineTextAlignment(.center)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.appBodyMedium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }
}
