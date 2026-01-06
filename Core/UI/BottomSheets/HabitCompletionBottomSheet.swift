import SwiftUI

// MARK: - HabitCompletionBottomSheet

struct HabitCompletionBottomSheet: View {
  @Binding var isPresented: Bool
  let habit: Habit
  let completionDate: Date
  @State private var selectedDifficulty: HabitDifficulty?
  let onDismiss: (() -> Void)?

  enum HabitDifficulty: Int, CaseIterable {
    case veryEasy = 1
    case easy = 2
    case medium = 3
    case hard = 4
    case veryHard = 5

    // MARK: Internal

    var displayName: String {
      switch self {
      case .veryEasy: "Very Easy"
      case .easy: "Easy"
      case .medium: "Medium"
      case .hard: "Hard"
      case .veryHard: "Very Hard"
      }
    }

    var color: Color {
      switch self {
      case .veryEasy: .green
      case .easy: .mint
      case .medium: .orange
      case .hard: .red
      case .veryHard: .purple
      }
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // Header Section
      headerSection

      // Difficulty Rating Section
      difficultyRatingSection

      // Action Buttons
      Spacer()

      actionButtons
    }
    .onAppear {
      print("🎯 HabitCompletionBottomSheet: onAppear called for habit: \(habit.name)")
      // Set default difficulty to very easy
      selectedDifficulty = .veryEasy

      // Haptic feedback for completion celebration
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
    }
    .padding(.horizontal, 24)
    .padding(.top, 24)
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.surface01Variant)
    .ignoresSafeArea(edges: .bottom)
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 4) {
      // Close button and title row
      HStack {
        Spacer()
        
        // Close button
        Button(action: {
          isPresented = false
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(.text07)
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, -12)
      }
      .padding(.top, 8)

      // Title
      Text("Good job!")
        .font(Font.appHeadlineSmallEmphasised)
        .foregroundColor(.text01)
        .frame(maxWidth: .infinity, alignment: .center)

      // Difficulty question
      Text("How difficult was this habit today?")
        .font(Font.appBodyMediumEmphasised)
        .foregroundColor(.text05)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  // MARK: - Habit Info Section

  private var habitInfoSection: some View {
    VStack(spacing: 16) {
      // Habit icon and name
      HStack(spacing: 16) {
        HabitIconView(habit: habit)
          .frame(width: 48, height: 48)

        VStack(alignment: .leading, spacing: 4) {
          Text(habit.name)
            .font(Font.appTitleMediumEmphasised)
            .foregroundColor(.text01)

          if !habit.description.isEmpty {
            Text(habit.description)
              .font(Font.appBodyMedium)
              .foregroundColor(.text03)
              .lineLimit(2)
          }

          // Progress context
          HStack(spacing: 8) {
            if habit.computedStreak() > 0 {
              HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                  .font(.caption)
                  .foregroundColor(.orange)
                Text("\(habit.computedStreak()) day streak")
                  .font(Font.appBodySmall)
                  .foregroundColor(.text03)
              }
            }

            if habit.computedStreak() > 0 {
              Text("•")
                .font(.appBodySmall)
                .foregroundColor(.text04)
            }

            Text("Completed today!")
              .font(.appBodySmall)
              .foregroundColor(.green)
          }
        }

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(.surface2)
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(.outline3, lineWidth: 1))
    }
  }

  // MARK: - Difficulty Rating Section

  private var difficultyRatingSection: some View {
    VStack(spacing: 24) {
      // Difficulty slider
      VStack(spacing: 16) {
        // Character image with chat bubble
        if let difficulty = selectedDifficulty {
          HStack(alignment: .center, spacing: 12) {
            // Character image
            Group {
              switch difficulty {
              case .veryEasy:
                Image("Difficulty-VeryEasy@4x")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: 128)

              case .easy:
                Image("Difficulty-Easy@4x")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: 128)

              case .medium:
                Image("Difficulty-Medium@4x")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: 128)

              case .hard:
                Image("Difficulty-Hard@4x")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: 128)

              case .veryHard:
                Image("Difficulty-VeryHard@4x")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: 128)
              }
            }
            
            // Chat bubble
            ZStack {
              // Chat bubble image
              Image("Chatbubble-stroke")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .foregroundColor(.appOutline02)
              
              // Text overlay on chat bubble
              Text(difficulty.displayName + "!")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text03)
                .padding(.leading, 10)
            }
            .padding(.leading, 8)
          }
          .frame(maxWidth: .infinity)
          .padding(.bottom, 8)
        }

        // Slider
        Slider(
          value: Binding(
            get: {
              if let difficulty = selectedDifficulty {
                return Double(difficulty.rawValue)
              }
              return 1.0 // Default to very easy
            },
            set: { value in
              // Convert slider value to difficulty
              let difficultyValue = Int(round(value))
              let newDifficulty = HabitDifficulty(rawValue: difficultyValue) ?? .veryEasy

              // Only trigger haptic if difficulty actually changed
              if selectedDifficulty != newDifficulty {
                selectedDifficulty = newDifficulty

                // Haptic feedback for slider movement
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
              }
            }),
          in: 1 ... 5,
          step: 1)
          .accentColor(.primary)

        // Difficulty labels
        HStack {
          Text("Very Easy")
            .font(.appBodySmallEmphasised)
            .foregroundColor(.text02)

          Spacer()

          Text("Very Hard")
            .font(.appBodySmallEmphasised)
            .foregroundColor(.text02)
        }
      }
    }
  }

  // MARK: - Action Buttons

  private var actionButtons: some View {
    HStack(spacing: 16) {
      // Skip button
      Button(action: {
        isPresented = false
        onDismiss?()
      }) {
        Text("Skip")
          .font(Font.appButtonText1)
          .foregroundColor(.text04)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(.badgeBackground)
          .cornerRadius(30)
      }
      .buttonStyle(PlainButtonStyle())

      // Submit button
      Button(action: {
        // Save difficulty rating to habit data
        if let difficulty = selectedDifficulty {
          saveDifficultyRating(difficulty)
        }
        isPresented = false
        onDismiss?()
      }) {
        Text("Submit")
          .font(Font.appButtonText1)
          .foregroundColor(.onPrimary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(selectedDifficulty != nil ? .primary : .disabledBackground)
          .cornerRadius(30)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(false)
    }
  }

  // MARK: - Save Difficulty Rating

  private func saveDifficultyRating(_ difficulty: HabitDifficulty) {
    // Convert difficulty to integer (1-5 scale)
    let difficultyValue = Int32(difficulty.rawValue)

    // Save to Core Data using HabitRepository with the actual completion date
    HabitRepository.shared.saveDifficultyRating(
      habitId: habit.id,
      date: completionDate,
      difficulty: difficultyValue)

    print(
      "🎯 HabitCompletionBottomSheet: Saved difficulty rating \(difficulty.displayName) for habit '\(habit.name)' on \(completionDate)")
  }
}

// MARK: - Corner Radius Extension

extension View {
  func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
    clipShape(RoundedCorner(radius: radius, corners: corners))
  }
}

#Preview {
  HabitCompletionBottomSheet(
    isPresented: .constant(true),
    habit: Habit(
      name: "Read Books",
      description: "Read at least one chapter every day",
      icon: "📚",
      color: .blue,
      habitType: .formation,
      schedule: "Everyday",
      goal: "1 chapter",
      reminder: "No reminder",
      startDate: Date(),
      endDate: nil),
    completionDate: Date(),
    onDismiss: { })
    .background(.surface2)
}
