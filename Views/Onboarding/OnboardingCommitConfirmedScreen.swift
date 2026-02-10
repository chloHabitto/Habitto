import SwiftUI

// MARK: - OnboardingCommitConfirmedScreen

struct OnboardingCommitConfirmedScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var visibleCheckCount: Int = 0

  private let backgroundColor = Color(hex: "000835")

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
        .frame(height: 24)

      HStack(spacing: 8) {
        Image("Sticker-Exciting")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 48, height: 48)
        Text("Exciting!")
          .font(.appTitleLarge)
          .foregroundColor(.white)
      }
      .padding(.bottom, 20)

      Text("\(displayName) Commitment")
        .font(.appHeadlineSmallEmphasised)
        .foregroundColor(.white)
        .padding(.bottom, 24)

      VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(viewModel.commitmentItems.enumerated()), id: \.offset) { index, item in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 20))
              .foregroundColor(Color("appSuccess"))
              .opacity(index < visibleCheckCount ? 1 : 0)
            Text("• \(item)")
              .font(.appBodyMedium)
              .foregroundColor(.white)
          }
        }
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .onAppear {
      for index in viewModel.commitmentItems.indices {
        let delay = 0.2 + Double(index) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          withAnimation(.easeOut(duration: 0.3)) {
            visibleCheckCount = index + 1
          }
        }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        viewModel.goToNext()
      }
    }
  }
}
