import SwiftUI

// MARK: - OnboardingCommitHoldScreen

struct OnboardingCommitHoldScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel

  private let backgroundColor = OnboardingButton.onboardingBackground

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Spacer()
          .frame(height: 24)

        HStack(spacing: 8) {
          Image("Sticker-Exciting")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
          Text("Exciting!")
            .font(.appBodyMedium)
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(.bottom, 16)

        Text("\(displayName) Commitment")
          .font(.appHeadlineSmallEmphasised)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 24)

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

        Spacer()
          .frame(minHeight: 40)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .safeAreaInset(edge: .bottom) {
      HoldToCommitButton {
        viewModel.hasCommitted = true
        viewModel.goToNext()
      }
      .padding(.bottom, 24)
    }
  }
}
