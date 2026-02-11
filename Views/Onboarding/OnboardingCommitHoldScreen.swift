import SwiftUI

// MARK: - Button frame preference (for expanding fill origin)

private struct ButtonFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

// MARK: - OnboardingCommitHoldScreen

struct OnboardingCommitHoldScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel

  @State private var isExpanding = false
  @State private var buttonFrame: CGRect = .zero
  @State private var expandLayer1Scale: CGFloat = 1
  @State private var expandLayer2Scale: CGFloat = 1
  @State private var expandLayer3Scale: CGFloat = 1
  @State private var expandLayer4Scale: CGFloat = 1

  private let backgroundColor = OnboardingButton.onboardingBackground
  private let expandFillColor = Color(red: 0.69, green: 0.80, blue: 0.98) // #B0CCF9
  private let buttonOvalSize = CGSize(width: 91, height: 114)

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
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

        HoldToCommitButton {
          viewModel.hasCommitted = true
          startExpandAnimation()
        }
        .background(
          GeometryReader { g in
            Color.clear.preference(key: ButtonFramePreferenceKey.self, value: g.frame(in: .global))
          }
        )
        .padding(.bottom, 24)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(backgroundColor)
      .onPreferenceChange(ButtonFramePreferenceKey.self) { buttonFrame = $0 }

      // Expanding fill overlay (on top of content)
      if isExpanding {
        GeometryReader { geo in
          let centerX = buttonFrame.isEmpty ? geo.size.width / 2 : (buttonFrame.midX - geo.frame(in: .global).minX)
          let centerY = buttonFrame.isEmpty ? geo.size.height / 2 : (buttonFrame.midY - geo.frame(in: .global).minY)

          ZStack {
            expandingLayer(scale: expandLayer1Scale, opacity: 0.2, centerX: centerX, centerY: centerY)
            expandingLayer(scale: expandLayer2Scale, opacity: 0.4, centerX: centerX, centerY: centerY)
            expandingLayer(scale: expandLayer3Scale, opacity: 0.7, centerX: centerX, centerY: centerY)
            expandingLayer(scale: expandLayer4Scale, opacity: 1.0, centerX: centerX, centerY: centerY)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .highPriorityGesture(DragGesture()) // blocks TabView swipe (forward and backward)
  }

  private func expandingLayer(scale: CGFloat, opacity: Double, centerX: CGFloat, centerY: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 57)
      .fill(expandFillColor.opacity(opacity))
      .frame(width: buttonOvalSize.width, height: buttonOvalSize.height)
      .scaleEffect(scale)
      .position(x: centerX, y: centerY)
  }

  private func startExpandAnimation() {
    isExpanding = true
    // Scale large enough to cover any phone screen (91*15, 114*15)
    let scaleToFill: CGFloat = 15

    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
      expandLayer1Scale = scaleToFill
    }
    withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) {
      expandLayer2Scale = scaleToFill
    }
    withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2)) {
      expandLayer3Scale = scaleToFill
    }
    withAnimation(.spring(response: 0.65, dampingFraction: 0.75).delay(0.3)) {
      expandLayer4Scale = scaleToFill
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
      viewModel.goToNext()
    }
  }
}
