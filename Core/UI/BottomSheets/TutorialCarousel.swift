import SwiftUI

// MARK: - TutorialCarousel

struct TutorialCarousel: View {
  let slides: [TutorialSlide]
  @Binding var currentIndex: Int

  var body: some View {
    // Image Carousel (includes all slides for proper swiping)
    TabView(selection: $currentIndex) {
      ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
        if index == 0 {
          // First slide: transparent placeholder (phoneImage shown separately)
          Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .tag(index)
        } else {
          // Regular images for slides 1+
          let isLastSlide = slide.id == TutorialSlide.tutorialSlides.last?.id
          Image(slide.imageName)
            .resizable()
            .aspectRatio(contentMode: isLastSlide ? .fit : .fill)
            .frame(width: isLastSlide ? 260 : nil, height: isLastSlide ? 260 : 280)
            .clipped()
            .tag(index)
        }
      }
    }
    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    .frame(height: 280)
  }
}

// MARK: - TutorialTextContent

struct TutorialTextContent: View {
  let slides: [TutorialSlide]
  @Binding var currentIndex: Int

  var body: some View {
    VStack(spacing: 12) {
      // Title
      Text(slides[currentIndex].title)
        .font(.appHeadlineSmallEmphasised)
        .foregroundColor(.appText04)
        .multilineTextAlignment(.center)

      // Description
      Text(slides[currentIndex].description)
        .font(.appBodyLarge)
        .foregroundColor(.appText05)
        .multilineTextAlignment(.center)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)
    .padding(.bottom, 24)
    .animation(.easeInOut(duration: 0.2), value: currentIndex)
  }
}

#Preview {
  TutorialCarousel(
    slides: TutorialSlide.tutorialSlides,
    currentIndex: .constant(0))
    .padding()
}
