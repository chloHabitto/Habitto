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
  @State private var circle1Scale: CGFloat = 1.0
  @State private var circle2Scale: CGFloat = 1.0
  @State private var circle3Scale: CGFloat = 1.0
  @State private var showConfetti = false

  // Certificate + Medal animation states
  @State private var showCertificate = false
  @State private var ovalOpacity: Double = 1.0
  @State private var showMedal = false
  @State private var medalScale: CGFloat = 0
  @State private var titleOpacity: Double = 0
  @State private var visibleItemCount: Int = 0
  @State private var certificateTargetScale: CGFloat = 3.0
  @State private var showContinueButton = false

  private let backgroundColor = OnboardingButton.onboardingBackground
  private let expandFillColor = Color(red: 0.69, green: 0.80, blue: 0.98) // #B0CCF9
  private let certificateCardSize = CGSize(width: 320, height: 420)

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    ZStack {
      // Layer 1: Background
      backgroundColor
        .ignoresSafeArea()

      // Layer 2: Main content + hold button
      VStack(spacing: 0) {
        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            Spacer().frame(height: 60)

            HStack(spacing: 8) {
              Image("Sticker-Exciting")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
              Text("Exciting!")
                .font(.appBodyMedium)
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 20)

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
          }
        }
        .frame(maxWidth: .infinity)

        Spacer()

        HoldToCommitButton {
          viewModel.hasCommitted = true
          startExpandAnimation()
        }
        .background(
          GeometryReader { g in
            Color.clear.preference(key: ButtonFramePreferenceKey.self, value: g.frame(in: .global))
          }
        )
        .padding(.bottom, 50)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .opacity(isExpanding ? 0 : 1)
      .allowsHitTesting(!isExpanding)
      .onPreferenceChange(ButtonFramePreferenceKey.self) { buttonFrame = $0 }

      // Layer 3 + 5 combined: Certificate card with overlaid Medal + text (BEHIND oval)
      if showCertificate {
        VStack(spacing: 0) {
          Spacer()

          ZStack(alignment: .top) {
            Image("Certificate")
              .resizable()
              .scaledToFill()
              .frame(width: certificateCardSize.width, height: certificateCardSize.height)
              .clipped()

            if showMedal {
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
                  .padding(.horizontal, 16)
                  .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 6) {
                  ForEach(Array(viewModel.commitmentItems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                      Text("•")
                        .font(.appBodySmall)
                        .foregroundColor(.white)
                      Text(item)
                        .font(.appBodySmall)
                        .foregroundColor(.white)
                    }
                    .opacity(index < visibleItemCount ? 1 : 0)
                  }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
          .frame(width: certificateCardSize.width, height: certificateCardSize.height)
          .cornerRadius(16)
          .scaleEffect(certificateTargetScale)

          if showContinueButton {
            OnboardingButton.primary(text: "Let's get started!") {
              viewModel.completeOnboarding()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .accessibilityLabel("Let's get started")
          } else {
            Spacer()
              .frame(height: 64)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
      }

      // Layer 4: Expanding circle ripple layers
      if isExpanding {
        Color.clear
          .ignoresSafeArea()
          .overlay(
            ZStack {
              Circle()
                .fill(expandFillColor.opacity(0.12))
                .frame(width: 180, height: 180)
                .scaleEffect(circle1Scale)

              Circle()
                .fill(expandFillColor.opacity(0.35))
                .frame(width: 150, height: 150)
                .scaleEffect(circle2Scale)

              Circle()
                .fill(expandFillColor)
                .frame(width: 120, height: 120)
                .scaleEffect(circle3Scale)
            }
            .position(
              x: buttonFrame.isEmpty ? UIScreen.main.bounds.width / 2 : buttonFrame.midX,
              y: buttonFrame.isEmpty ? UIScreen.main.bounds.height * 0.75 : buttonFrame.midY
            )
          )
          .opacity(ovalOpacity)
          .allowsHitTesting(false)
      }

      if showConfetti {
        OnboardingConfettiOverlay()
          .ignoresSafeArea()
          .allowsHitTesting(false)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .highPriorityGesture(DragGesture()) // blocks TabView swipe (forward and backward)
  }

  private func startExpandAnimation() {
    isExpanding = true

    let screenDiagonal = sqrt(
      pow(UIScreen.main.bounds.width, 2) +
      pow(UIScreen.main.bounds.height, 2)
    )
    let target1 = (screenDiagonal * 1.5) / 180
    let target2 = (screenDiagonal * 1.5) / 150
    let target3 = (screenDiagonal * 1.5) / 120

    withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 2.4)) {
      circle1Scale = target1
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 2.4)) {
        self.circle2Scale = target2
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 2.4)) {
        self.circle3Scale = target3
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
      showCertificate = true
      withAnimation(.easeInOut(duration: 0.5)) {
        ovalOpacity = 0
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
      showMedal = true
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        medalScale = 1.0
      }
      withAnimation(.easeOut(duration: 0.4)) {
        titleOpacity = 1.0
      }
      for index in viewModel.commitmentItems.indices {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.15) {
          withAnimation(.easeOut(duration: 0.3)) {
            visibleItemCount = index + 1
          }
        }
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
        certificateTargetScale = 0.85
      }
      showConfetti = true
      let generator = UIImpactFeedbackGenerator(style: .heavy)
      generator.impactOccurred()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
      withAnimation(.easeOut(duration: 0.5)) {
        showContinueButton = true
      }
    }
  }
}
