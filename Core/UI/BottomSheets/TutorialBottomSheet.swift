import SwiftUI

struct TutorialBottomSheet: View {
  // MARK: Internal

  @ObservedObject var tutorialManager: TutorialManager

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Full-screen swipeable TabView
        TabView(selection: $currentIndex) {
          ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
            VStack(spacing: 0) {
              // Image area - phoneImage for first and second screen, carousel for others
              if index == 0 {
                // First screen: phoneImage with pulsing ring
                VStack {
                  Spacer()
                  
                  ZStack {
                    Image("phoneImage")
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(maxWidth: .infinity)
                      .padding(.horizontal, 0)
                      .scaleEffect(1.1)
                      .offset(y: phoneImageOffset)
                      .opacity(phoneImageOpacity)
                    
                    // Pulsing ring animation overlay
                    if currentIndex == 0 && phoneImageOpacity > 0.9 {
                      ZStack {
                        // Outer pulsing ring
                        Circle()
                          .stroke(Color.primary, lineWidth: 2)
                          .frame(width: 40, height: 40)
                          .scaleEffect(pulsingRingScale)
                          .opacity(pulsingRingOpacity)
                        
                        // Inner static circle
                        Circle()
                          .fill(Color.primary.opacity(0.3))
                          .frame(width: 40, height: 40)
                      }
                      .offset(x: 83, y: -112.2)
                    }
                  }
                  
                  Spacer()
                }
                .frame(height: 300)
                .padding(.top, 20)
                .onAppear {
                  // Animate phoneImage when first screen appears
                  withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    phoneImageOffset = 0
                    phoneImageOpacity = 1.0
                  }
                  
                  // Start pulsing ring animation after entrance animation (0.8s delay)
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    startPulsingAnimation()
                  }
                }
                .onChange(of: currentIndex) { _, newIndex in
                  // Reset animation when coming back to first screen
                  if newIndex == 0 {
                    phoneImageOffset = 50
                    phoneImageOpacity = 0.0
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                      phoneImageOffset = 0
                      phoneImageOpacity = 1.0
                    }
                    
                    // Restart pulsing animation after entrance
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                      startPulsingAnimation()
                    }
                  } else {
                    // Stop animation when leaving first screen
                    stopPulsingAnimation()
                  }
                }
                
                // Fixed 48pt spacing between image and text for first screen
                Color.clear
                  .frame(height: 48)
              } else if index == 1 {
                // Second screen: phoneImage with ScheduledHabitItemView overlay
                VStack {
                  Spacer()
                  
                  ZStack {
                    Image("phoneImage")
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(maxWidth: .infinity)
                      .padding(.horizontal, 0)
                      .scaleEffect(1.1)
                    
                    // ScheduledHabitItemView overlay
                    if currentIndex == 1 {
                      ScheduledHabitItem(
                        habit: demoHabit,
                        selectedDate: Date())
                      .fixedSize(horizontal: false, vertical: true) // Fix height to hug content
                      .scaleEffect(0.75) // Scale down to fit phone image
                      .offset(y: -40 + habitItemOffsetY) // Position over phone + animation offset
                      .opacity(habitItemOpacity)
                      
                      // Hand icon overlay for swipe demonstration
                      // Always render (even when opacity is 0) so it can be positioned and animated
                      Image(currentHandIcon)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(currentHandIcon == "Hand-right" ? Color("green300") : Color("red300"))
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 45, height: 45)
                        .offset(x: handIconOffset, y: -40 + habitItemOffsetY)
                        .opacity(handIconOpacity)
                    }
                  }
                  
                  Spacer()
                }
                .frame(height: 300)
                .padding(.top, 20)
                .onAppear {
                  // Reset and start animations when screen 2 appears
                  if currentIndex == 1 {
                    resetHabitItemAnimations()
                    startHabitItemAnimations()
                  }
                }
                .onChange(of: currentIndex) { _, newIndex in
                  if newIndex == 1 {
                    // Reset and start animations when navigating to screen 2
                    resetHabitItemAnimations()
                    startHabitItemAnimations()
                  } else {
                    // Stop animations when leaving screen 2
                    stopHabitItemAnimations()
                  }
                }
                
                // Fixed 48pt spacing between image and text for consistency with first screen
                Color.clear
                  .frame(height: 48)
              } else {
                // Other screens: Regular images
                VStack {
                  Spacer()
                  
                  Image(slide.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                  
                  Spacer()
                }
                .frame(height: 300)
                .padding(.top, 20)
                
                // Fixed 48pt spacing between image and text for consistency with first screen
                Color.clear
                  .frame(height: 48)
              }
              
              // Title + Description + Page Controls
              TutorialTextContent(
                slides: slides,
                currentIndex: $currentIndex)
            }
            .background(Color("appSurface01Variant02"))
            .tag(index)
          }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        
        // Fixed page controls at bottom (outside TabView)
        HStack(spacing: 8) {
          ForEach(0 ..< slides.count, id: \.self) { index in
            Circle()
              .fill(index == currentIndex ? Color.appText02 : Color.grey300.opacity(0.4))
              .frame(width: 8, height: 8)
              .animation(.easeInOut(duration: 0.2), value: currentIndex)
          }
        }
        .padding(.bottom, 16)
        .background(Color("appSurface01Variant02"))
        
        // Fixed button at bottom (outside TabView)
        HabittoButton.largeFillPrimary(
          text: currentIndex < slides.count - 1 ? "Next" : "Get Started",
          action: {
            if currentIndex < slides.count - 1 {
              withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
              }
            } else {
              tutorialManager.markTutorialAsSeen()
              dismiss()
            }
          })
          .padding(.horizontal, 24)
          .padding(.top, 16)
          .padding(.bottom, 24)
          .background(Color("appSurface01Variant02"))
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Tutorial & Tips")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            tutorialManager.markTutorialAsSeen()
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var currentIndex = 0
  @State private var phoneImageOffset: CGFloat = 50
  @State private var phoneImageOpacity: Double = 0.0
  @State private var pulsingRingScale: CGFloat = 1.0
  @State private var pulsingRingOpacity: Double = 0.6
  @State private var isPulsingActive: Bool = false
  
  // Habit item animation state for screen 2
  @State private var habitItemOpacity: CGFloat = 0
  @State private var habitItemOffsetY: CGFloat = 20
  
  // Hand icon animation state
  @State private var handIconOffset: CGFloat = -90 // Start on the left
  @State private var handIconOpacity: CGFloat = 0
  @State private var currentHandIcon: String = "Hand-right" // Switch between Hand-right and Hand-left
  
  // Demo habit with mutable progress
  @State private var demoHabit: Habit = {
    var habit = Habit(
      name: "Morning Exercise",
      description: "30 minutes of cardio",
      icon: "🏃‍♂️",
      color: Color("pastelBlue"),
      habitType: .formation,
      schedule: "Everyday",
      goal: "5 times",
      reminder: "No reminder",
      startDate: Date(),
      endDate: nil)
    // Set initial progress to 2/5
    let dateKey = Habit.dateKey(for: Date())
    habit.completionHistory[dateKey] = 2
    return habit
  }()

  private let slides = TutorialSlide.tutorialSlides
  
  // MARK: - Pulsing Animation Helpers
  
  private func startPulsingAnimation() {
    guard !isPulsingActive else { return }
    isPulsingActive = true
    animatePulse()
  }
  
  private func animatePulse() {
    guard isPulsingActive else { return }
    
    // Reset to initial state without animation
    withAnimation(nil) {
      pulsingRingScale = 1.0
      pulsingRingOpacity = 0.6
    }
    
    // Small delay to ensure reset is applied
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      guard self.isPulsingActive else { return }
      
      // Animate outward
      withAnimation(.easeOut(duration: 1.2)) {
        self.pulsingRingScale = 1.8
        self.pulsingRingOpacity = 0.0
      }
      
      // Loop back after animation completes
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        self.animatePulse()
      }
    }
  }
  
  private func stopPulsingAnimation() {
    isPulsingActive = false
    withAnimation(nil) {
      pulsingRingScale = 1.0
      pulsingRingOpacity = 0.6
    }
  }
  
  // MARK: - Habit Item Animation Helpers
  
  private func resetHabitItemAnimations() {
    habitItemOpacity = 0
    habitItemOffsetY = 20
    handIconOffset = -90
    handIconOpacity = 0
    currentHandIcon = "Hand-right"
    
    // Reset demo habit progress to initial value (2/5)
    let dateKey = Habit.dateKey(for: Date())
    var updatedHabit = demoHabit
    updatedHabit.completionHistory[dateKey] = 2
    demoHabit = updatedHabit
  }
  
  private func startHabitItemAnimations() {
    // Appearing animation: fade in + slide up
    // Delay: 0.3s after screen appears
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation(.easeOut(duration: 0.5)) {
        habitItemOpacity = 1.0
        habitItemOffsetY = 0
      }
      
      // Start hand icon swipe demonstration after appearing animation completes
      // Delay: 0.5s (appearing duration) + 0.8s (additional delay) = 1.3s total
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + 0.8) {
        startHandSwipeDemonstration()
      }
    }
  }
  
  private func startHandSwipeDemonstration() {
    guard currentIndex == 1 else { return }
    
    // Start the sequence: 2 right swipes, then 2 left swipes
    performSwipeSequence(step: 0)
  }
  
  private func performSwipeSequence(step: Int) {
    guard currentIndex == 1 else { return }
    
    // Step 0-1: Right swipes (increase)
    // Step 2-3: Left swipes (decrease)
    let isRightSwipe = step < 2
    let startOffset: CGFloat = isRightSwipe ? -90 : 90
    let endOffset: CGFloat = isRightSwipe ? 90 : -90
    let handIconName = isRightSwipe ? "Hand-right" : "Hand-left"
    let progressChange = isRightSwipe ? 1 : -1
    
    // Determine current progress based on step
    let currentProgress: Int
    switch step {
    case 0: currentProgress = 2  // Start at 2
    case 1: currentProgress = 3  // After first right swipe
    case 2: currentProgress = 4  // After second right swipe
    case 3: currentProgress = 3  // After first left swipe
    default: currentProgress = 2
    }
    let newProgress = currentProgress + progressChange
    
    // Set hand icon type
    currentHandIcon = handIconName
    
    // Reset hand position and opacity instantly (no animation)
    withAnimation(nil) {
      handIconOffset = startOffset
      handIconOpacity = 0
    }
    
    // Small delay to ensure state is set, then start animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      guard self.currentIndex == 1 else { return }
      
      // Animate movement from start to end position (0.8s total)
      withAnimation(.easeInOut(duration: 0.8)) {
        self.handIconOffset = endOffset
      }
      
      // Fade in during first 30% of movement (0.24s = 30% of 0.8s)
      withAnimation(.easeOut(duration: 0.24)) {
        self.handIconOpacity = 1.0
      }
    }
    
    // Update progress at midpoint (0.4s into movement)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      guard self.currentIndex == 1 else { return }
      let dateKey = Habit.dateKey(for: Date())
      var updatedHabit = self.demoHabit
      updatedHabit.completionHistory[dateKey] = newProgress
      self.demoHabit = updatedHabit
    }
    
    // Fade out during last 30% of movement (starts at 0.56s, duration 0.24s)
    // 0.8s - 0.24s = 0.56s (last 30% of 0.8s movement)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
      guard self.currentIndex == 1 else { return }
      withAnimation(.easeIn(duration: 0.24)) {
        self.handIconOpacity = 0
      }
    }
    
    // After swipe completes, move to next step or loop
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      guard self.currentIndex == 1 else { return }
      
      if step < 3 {
        // Continue to next swipe after brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          guard self.currentIndex == 1 else { return }
          self.performSwipeSequence(step: step + 1)
        }
      } else {
        // All swipes complete, pause then loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          guard self.currentIndex == 1 else { return }
          // Reset progress to 2 and restart
          let dateKey = Habit.dateKey(for: Date())
          var updatedHabit = self.demoHabit
          updatedHabit.completionHistory[dateKey] = 2
          self.demoHabit = updatedHabit
          self.performSwipeSequence(step: 0)
        }
      }
    }
  }
  
  private func stopHabitItemAnimations() {
    withAnimation(nil) {
      habitItemOpacity = 0
      habitItemOffsetY = 20
      handIconOffset = -90
      handIconOpacity = 0
      currentHandIcon = "Hand-right"
    }
    
    // Reset demo habit progress
    let dateKey = Habit.dateKey(for: Date())
    var updatedHabit = demoHabit
    updatedHabit.completionHistory[dateKey] = 2
    demoHabit = updatedHabit
  }
}

#Preview {
  TutorialBottomSheet(tutorialManager: TutorialManager())
}
