import SwiftUI

struct TutorialBottomSheet: View {
  // MARK: Internal

  @ObservedObject var tutorialManager: TutorialManager

  var body: some View {
    BaseBottomSheet(
      title: "Welcome to Habitto!",
      description: "Let's get you started with building healthy habits",
      onClose: {
        tutorialManager.markTutorialAsSeen()
      },
      useGlassCloseButton: true) {
        VStack(spacing: 0) {
          // Carousel
          TutorialCarousel(
            slides: slides,
            currentIndex: $currentIndex)
            .padding(.top, 20)

          Spacer(minLength: 20)

          // Navigation Button
          HabittoButton.largeFillPrimary(
            text: currentIndex < slides.count - 1 ? "Next" : "Get Started",
            action: {
              if currentIndex < slides.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                  currentIndex += 1
                }
              } else {
                tutorialManager.markTutorialAsSeen()
              }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
      }
  }

  // MARK: Private

  @State private var currentIndex = 0

  private let slides = TutorialSlide.tutorialSlides
}

#Preview {
  TutorialBottomSheet(tutorialManager: TutorialManager())
}
