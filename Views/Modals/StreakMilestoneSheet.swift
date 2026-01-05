import Lottie
import SwiftUI

// MARK: - StreakMilestoneSheet

struct StreakMilestoneSheet: View {
  // MARK: Internal

  @Binding var isPresented: Bool
  let streakCount: Int

  var body: some View {
    ZStack {
      // Full screen background
      StreakColors.cardBackground
        .ignoresSafeArea()

      // Full screen content
      GeometryReader { geometry in
        ZStack(alignment: .top) {
          // Main content area
          VStack(spacing: 0) {
            // Spacer to push content down (reserves space for animation)
            Spacer()
              .frame(height: geometry.size.width * 0.9 + 20)
            
            // "n day" text between animation and container
            Text("\(streakCount) day")
              .font(.system(size: 40, weight: .black))
              .foregroundColor(.primary)
              .lineSpacing(48 - 40) // Line height 48 - font size 40 = 8pt spacing
              .multilineTextAlignment(.center)
              .opacity(showContent ? 1.0 : 0.0)
              .animation(.easeInOut(duration: 0.6).delay(0.1), value: showContent)
            
            // Content area with padding
            VStack(spacing: StreakSpacing.xl) {
              // Combined container with title, description, and week indicator
              WeekIndicatorContainerView(
                title: "You did it!",
                description: milestoneMessage,
                completedDays: completedDaysInWeek)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.6).delay(0.2), value: showContent)
            }
            .padding(StreakSpacing.xxl)
            
            // Fixed spacing between container and button
            Spacer()
              .frame(height: 72)
            
            // Continue button - matching Save button style
            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
              }
            }) {
              Text("Continue")
                .font(.appButtonText1)
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.6).delay(0.6), value: showContent)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
          }
          
          // Animation overlay (positioned absolutely, doesn't affect layout)
          StreakFireAnimation()
            .frame(width: geometry.size.width * 0.9)
            .frame(height: geometry.size.width * 0.9)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .ignoresSafeArea()
    .onAppear {
      startAnimations()
    }
  }

  // MARK: Private

  @State private var showContent = false

  private var milestoneMessage: String {
    switch streakCount {
    case 1:
      return "Every habit starts with a single day 🌱"
    case 3:
      return "You're building momentum! 🔥"
    case 7:
      return "One whole week! Amazing! ⭐"
    case 14:
      return "Two weeks strong! 💪"
    case 30:
      return "A full month! You're unstoppable! 🏆"
    default:
      // For other milestones, use a generic message
      if streakCount >= 30 {
        return "Incredible dedication! Keep going! 🚀"
      } else if streakCount >= 14 {
        return "You're on fire! Keep it up! 🔥"
      } else if streakCount >= 7 {
        return "Great progress! ⭐"
      } else {
        return "Keep building your streak! 💪"
      }
    }
  }

  private var completedDaysInWeek: [Bool] {
    // Calculate which days of the week are completed based on streak
    // For now, show all days as completed if streak >= 7, otherwise show partial
    let calendar = Calendar.current
    let today = Date()
    let weekday = calendar.component(.weekday, from: today)
    // Adjust for Monday = 0
    let mondayOffset = (weekday + 5) % 7
    var days: [Bool] = Array(repeating: false, count: 7)

    if streakCount >= 7 {
      // All days completed
      days = Array(repeating: true, count: 7)
    } else {
      // Show completed days up to streak count, starting from today going backwards
      for i in 0 ..< min(streakCount, 7) {
        let dayIndex = (mondayOffset - i + 7) % 7
        if dayIndex >= 0 && dayIndex < 7 {
          days[dayIndex] = true
        }
      }
    }

    return days
  }

  private func startAnimations() {
    withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
      showContent = true
    }
  }
}

// MARK: - WeekIndicatorContainerView

struct WeekIndicatorContainerView: View {
  let title: String
  let description: String
  let completedDays: [Bool]
  private let dayLabels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

  var body: some View {
    VStack(spacing: 20) {
      // VStack 1: Title + Description
      VStack(spacing: 8) {
        Text(title)
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.text04)
          .multilineTextAlignment(.center)

        Text(description)
          .font(.appBodyLarge)
          .foregroundColor(.text05)
          .multilineTextAlignment(.center)
      }

      // VStack 2: Week indicator (Mo...Su + circles)
      VStack(spacing: 12) {
        // Day labels
        HStack(spacing: 0) {
          ForEach(0 ..< 7, id: \.self) { index in
            Text(dayLabels[index])
              .font(.system(size: 16, weight: .black))
              .foregroundColor(.text07)
              .frame(maxWidth: .infinity)
          }
        }

        // Completion circles
        HStack(spacing: 0) {
          ForEach(0 ..< 7, id: \.self) { index in
            ZStack {
              if completedDays[index] {
                // Filled circle with icon
                Circle()
                  .fill(Color.primary)
                  .frame(width: 24, height: 24)
                
                Image("Icon-Bolt_Filled")
                  .resizable()
                  .renderingMode(.template)
                  .foregroundColor(.onPrimary)
                  .frame(width: 14, height: 14)
              } else {
                // Empty circle with stroke
                Circle()
                  .stroke(Color.text07, lineWidth: 2)
                  .frame(width: 24, height: 24)
              }
            }
            .frame(maxWidth: .infinity)
          }
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
    .background(
      LinearGradient(
        stops: [
          Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
          Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
        ],
        startPoint: UnitPoint(x: 0.08, y: 0.09),
        endPoint: UnitPoint(x: 0.88, y: 1)
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: 28))
    .overlay(
      RoundedRectangle(cornerRadius: 28)
        .stroke(Color.outline02, lineWidth: 2)
    )
  }
}

// MARK: - Preview

#Preview {
  StreakMilestoneSheet(
    isPresented: .constant(true),
    streakCount: 7)
}

