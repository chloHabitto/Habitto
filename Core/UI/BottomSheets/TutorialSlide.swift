import SwiftUI

struct TutorialSlide: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
}

// MARK: - Tutorial Data
extension TutorialSlide {
    static let tutorialSlides: [TutorialSlide] = [
        TutorialSlide(
            imageName: "Add a habit@4x",
            title: "Add a Habit",
            description: "Tap the + button to create your first habit and start building healthy routines."
        ),
        TutorialSlide(
            imageName: "swipe to update progress@4x",
            title: "Track Progress",
            description: "Swipe left or right on your habits to update your daily progress and stay motivated."
        ),
        TutorialSlide(
            imageName: "IMG_6696",
            title: "How to share a feedback",
            description: "Screenshot -> Share -> Share Beta Feedback"
        ),
        TutorialSlide(
            imageName: "IMG_6720",
            title: "Thank you 🩷",
            description: "The app is still a work in progress, so it might not be fully functional or look perfect yet, but I'm continuing to build it, your feedback is really valuable!"
        )
    ]
}
