import SwiftUI

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Achievement Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(achievement.isUnlocked ? .yellow : .gray)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)
            }
            
            // Achievement Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(achievement.isUnlocked ? .text01 : .text02)
                    
                    Spacer()
                    
                    if achievement.isUnlocked {
                        Text("+\(achievement.xpReward) XP")
                            .font(.appLabelSmall)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                    }
                }
                
                Text(achievement.description)
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                    .lineLimit(2)
                
                // Progress Bar (for locked achievements)
                if !achievement.isUnlocked && achievement.progress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(achievement.progress)/\(achievement.requirement.target)")
                                .font(.appLabelSmall)
                                .foregroundColor(.text02)
                            
                            Spacer()
                            
                            Text("\(Int(achievement.progressPercentage * 100))%")
                                .font(.appLabelSmall)
                                .foregroundColor(.text02)
                        }
                        
                        ProgressView(value: achievement.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(achievement.isUnlocked ? Color.yellow.opacity(0.05) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(achievement.isUnlocked ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isAnimating)
        .onAppear {
            if achievement.isUnlocked {
                withAnimation(.easeInOut(duration: 0.6).delay(0.1)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Achievement Grid
struct AchievementGrid: View {
    let achievements: [Achievement]
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(achievements) { achievement in
                AchievementCard(achievement: achievement)
            }
        }
    }
}

// MARK: - Achievement Category Header
struct AchievementCategoryHeader: View {
    let category: Achievement.AchievementCategory
    let count: Int
    let unlockedCount: Int
    
    var categoryTitle: String {
        switch category {
        case .daily: return "Daily"
        case .streak: return "Streak"
        case .milestone: return "Milestone"
        case .habit: return "Habit"
        case .general: return "General"
        case .social: return "Social"
        case .special: return "Special"
        }
    }
    
    var categoryIcon: String {
        switch category {
        case .daily: return "sun.max.fill"
        case .streak: return "flame.fill"
        case .milestone: return "star.circle.fill"
        case .habit: return "plus.circle.fill"
        case .general: return "gear.circle.fill"
        case .social: return "person.2.fill"
        case .special: return "sparkles"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: categoryIcon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(categoryTitle)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Text("\(unlockedCount) of \(count) unlocked")
                    .font(.appLabelSmall)
                    .foregroundColor(.text02)
            }
            
            Spacer()
            
            // Progress indicator
            if count > 0 {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("\(Int(Double(unlockedCount) / Double(count) * 100))%")
                            .font(.appLabelSmallEmphasised)
                            .foregroundColor(.blue)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Recent Unlocks
struct RecentUnlocksView: View {
    let recentUnlocks: [Achievement]
    @State private var showAll = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Unlocks")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                if recentUnlocks.count > 3 {
                    Button(showAll ? "Show Less" : "Show All") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAll.toggle()
                        }
                    }
                    .font(.appLabelMedium)
                    .foregroundColor(.blue)
                }
            }
            
            if recentUnlocks.isEmpty {
                Text("Complete habits to unlock achievements!")
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(recentUnlocks.prefix(showAll ? recentUnlocks.count : 3))) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Achievement Card Preview
#Preview {
    VStack(spacing: 20) {
        // Unlocked achievement
        AchievementCard(achievement: Achievement(
            title: "First Steps",
            description: "Complete your first habit",
            xpReward: 25,
            isUnlocked: true,
            unlockedDate: Date(),
            iconName: "star.fill",
            category: .daily,
            requirement: .completeHabits(count: 1)
        ))
        
        // Locked achievement with progress
        AchievementCard(achievement: Achievement(
            title: "Daily Warrior",
            description: "Complete all habits for 7 days straight",
            xpReward: 100,
            isUnlocked: false,
            iconName: "flame.fill",
            category: .daily,
            requirement: .completeDailyHabits(days: 7)
        ))
    }
    .padding()
    .background(Color.primary)
}
