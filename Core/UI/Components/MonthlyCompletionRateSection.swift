import SwiftUI

struct MonthlyCompletionRateSection: View {
    let monthlyCompletionRate: Double
    let monthlyCompletedHabits: Int
    let monthlyTotalHabits: Int
    let topPerformingHabit: Habit?
    let needsAttentionHabit: Habit?
    let progressTrendColor: Color
    let progressTrendIcon: String
    let progressTrendText: String
    let progressTrendDescription: String
    let monthlyHabitCompletionRate: (Habit) -> Double
    
    // Celebration state
    @State private var showingCelebration = false
    @State private var celebrationScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32) {
                        // Main completion rate card - matching today's progress card style
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Month's Progress")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.onPrimaryContainer)
                        
                        Text(getCompletionMessage())
                            .font(.appBodyMedium)
                            .foregroundColor(.text02)
                    }
                    
                    Spacer()
                    
                    // Circular progress ring on the right - matching today's style
                    ZStack {
                        Circle()
                            .stroke(Color.outline3.opacity(0.3), lineWidth: 6)
                            .frame(width: 48, height: 48)
                        
                        Circle()
                            .trim(from: 0, to: monthlyCompletionRate)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: monthlyCompletionRate)
                        
                        Text("\(Int(monthlyCompletionRate * 100))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .scaleEffect(celebrationScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: celebrationScale)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.outline3.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
            .overlay(
                // Celebration confetti overlay
                CelebrationConfettiView(isVisible: showingCelebration)
            )
            
            // Enhanced Habit Spotlight with better visual hierarchy
            HabitSpotlightSection(
                topPerformingHabit: topPerformingHabit,
                needsAttentionHabit: needsAttentionHabit,
                progressTrendColor: progressTrendColor,
                progressTrendIcon: progressTrendIcon,
                progressTrendText: progressTrendText,
                monthlyHabitCompletionRate: monthlyHabitCompletionRate
            )
        }
        .onAppear {
            // Trigger celebration animation when view appears if progress is good
            if monthlyCompletionRate >= 0.7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    triggerCelebration()
                }
            }
        }
        .onChange(of: monthlyCompletionRate) { oldValue, newValue in
            // Trigger celebration when progress improves significantly
            if newValue > oldValue && newValue >= 0.8 {
                triggerCelebration()
            }
        }
    }
    
    // Helper function to get friendly completion message
    private func getCompletionMessage() -> String {
        let percentage = monthlyCompletionRate * 100
        
        switch percentage {
        case 90...100:
            return "You're absolutely crushing it!"
        case 75..<90:
            return "You're doing amazing!"
        case 60..<75:
            return "Great progress! Keep going!"
        case 40..<60:
            return "You're on the right track!"
        case 20..<40:
            return "Every step counts!"
        default:
            return "Starting is the hardest part!"
        }
    }
    
    // Celebration trigger function
    private func triggerCelebration() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            celebrationScale = 1.1
        }
        
        showingCelebration = true
        
        // Reset scale after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                celebrationScale = 1.0
            }
        }
        
        // Hide confetti after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showingCelebration = false
        }
        
        // Haptic feedback for celebration
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Celebration Confetti View
struct CelebrationConfettiView: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                // Confetti pieces
                ForEach(0..<20, id: \.self) { index in
                    ConfettiPiece(
                        color: confettiColors[index % confettiColors.count],
                        delay: Double(index) * 0.1,
                        position: confettiPositions[index % confettiPositions.count]
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
    
    private let confettiColors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink
    ]
    
    private let confettiPositions: [CGPoint] = [
        CGPoint(x: 0.2, y: 0.1), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.1, y: 0.8),
        CGPoint(x: 0.9, y: 0.9), CGPoint(x: 0.5, y: 0.1), CGPoint(x: 0.3, y: 0.7),
        CGPoint(x: 0.7, y: 0.3), CGPoint(x: 0.2, y: 0.6), CGPoint(x: 0.8, y: 0.4),
        CGPoint(x: 0.4, y: 0.8), CGPoint(x: 0.6, y: 0.2), CGPoint(x: 0.1, y: 0.3),
        CGPoint(x: 0.9, y: 0.7), CGPoint(x: 0.5, y: 0.9), CGPoint(x: 0.3, y: 0.1),
        CGPoint(x: 0.7, y: 0.8), CGPoint(x: 0.2, y: 0.4), CGPoint(x: 0.8, y: 0.6),
        CGPoint(x: 0.4, y: 0.2), CGPoint(x: 0.6, y: 0.9)
    ]
}

// MARK: - Individual Confetti Piece
struct ConfettiPiece: View {
    let color: Color
    let delay: Double
    let position: CGPoint
    
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .position(
                x: UIScreen.main.bounds.width * position.x,
                y: UIScreen.main.bounds.height * position.y
            )
            .opacity(isAnimating ? 0 : 1)
            .scaleEffect(isAnimating ? 0.1 : 1.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 1.5)) {
                        isAnimating = true
                    }
                }
            }
    }
}

// MARK: - Enhanced Habit Spotlight Section
struct HabitSpotlightSection: View {
    let topPerformingHabit: Habit?
    let needsAttentionHabit: Habit?
    let progressTrendColor: Color
    let progressTrendIcon: String
    let progressTrendText: String
    let monthlyHabitCompletionRate: (Habit) -> Double
    
    // Micro-interaction states
    @State private var topHabitScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            // Enhanced section header with better typography
            HStack {
                Text("Habit Spotlight")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Enhanced spotlight card - only showing superstar habit
            if let topHabit = topPerformingHabit {
                VStack(spacing: 0) {
                    // Main content
                    HStack(spacing: 20) {
                        // Enhanced star icon with better gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                        .scaleEffect(topHabitScale)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                topHabitScale = 1.2
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    topHabitScale = 1.0
                                }
                            }
                            
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // Enhanced content with better typography and spacing
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Superstar Habit")
                                .font(.appLabelMedium)
                                .foregroundColor(.text02)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.yellow.opacity(0.1))
                                )
                            
                            Text(topHabit.name)
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.text01)
                                .lineLimit(2)
                            
                            let rate = monthlyHabitCompletionRate(topHabit)
                            Text("\(Int(rate))% completion rate")
                                .font(.appBodyMedium)
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    
                    // Bottom motivational section
                    VStack(spacing: 8) {
                        Divider()
                            .background(Color.outline3.opacity(0.3))
                        
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yellow)
                            
                            Text("Tip: Keep shining! You're setting an amazing example!")
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
                                        colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.1)],
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
        }
    }
}
