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
                      .offset(x: 83, y: -112)
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
                .onChange(of: currentIndex) { newIndex in
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
                // Second screen: phoneImage without pulsing animation
                VStack {
                  Spacer()
                  
                  Image("phoneImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 0)
                    .scaleEffect(1.1)
                  
                  Spacer()
                }
                .frame(height: 300)
                .padding(.top, 20)
                
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

  private let slides = TutorialSlide.tutorialSlides
  
  // MARK: - Pulsing Animation Helpers
  
  private func startPulsingAnimation() {
    guard !isPulsingActive else { return }
    isPulsingActive = true
    animatePulse()
  }
  
  private func animatePulse() {
    // Reset to initial state
    pulsingRingScale = 1.0
    pulsingRingOpacity = 0.6
    
    // Animate outward
    withAnimation(.easeOut(duration: 1.5)) {
      pulsingRingScale = 1.8
      pulsingRingOpacity = 0.0
    }
    
    // Loop back after animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      if isPulsingActive {
        animatePulse()
      }
    }
  }
  
  private func stopPulsingAnimation() {
    isPulsingActive = false
    pulsingRingScale = 1.0
    pulsingRingOpacity = 0.6
  }
}

#Preview {
  TutorialBottomSheet(tutorialManager: TutorialManager())
}
