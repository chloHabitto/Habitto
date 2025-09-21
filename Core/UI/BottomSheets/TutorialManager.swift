import SwiftUI

class TutorialManager: ObservableObject {
    @Published var shouldShowTutorial: Bool = false
    
    private let hasSeenTutorialKey = "HasSeenTutorial"
    
    init() {
        print("🔍 TutorialManager: Initializing...")
        
        // Check tutorial status on main actor
        Task { @MainActor in
            self.checkTutorialStatus()
        }
        
        // Recheck after a delay to ensure HabitRepository is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor in
                self?.recheckTutorialStatus()
            }
        }
    }
    
    @MainActor
    private func checkTutorialStatus() {
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: hasSeenTutorialKey)
        
        // Additional check: If user has habits, they've likely used the app before
        // This provides a backup in case UserDefaults was cleared
        // Use a safe approach to check habits count
        let hasHabits = (HabitRepository.shared.habits.count > 0)
        
        // Show tutorial only if user hasn't seen it AND has no habits (truly new user)
        shouldShowTutorial = !hasSeenTutorial && !hasHabits
        
        print("🔍 TutorialManager: HasSeenTutorial = \(hasSeenTutorial), HasHabits = \(hasHabits), ShouldShowTutorial = \(shouldShowTutorial)")
    }
    
    func markTutorialAsSeen() {
        print("🔍 TutorialManager: markTutorialAsSeen() called")
        UserDefaults.standard.set(true, forKey: hasSeenTutorialKey)
        shouldShowTutorial = false
        print("🔍 TutorialManager: Tutorial marked as seen, shouldShowTutorial = false")
    }
    
    @MainActor
    func resetTutorial() {
        print("🔍 TutorialManager: resetTutorial() called")
        UserDefaults.standard.set(false, forKey: hasSeenTutorialKey)
        checkTutorialStatus() // Recheck with new logic
        print("🔍 TutorialManager: Tutorial reset, shouldShowTutorial = \(shouldShowTutorial)")
    }
    
    /// Recheck tutorial status (useful when habits change)
    @MainActor
    func recheckTutorialStatus() {
        print("🔍 TutorialManager: Rechecking tutorial status...")
        checkTutorialStatus()
    }
}
