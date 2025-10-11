import Foundation
import SwiftUI

/// Manages the state of habit completion flows to prevent premature list reordering
class CompletionStateManager: ObservableObject {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = CompletionStateManager()

  /// Get all habits currently showing completion sheets
  var activeCompletionHabits: Set<UUID> {
    habitsWithActiveCompletionSheets
  }

  /// Mark a habit as having an active completion sheet
  func startCompletionFlow(for habitId: UUID) {
    DispatchQueue.main.async {
      self.habitsWithActiveCompletionSheets.insert(habitId)
      print("🎯 CompletionStateManager: Started completion flow for habit \(habitId)")
      print(
        "🎯 CompletionStateManager: Active completion sheets: \(self.habitsWithActiveCompletionSheets)")
      print("🎯 CompletionStateManager: Thread: \(Thread.isMainThread ? "Main" : "Background")")
    }
  }

  /// Mark a habit as no longer having an active completion sheet
  func endCompletionFlow(for habitId: UUID) {
    DispatchQueue.main.async {
      self.habitsWithActiveCompletionSheets.remove(habitId)
      print("🎯 CompletionStateManager: Ended completion flow for habit \(habitId)")
      print(
        "🎯 CompletionStateManager: Active completion sheets: \(self.habitsWithActiveCompletionSheets)")
    }
  }

  /// Check if a habit is currently showing a completion sheet
  func isShowingCompletionSheet(for habitId: UUID) -> Bool {
    let result = habitsWithActiveCompletionSheets.contains(habitId)
    print("🎯 CompletionStateManager: isShowingCompletionSheet for \(habitId): \(result)")
    return result
  }

  // MARK: Private

  /// Tracks habits that are currently showing completion sheets
  @Published private var habitsWithActiveCompletionSheets: Set<UUID> = []
}
