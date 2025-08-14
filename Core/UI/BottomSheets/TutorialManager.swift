import SwiftUI

class TutorialManager: ObservableObject {
    @Published var shouldShowTutorial: Bool = false
    
    private let hasSeenTutorialKey = "HasSeenTutorial"
    
    init() {
        checkTutorialStatus()
    }
    
    private func checkTutorialStatus() {
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: hasSeenTutorialKey)
        shouldShowTutorial = !hasSeenTutorial
    }
    
    func markTutorialAsSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenTutorialKey)
        shouldShowTutorial = false
    }
    
    func resetTutorial() {
        UserDefaults.standard.set(false, forKey: hasSeenTutorialKey)
        shouldShowTutorial = true
    }
}
