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
  @State private var showFullScreenText = false

  @State private var ovalOpacity: Double = 1.0
  @State private var showMedal = false
  @State private var medalScale: CGFloat = 0
  @State private var titleOpacity: Double = 0
  @State private var visibleItemCount: Int = 0
  @State private var showContinueButton = false

  private let backgroundColor = OnboardingButton.onboardingBackground
  private let expandFillColor = Color(red: 0.69, green: 0.80, blue: 0.98) // #B0CCF9

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  /// Actual safe area insets from UIKit (parent OnboardingFlowView strips safe area with .ignoresSafeArea(edges: .all)).
  private var safeAreaInsets: UIEdgeInsets {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.keyWindow?.safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
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
            // Use UIKit safe area top inset (parent strips safe area with .ignoresSafeArea(edges: .all))
            Spacer().frame(height: safeAreaInsets.top + 16)

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
          .frame(minHeight: 16, maxHeight: 40)

        HoldToCommitButton {
          viewModel.hasCommitted = true
          startExpandAnimation()
        }
        .background(
          GeometryReader { g in
            Color.clear.preference(key: ButtonFramePreferenceKey.self, value: g.frame(in: .global))
          }
        )
        .padding(.bottom, safeAreaInsets.bottom + 16)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // No .safeAreaPadding(.top) — parent strips safe area, it has no effect
      .opacity(isExpanding ? 0 : 1)
      .allowsHitTesting(!isExpanding)
      .onPreferenceChange(ButtonFramePreferenceKey.self) { buttonFrame = $0 }

      // Layer 3.5: Full-screen commitment screen (final screen after circles)
      if showFullScreenText {
        ZStack {
          expandFillColor
            .ignoresSafeArea()

          VStack(spacing: 0) {
            Spacer()

            Image("Medal")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)
              .scaleEffect(medalScale)
              .padding(.bottom, 16)

            Text("\(displayName) Commitment")
              .font(.appHeadlineSmallEmphasised)
              .foregroundColor(Color(red: 0.10, green: 0.15, blue: 0.30))
              .multilineTextAlignment(.center)
              .opacity(titleOpacity)
              .padding(.horizontal, 24)
              .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 10) {
              ForEach(Array(viewModel.commitmentItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                  Text("•")
                    .font(.appBodyMedium)
                    .foregroundColor(Color(red: 0.15, green: 0.20, blue: 0.35))
                  Text(item)
                    .font(.appBodyMedium)
                    .foregroundColor(Color(red: 0.15, green: 0.20, blue: 0.35))
                }
                .opacity(index < visibleItemCount ? 1 : 0)
              }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
          }
        }
        .transition(.opacity)
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

      if showContinueButton {
        VStack {
          Spacer()
          OnboardingButton.primary(text: "Let's get started!") {
            viewModel.completeOnboarding()
          }
          .padding(.horizontal, 20)
          .padding(.bottom, safeAreaInsets.bottom + 16)
          .accessibilityLabel("Let's get started")
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

    withAnimation(.easeOut(duration: 1.6)) {
      circle1Scale = target1
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      withAnimation(.easeOut(duration: 1.6)) {
        self.circle2Scale = target2
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      withAnimation(.easeOut(duration: 1.6)) {
        self.circle3Scale = target3
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      showFullScreenText = true
      withAnimation(.easeInOut(duration: 0.5)) {
        ovalOpacity = 0
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
      showMedal = true
      withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
        medalScale = 1.0
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      withAnimation(.easeInOut(duration: 0.6)) {
        titleOpacity = 1.0
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
      for index in viewModel.commitmentItems.indices {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.4) {
          withAnimation(.easeInOut(duration: 0.5)) {
            visibleItemCount = index + 1
          }
        }
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
      showConfetti = true
      let generator = UIImpactFeedbackGenerator(style: .heavy)
      generator.impactOccurred()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 7.5) {
      withAnimation(.easeOut(duration: 0.5)) {
        showContinueButton = true
      }
    }
  }
}
