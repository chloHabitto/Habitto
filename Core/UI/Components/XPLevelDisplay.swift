import SwiftUI

// MARK: - XPLevelDisplay

struct XPLevelDisplay: View {
  // MARK: Internal

  // ✅ FIX: Use @Environment to properly observe @Observable changes
  @Environment(XPManager.self) private var xpManager

  var body: some View {
    return VStack(spacing: 12) {
      // Level and XP Info
      HStack(spacing: 16) {
        // Level Badge
        VStack(spacing: 4) {
          Text("Level")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.text04)

          Text("\(xpManager.currentLevel)")  // ✅ Read from @Published property
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

            Text(
              "\(xpManager.userProgress.xpForCurrentLevel)/\(xpManager.userProgress.xpForNextLevel)")
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
                .frame(width: progressWidth(geometry.size.width), height: 8)
            }
          }
          .frame(height: 8)

          // Total XP
          Text("\(xpManager.totalXP) total XP")  // ✅ Read from @Published property
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(.text04)
        }
      }

      // Recent XP Transactions (if any)
      if !xpManager.recentTransactions.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Recent Activity")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.text04)

          ForEach(Array(xpManager.recentTransactions.prefix(3)), id: \.id) { transaction in
            HStack(spacing: 8) {
              // XP Icon
              Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.warning)

              // Description
              Text(transaction.description)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.text02)

              Spacer()

              // XP Amount
              Text("+\(transaction.amount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.success)
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
    .opacity(appeared ? 1 : 0)
    .scaleEffect(appeared ? 1 : 0.95)
    .offset(y: appeared ? 0 : 10)
    .onAppear {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)) {
        appeared = true
      }
    }
  }

  // MARK: Private

  @State private var appeared = false

  private var progressWidth: (CGFloat) -> CGFloat {
    { totalWidth in
      let progress = xpManager.userProgress.levelProgress
      return totalWidth * CGFloat(progress)
    }
  }

  private var progressGradient: LinearGradient {
    LinearGradient(
      colors: [Color.primary, Color.primaryFocus],
      startPoint: .leading,
      endPoint: .trailing)
  }
}

// MARK: - XPLevelDisplayCompact

struct XPLevelDisplayCompact: View {
  // MARK: Internal

  // ✅ FIX: Use @Environment to properly observe @Observable changes
  @Environment(XPManager.self) private var xpManager

  var body: some View {
    HStack(spacing: 12) {
      // Level Badge
      VStack(spacing: 2) {
        Text("Level")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(.text04)

        Text("\(xpManager.currentLevel)")  // ✅ Read from @Published property
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.text01)
      }
      .frame(width: 40)

      // XP Info
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("\(xpManager.totalXP) XP")  // ✅ Read from @Published property
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.text01)

          Spacer()

          Text(
            "\(xpManager.userProgress.xpForCurrentLevel)/\(xpManager.userProgress.xpForNextLevel)")
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
              .frame(width: progressWidth(geometry.size.width), height: 4)
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

  // MARK: Private

  private var progressWidth: (CGFloat) -> CGFloat {
    { totalWidth in
      let progress = xpManager.userProgress.levelProgress
      return totalWidth * CGFloat(progress)
    }
  }

  private var progressGradient: LinearGradient {
    LinearGradient(
      colors: [Color.primary, Color.primaryFocus],
      startPoint: .leading,
      endPoint: .trailing)
  }
}

// MARK: - XPTransactionRow

struct XPTransactionRow: View {
  // MARK: Internal

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
        .foregroundColor(.success)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  // MARK: Private

  private func iconForReason(_ reason: XPRewardReason) -> String {
    switch reason {
    case .completeHabit:
      "checkmark.circle.fill"
    case .completeAllHabits:
      "star.fill"
    case .streakBonus:
      "flame.fill"
    case .levelUp:
      "arrow.up.circle.fill"
    case .achievement:
      "trophy.fill"
    case .perfectWeek:
      "calendar.badge.checkmark"
    case .firstHabit:
      "star.circle.fill"
    case .comeback:
      "arrow.clockwise.circle.fill"
    }
  }

  private func colorForReason(_ reason: XPRewardReason) -> Color {
    switch reason {
    case .completeHabit:
      .primary
    case .completeAllHabits:
      .warning
    case .streakBonus:
      .warning
    case .levelUp:
      .primaryFocus
    case .achievement:
      .success
    case .perfectWeek:
      .primary
    case .firstHabit:
      .warning
    case .comeback:
      .success
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
    XPLevelDisplay()

    XPLevelDisplayCompact()

    XPTransactionRow(transaction: XPTransaction(
      amount: 15,
      reason: .completeHabit,
      habitName: "Morning Exercise",
      description: "Completed Morning Exercise"))
  }
  .padding()
  .background(Color.gray.opacity(0.1))
}
