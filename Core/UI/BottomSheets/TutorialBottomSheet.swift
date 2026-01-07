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
              // Image area - phoneImage for first screen, carousel for others
              if index == 0 {
                // First screen: phoneImage
                VStack {
                  Spacer()
                  
                  Image("phoneImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .offset(y: phoneImageOffset)
                    .opacity(phoneImageOpacity)
                  
                  Spacer()
                }
                .frame(height: 280)
                .padding(.top, 20)
                .onAppear {
                  // Animate phoneImage when first screen appears
                  withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    phoneImageOffset = 0
                    phoneImageOpacity = 1.0
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
                  }
                }
                
                // Fixed 48pt spacing between image and text for first screen
                Color.clear
                  .frame(height: 48)
              } else {
                // Other screens: Regular images
                let isLastSlide = slide.id == TutorialSlide.tutorialSlides.last?.id
                VStack {
                  Spacer()
                  
                  Image(slide.imageName)
                    .resizable()
                    .aspectRatio(contentMode: isLastSlide ? .fit : .fill)
                    .frame(width: isLastSlide ? 260 : nil, height: isLastSlide ? 260 : 280)
                    .clipped()
                    .offset(y: isLastSlide ? lastImageOffset : 0)
                    .scaleEffect(isLastSlide ? lastImageScale : 1.0)
                    .opacity(isLastSlide ? lastImageOpacity : 1.0)
                  
                  Spacer()
                }
                .frame(height: 280)
                .padding(.top, 20)
                .onAppear {
                  if isLastSlide {
                    // Animate last slide image when it appears (from bottom to top)
                    lastImageOffset = 30
                    lastImageScale = 0.8
                    lastImageOpacity = 0.0
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                      lastImageOffset = 0
                      lastImageScale = 1.0
                      lastImageOpacity = 1.0
                    }
                  }
                }
                
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
        .onChange(of: currentIndex) { newIndex in
          // Trigger animation when navigating to last slide (from bottom to top)
          if newIndex == slides.count - 1 {
            lastImageOffset = 30
            lastImageScale = 0.8
            lastImageOpacity = 0.0
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
              lastImageOffset = 0
              lastImageScale = 1.0
              lastImageOpacity = 1.0
            }
          }
        }
        
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
  @State private var lastImageOffset: CGFloat = 30
  @State private var lastImageScale: CGFloat = 0.8
  @State private var lastImageOpacity: Double = 0.0

  private let slides = TutorialSlide.tutorialSlides
}

#Preview {
  TutorialBottomSheet(tutorialManager: TutorialManager())
}
