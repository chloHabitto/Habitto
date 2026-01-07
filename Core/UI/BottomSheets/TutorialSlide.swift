import SwiftUI

// MARK: - TutorialSlide

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
      description: "Tap the + button to create your first habit and start building healthy routines."),
    TutorialSlide(
      imageName: "swipe to update progress@4x",
      title: "Track Progress",
      description: "Swipe left or right on your habits to update your daily progress and stay motivated."),
    TutorialSlide(
      imageName: "Love",
      title: "We're here to help 🩷",
      description: "We're constantly working to improve Habitto and help you build better habits. Your feedback means the world to us!")
  ]
}
