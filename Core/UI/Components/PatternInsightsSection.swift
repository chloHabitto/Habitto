import SwiftUI

struct PatternInsightsSection: View {
    let habit: Habit?
    let completionRecords: [CompletionRecordEntity]
    let difficultyLogs: [DifficultyLogEntity]
    
    var body: some View {
        VStack(spacing: 20) {
            // Enhanced section header
            HStack {
                Text("Pattern Magic")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Enhanced pattern insight card
            if let habit = habit {
                enhancedIndividualHabitPatternCard(habit: habit)
            } else {
                enhancedOverallPatternCard()
            }
        }
    }
    
    // MARK: - Enhanced Individual Habit Pattern Card
    private func enhancedIndividualHabitPatternCard(habit: Habit) -> some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 20) {
                // Enhanced icon with better gradient and animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.25), Color.teal.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.green)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                }
                
                // Enhanced content with better typography and spacing
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Rhythm")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    
                    Text("Every 2-3 Days")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(getPatternMotivationalMessage(for: "individual"))
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Bottom pattern tip section
            VStack(spacing: 8) {
                Divider()
                    .background(Color.outline3.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.pink)
                    
                    Text("Tip: Consistency beats perfection every time!")
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
                                colors: [Color.green.opacity(0.2), Color.teal.opacity(0.1)],
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
    
    // MARK: - Enhanced Overall Pattern Card
    private func enhancedOverallPatternCard() -> some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 20) {
                // Enhanced icon with better gradient and animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.teal.opacity(0.25), Color.green.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis.circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.teal)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                }
                
                // Enhanced content with better typography and spacing
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Journey")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.teal.opacity(0.1))
                        )
                    
                    Text("Improving")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(getPatternMotivationalMessage(for: "overall"))
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Bottom pattern tip section
            VStack(spacing: 8) {
                Divider()
                    .background(Color.outline3.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text("Tip: Every small step is progress toward your goals!")
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
                                colors: [Color.teal.opacity(0.2), Color.green.opacity(0.1)],
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
    
    // MARK: - Pattern Motivational Message Helper
    private func getPatternMotivationalMessage(for patternType: String) -> String {
        let messages = [
            "individual": [
                "You're building a consistent rhythm! 🎵",
                "Your pattern shows dedication! 💎",
                "You're creating lasting change! 🌱",
                "Your consistency is inspiring! ✨"
            ],
            "overall": [
                "Your consistency is getting better! 📈",
                "You're on an upward trajectory! 🚀",
                "Every day you're getting stronger! 💪",
                "Your progress is unstoppable! 🔥"
            ]
        ]
        
        let patternMessages = messages[patternType] ?? messages["individual"]!
        return patternMessages.randomElement() ?? patternMessages[0]
    }
}

#Preview {
    PatternInsightsSection(habit: nil, completionRecords: [], difficultyLogs: [])
}
