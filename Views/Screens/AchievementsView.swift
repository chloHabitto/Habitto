import SwiftUI

// MARK: - Achievements View

struct AchievementsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Header Stats
          headerStats

          // Recent Unlocks
          if !achievementManager.recentUnlocks.isEmpty {
            RecentUnlocksView(recentUnlocks: achievementManager.recentUnlocks)
          }

          // Category Tabs
          categoryTabs

          // Achievements List
          achievementsList
        }
        .padding(.bottom, 20)
      }
      .navigationTitle("Achievements")
      .navigationBarTitleDisplayMode(.large)
      .background(Color.primary)
    }
  }

  // MARK: Private

  @StateObject private var achievementManager = AchievementManager()
  @State private var selectedCategory: Achievement.AchievementCategory? = nil
  @State private var showingRecentUnlocks = false

  private var overallProgress: Double {
    guard !achievementManager.achievements.isEmpty else { return 0 }
    let unlockedCount = achievementManager.unlockedAchievements.count
    return Double(unlockedCount) / Double(achievementManager.achievements.count)
  }

  // MARK: - Header Stats

  private var headerStats: some View {
    VStack(spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(achievementManager.unlockedAchievements.count)")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.text01)

          Text("Achievements Unlocked")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("\(achievementManager.achievements.count)")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.text01)

          Text("Total Available")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
        }
      }

      // Progress Bar
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Overall Progress")
            .font(.appLabelMedium)
            .foregroundColor(.text02)

          Spacer()

          Text("\(Int(overallProgress * 100))%")
            .font(.appLabelMediumEmphasised)
            .foregroundColor(.text01)
        }

        ProgressView(value: overallProgress)
          .progressViewStyle(LinearProgressViewStyle(tint: .blue))
          .scaleEffect(x: 1, y: 2, anchor: .center)
          .cornerRadius(4)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.surface)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2))
    .padding(.horizontal, 20)
  }

  // MARK: - Category Tabs

  private var categoryTabs: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        // All Categories
        categoryTab(
          title: "All",
          icon: "list.bullet",
          isSelected: selectedCategory == nil,
          count: achievementManager.achievements.count,
          unlockedCount: achievementManager.unlockedAchievements.count)
        {
          selectedCategory = nil
        }

        // Individual Categories
        ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
          let categoryAchievements = achievementManager.getAchievementsByCategory(category)
          let unlockedCount = categoryAchievements.filter { $0.isUnlocked }.count

          categoryTab(
            title: categoryTitle(category),
            icon: categoryIcon(category),
            isSelected: selectedCategory == category,
            count: categoryAchievements.count,
            unlockedCount: unlockedCount)
          {
            selectedCategory = category
          }
        }
      }
      .padding(.horizontal, 20)
    }
  }

  // MARK: - Achievements List

  private var achievementsList: some View {
    LazyVStack(spacing: 16) {
      if let selectedCategory {
        // Show achievements for selected category
        let categoryAchievements = achievementManager.getAchievementsByCategory(selectedCategory)

        if !categoryAchievements.isEmpty {
          AchievementCategoryHeader(
            category: selectedCategory,
            count: categoryAchievements.count,
            unlockedCount: categoryAchievements.filter { $0.isUnlocked }.count)

          LazyVStack(spacing: 12) {
            ForEach(categoryAchievements) { achievement in
              AchievementCard(achievement: achievement)
            }
          }
          .padding(.horizontal, 20)
        } else {
          emptyState
        }
      } else {
        // Show all achievements grouped by category
        ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
          let categoryAchievements = achievementManager.getAchievementsByCategory(category)
          let unlockedCount = categoryAchievements.filter { $0.isUnlocked }.count

          if !categoryAchievements.isEmpty {
            VStack(spacing: 12) {
              AchievementCategoryHeader(
                category: category,
                count: categoryAchievements.count,
                unlockedCount: unlockedCount)

              LazyVStack(spacing: 12) {
                ForEach(categoryAchievements) { achievement in
                  AchievementCard(achievement: achievement)
                }
              }
              .padding(.horizontal, 20)
            }
          }
        }
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "trophy")
        .font(.system(size: 48, weight: .light))
        .foregroundColor(.gray)

      Text("No Achievements Yet")
        .font(.appTitleMediumEmphasised)
        .foregroundColor(.text01)

      Text("Complete habits to start unlocking achievements!")
        .font(.appBodyMedium)
        .foregroundColor(.text02)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 40)
    .padding(.horizontal, 20)
  }

  private func categoryTab(
    title: String,
    icon: String,
    isSelected: Bool,
    count: Int,
    unlockedCount: Int,
    action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(isSelected ? .white : .blue)

        Text(title)
          .font(.appLabelMediumEmphasised)
          .foregroundColor(isSelected ? .white : .text01)

        Text("\(unlockedCount)/\(count)")
          .font(.appLabelSmall)
          .foregroundColor(isSelected ? .white.opacity(0.8) : .text02)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.blue : .surface)
          .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2))
    }
    .buttonStyle(PlainButtonStyle())
  }

  private func categoryTitle(_ category: Achievement.AchievementCategory) -> String {
    switch category {
    case .daily: "Daily"
    case .streak: "Streak"
    case .milestone: "Milestone"
    case .habit: "Habit"
    case .general: "General"
    case .social: "Social"
    case .special: "Special"
    }
  }

  private func categoryIcon(_ category: Achievement.AchievementCategory) -> String {
    switch category {
    case .daily: "sun.max.fill"
    case .streak: "flame.fill"
    case .milestone: "star.circle.fill"
    case .habit: "plus.circle.fill"
    case .general: "gear.circle.fill"
    case .social: "person.2.fill"
    case .special: "sparkles"
    }
  }
}

// MARK: - Achievements View Preview

#Preview {
  AchievementsView()
}
