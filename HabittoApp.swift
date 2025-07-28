import SwiftUI

@main
struct HabittoApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear {
                    print("🚀 HabittoApp: App started!")
                }
        }
    }
} 
