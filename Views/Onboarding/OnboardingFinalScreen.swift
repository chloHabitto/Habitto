import SwiftUI

// MARK: - OnboardingFinalScreen

struct OnboardingFinalScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var contentOpacity: Double = 0

  private let backgroundColor = Color(hex: "000835")

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Text("\(displayName) Commitment")
        .font(.appHeadlineSmallEmphasised)
        .foregroundColor(.white)
        .padding(.bottom, 24)
        .opacity(contentOpacity)

      VStack(alignment: .leading, spacing: 12) {
        ForEach(viewModel.commitmentItems, id: \.self) { item in
          HStack(alignment: .top, spacing: 8) {
            Text("•")
              .font(.appBodyMedium)
              .foregroundColor(.white)
            Text(item)
              .font(.appBodyMedium)
              .foregroundColor(.white)
          }
        }
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .opacity(contentOpacity)

      Spacer()
        .frame(height: 24)

      MascotPlaceholderView(size: 80)
        .opacity(contentOpacity)

      Spacer()

      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text("Let's get started!"),
        state: .default,
        action: {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          viewModel.completeOnboarding()
        }
      )
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
      .opacity(contentOpacity)
      .accessibilityLabel("Let's get started")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .onAppear {
      withAnimation(.easeOut(duration: 0.6)) {
        contentOpacity = 1
      }
    }
  }
}
