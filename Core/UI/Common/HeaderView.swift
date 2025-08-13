import SwiftUI

// MARK: - Helper Functions
private func pluralizeStreak(_ count: Int) -> String {
    if count == 0 {
        return "0 streak"
    } else if count == 1 {
        return "1 streak"
    } else {
        return "\(count) streaks"
    }
}

struct HeaderView: View {
    let onCreateHabit: () -> Void
    let onStreakTap: () -> Void
    let onNotificationTap: () -> Void
    let showProfile: Bool
    let currentStreak: Int
    
    init(onCreateHabit: @escaping () -> Void, onStreakTap: @escaping () -> Void, onNotificationTap: @escaping () -> Void, showProfile: Bool = false, currentStreak: Int = 0) {
        self.onCreateHabit = onCreateHabit
        self.onStreakTap = onStreakTap
        self.onNotificationTap = onNotificationTap
        self.showProfile = showProfile
        self.currentStreak = currentStreak
    }
    
    var body: some View {
        HStack {
            if showProfile {
                // Profile section
                ZStack {
                    HStack(spacing: 12) {
                        // Profile image
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text("C")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.black)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hi Chloe,")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                            
                            Button("View Profile >") {
                                // TODO: Handle profile view action
                            }
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white)
                        }
                    }
                }
            } else {
                // Streak pill
                Button(action: onStreakTap) {
                    HStack(spacing: 6) {
                        Image(.iconFire)
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text(pluralizeStreak(currentStreak))
                            .font(.appButtonText1)
                            .foregroundColor(.black)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                // Notification bell
                Button(action: onNotificationTap) {
                    Image(.iconNotification)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                
                // Add (+) button
                Button(action: onCreateHabit) {
                    Image(.iconPlusCircle)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 28)
        .padding(.bottom, 28)
    }
} 
