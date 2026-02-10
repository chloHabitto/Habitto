import SwiftUI

// MARK: - OnboardingCelebrationScreen

struct OnboardingCelebrationScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var starScales: [CGFloat] = Array(repeating: 0, count: 8)
  @State private var mascotScale: CGFloat = 0.8
  @State private var listOpacity: Double = 0

  private let backgroundColor = Color(hex: "000835")

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Your" : "\(trimmed)'s"
  }

  var body: some View {
    ZStack {
      backgroundColor
        .ignoresSafeArea()

      ForEach(0 ..< 8, id: \.self) { index in
        Image(systemName: "star.fill")
          .font(.system(size: 24))
          .foregroundColor(.white.opacity(0.6))
          .offset(
            x: cos(Double(index) * .pi / 4) * 120,
            y: sin(Double(index) * .pi / 4) * 100
          )
          .scaleEffect(starScales.indices.contains(index) ? starScales[index] : 0)
      }

      VStack(spacing: 0) {
        Spacer()

        MascotPlaceholderView(size: 120)
          .scaleEffect(mascotScale)
          .padding(.bottom, 32)

        Text("\(displayName) Commitment")
          .font(.appHeadlineSmallEmphasised)
          .foregroundColor(.white.opacity(0.9))
          .padding(.bottom, 8)

        VStack(alignment: .leading, spacing: 4) {
          ForEach(viewModel.commitmentItems, id: \.self) { item in
            Text("• \(item)")
              .font(.appBodySmall)
              .foregroundColor(.white.opacity(0.5))
          }
        }
        .padding(.horizontal, 32)
        .opacity(listOpacity)

        Spacer()
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        mascotScale = 1.0
      }
      for index in 0 ..< 8 {
        let delay = 0.1 + Double(index) * 0.05
        let idx = index
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if starScales.indices.contains(idx) {
              var next = starScales
              next[idx] = 1.0
              starScales = next
            }
          }
        }
      }
      withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
        listOpacity = 1
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        viewModel.goToNext()
      }
    }
  }
}
