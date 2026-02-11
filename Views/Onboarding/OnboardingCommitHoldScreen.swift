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

  // Existing expand states
  @State private var isExpanding = false
  @State private var buttonFrame: CGRect = .zero
  @State private var expandLayer1Scale: CGFloat = 1
  @State private var expandLayer2Scale: CGFloat = 1
  @State private var expandLayer3Scale: CGFloat = 1
  @State private var expandLayer4Scale: CGFloat = 1

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
  private let buttonOvalSize = CGSize(width: 91, height: 114)
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

      // Layer 2: Main content (commitment text + hold button) — fade out when expanding
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
              viewModel.goToNext()
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

      // Layer 4: Expanding oval fill layers (ON TOP of certificate)
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
          .opacity(ovalOpacity)
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
    showCertificate = true

    let scaleToFill: CGFloat = 15

    // Phase 1 — Oval expands to fill screen (0.0s – 0.8s)
    withAnimation(.easeInOut(duration: 0.6)) {
      expandLayer1Scale = scaleToFill
    }
    withAnimation(.easeInOut(duration: 0.6).delay(0.05)) {
      expandLayer2Scale = scaleToFill
    }
    withAnimation(.easeInOut(duration: 0.6).delay(0.1)) {
      expandLayer3Scale = scaleToFill
    }
    withAnimation(.easeInOut(duration: 0.6).delay(0.15)) {
      expandLayer4Scale = scaleToFill
    }

    // Phase 2 — Oval fades out, revealing certificate behind it (0.8s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      withAnimation(.easeInOut(duration: 0.5)) {
        ovalOpacity = 0
      }
    }

    // Phase 3 — Medal + text appear on the oversized certificate (1.5s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

    // Phase 4 — Certificate shrinks to card size (2.5s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
        certificateTargetScale = 0.85
      }
    }

    // Phase 5 — "Let's get started!" button appears below the card (3.5s)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
      withAnimation(.easeOut(duration: 0.4)) {
        showContinueButton = true
      }
    }
  }
}
