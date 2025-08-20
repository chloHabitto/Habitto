import SwiftUI

struct TimeInsightsSection: View {
    let habit: Habit?
    let completionRecords: [CompletionRecordEntity]
    
    var body: some View {
        VStack(spacing: 12) {
            // Enhanced section header
            HStack {
                Text("Time Magic")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Enhanced time insight card
            if let habit = habit {
                enhancedIndividualHabitTimeCard(habit: habit)
            } else {
                enhancedOverallTimeCard()
            }
        }
    }
    
    // MARK: - Enhanced Individual Habit Time Card
    private func enhancedIndividualHabitTimeCard(habit: Habit) -> some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 20) {
                // Enhanced icon with better gradient and animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "clock.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.blue)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                }
                
                // Enhanced content with better typography and spacing
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Golden Hour")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    
                    Text("Morning (8-10 AM)")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(getTimeMotivationalMessage(for: "morning"))
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Bottom time tip section
            VStack(spacing: 8) {
                Divider()
                    .background(Color.outline3.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text("Tip: Schedule your most important habits during this time!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Enhanced Overall Time Card
    private func enhancedOverallTimeCard() -> some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 20) {
                // Enhanced icon with better gradient and animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.purple)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                }
                
                // Enhanced content with better typography and spacing
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Power Time")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.1))
                        )
                    
                    Text("Evening Focus")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(getTimeMotivationalMessage(for: "evening"))
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Bottom time tip section
            VStack(spacing: 8) {
                Divider()
                    .background(Color.outline3.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                    
                    Text("Tip: Use this time for reflection and planning!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Time Motivational Message Helper
    private func getTimeMotivationalMessage(for timeOfDay: String) -> String {
        let messages = [
            "morning": [
                "You're most consistent during this time! 🌅",
                "Early bird gets the worm! ⏰",
                "Your energy is at its peak! ⚡",
                "Perfect time to start strong! 💪"
            ],
            "evening": [
                "Most habits completed after 6 PM 🌙",
                "You're a night owl achiever! 🦉",
                "Evening productivity is your superpower! ✨",
                "You shine when the sun sets! 🌟"
            ]
        ]
        
        let timeMessages = messages[timeOfDay] ?? messages["morning"]!
        return timeMessages.randomElement() ?? timeMessages[0]
    }
}

#Preview {
    TimeInsightsSection(habit: nil, completionRecords: [])
}
