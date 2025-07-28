import SwiftUI

@main
struct HabittoApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear {
                    print("🚀 HabittoApp: App started!")
                }
        }
    }
} 
