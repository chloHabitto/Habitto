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
                    .padding(.horizontal, 24)
                  
                  Spacer()
                }
                .frame(height: 280)
                .padding(.top, 20)
                
                // Fixed 48pt spacing between image and text for first screen
                Color.clear
                  .frame(height: 48)
              } else {
                // Other screens: Regular images
                Image(slide.imageName)
                  .resizable()
                  .aspectRatio(contentMode: slide.id == TutorialSlide.tutorialSlides.last?.id
                    ? .fit
                    : .fill)
                  .frame(maxWidth: .infinity)
                  .frame(height: 280)
                  .clipped()
                  .padding(.top, 20)
                
                Spacer()
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

  private let slides = TutorialSlide.tutorialSlides
}

#Preview {
  TutorialBottomSheet(tutorialManager: TutorialManager())
}
