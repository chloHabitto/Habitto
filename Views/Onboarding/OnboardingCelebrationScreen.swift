import SwiftUI

// MARK: - OnboardingCelebrationScreen

struct OnboardingCelebrationScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel

  @State private var certificateScale: CGFloat = 2.5
  @State private var medalScale: CGFloat = 0
  @State private var titleOpacity: Double = 0
  @State private var visibleItemCount: Int = 0

  private let backgroundColor = OnboardingButton.onboardingBackground
  private let certificateCardSize = CGSize(width: 280, height: 360)

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    ZStack {
      backgroundColor
        .ignoresSafeArea()

      // Certificate (scales from fullscreen to card) with Medal + text overlay
      ZStack(alignment: .top) {
        Image("Certificate")
          .resizable()
          .scaledToFill()
          .frame(width: certificateCardSize.width, height: certificateCardSize.height)
          .clipped()

        VStack(spacing: 0) {
          Image("Medal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 80, height: 80)
            .scaleEffect(medalScale)
            .padding(.top, 24)
            .padding(.bottom, 12)

          Text("\(displayName) Commitment")
            .font(.appHeadlineSmallEmphasised)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .opacity(titleOpacity)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

          VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(viewModel.commitmentItems.enumerated()), id: \.offset) { index, item in
              HStack(alignment: .top, spacing: 6) {
                Text("•")
                  .font(.appBodyMedium)
                  .foregroundColor(.white)
                Text(item)
                  .font(.appBodyMedium)
                  .foregroundColor(.white)
              }
              .opacity(index < visibleItemCount ? 1 : 0)
            }
          }
          .padding(.horizontal, 24)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 24)
        }
      }
      .frame(width: certificateCardSize.width, height: certificateCardSize.height)
      .scaleEffect(certificateScale)
    }
    .onAppear {
      // Phase 2 (0.5s): Medal + title + items appear
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
          medalScale = 1.0
          titleOpacity = 1
        }
        for index in viewModel.commitmentItems.indices {
          let delay = 0.5 + 0.15 * Double(index)
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.3)) {
              visibleItemCount = index + 1
            }
          }
        }
      }

      // Phase 3 (1.5s): Certificate shrinks to card
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
          certificateScale = 1.0
        }
      }

      // Phase 4 (3.0s): Auto-advance
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        viewModel.goToNext()
      }
    }
  }
}
