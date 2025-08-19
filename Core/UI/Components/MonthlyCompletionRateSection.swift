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
            // Main completion rate card - enhanced prominence and spacing
            VStack(spacing: 24) {
                HStack(spacing: 24) {
                    // Larger, more prominent progress ring with enhanced styling
                    ZStack {
                        // Background circle with enhanced gradient
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.primaryContainer.opacity(0.4), Color.primaryContainer.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 12
                            )
                            .frame(width: 90, height: 90)
                        
                        // Progress circle with enhanced gradient and animation
                        Circle()
                            .trim(from: 0, to: monthlyCompletionRate)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 2.0), value: monthlyCompletionRate)
                        
                        // Enhanced percentage text with better typography
                        Text("\(Int(monthlyCompletionRate * 100))%")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .scaleEffect(celebrationScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: celebrationScale)
                    
                    // Enhanced progress details with better spacing and typography
                    VStack(alignment: .leading, spacing: 12) {
                        Text(getCompletionMessage())
                            .font(.appTitleLargeEmphasised)
                            .foregroundColor(.text01)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("\(monthlyCompletedHabits) of \(monthlyTotalHabits) habits completed this month")
                            .font(.appBodyLarge)
                            .foregroundColor(.text02)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [Color.surface, Color.surface.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [Color.outline3.opacity(0.6), Color.outline3.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
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
    @State private var needsAttentionScale: CGFloat = 1.0
    @State private var trendScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Enhanced section header with better typography
            HStack {
                Text("Habit Spotlight")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Enhanced spotlight card with better spacing and visual hierarchy
            VStack(spacing: 28) {
                // Top performing habit highlight with enhanced styling
                if let topHabit = topPerformingHabit {
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
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 24, weight: .medium))
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
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Superstar Habit")
                                .font(.appLabelMedium)
                                .foregroundColor(.text02)
                            
                            Text(topHabit.name)
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.text01)
                                .lineLimit(1)
                            
                            let rate = monthlyHabitCompletionRate(topHabit)
                            Text("\(Int(rate))% completion rate")
                                .font(.appBodyMedium)
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    
                    // Enhanced divider with better styling
                    Rectangle()
                        .fill(Color.outline3.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
                
                // Needs attention habit with enhanced styling
                if let needsAttentionHabit = needsAttentionHabit {
                    HStack(spacing: 20) {
                        // Enhanced heart icon with better gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.25), Color.red.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.pink)
                        }
                        .scaleEffect(needsAttentionScale)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                needsAttentionScale = 1.2
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    needsAttentionScale = 1.0
                                }
                            }
                            
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Could Use Some Love")
                                .font(.appLabelMedium)
                                .foregroundColor(.text02)
                            
                            Text(needsAttentionHabit.name)
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.text01)
                                .lineLimit(1)
                            
                            let rate = monthlyHabitCompletionRate(needsAttentionHabit)
                            Text("\(Int(rate))% completion rate")
                                .font(.appBodyMedium)
                                .foregroundColor(.pink)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    
                    // Enhanced divider with better styling
                    Rectangle()
                        .fill(Color.outline3.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
                
                // Progress trend with enhanced styling
                HStack(spacing: 20) {
                    // Enhanced trend icon with better gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [progressTrendColor.opacity(0.25), progressTrendColor.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: progressTrendIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(progressTrendColor)
                    }
                    .scaleEffect(trendScale)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            trendScale = 1.2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                trendScale = 1.0
                            }
                        }
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Progress Journey")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                        
                        Text(getTrendMessage())
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.surface, Color.surface.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.outline3.opacity(0.4), Color.outline3.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
        }
    }
    
    // Helper function to get friendly trend message
    private func getTrendMessage() -> String {
        if progressTrendText.contains("Improving") {
            return "You're getting better every day!"
        } else if progressTrendText.contains("Declining") {
            return "Every setback is a setup for a comeback!"
        } else {
            return "You're maintaining great consistency!"
        }
    }
}
