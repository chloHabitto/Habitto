import SwiftUI

struct TutorialBottomSheet: View {
    @ObservedObject var tutorialManager: TutorialManager
    @State private var currentIndex: Int = 0
    
    private let slides = TutorialSlide.tutorialSlides
    
    var body: some View {
        BaseBottomSheet(
            title: "Welcome to Habitto!",
            description: "Let's get you started with building healthy habits",
            onClose: {
                tutorialManager.markTutorialAsSeen()
            }
        ) {
            VStack(spacing: 0) {
                // Carousel
                TutorialCarousel(
                    slides: slides,
                    currentIndex: $currentIndex
                )
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
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    TutorialBottomSheet(tutorialManager: TutorialManager())
}
