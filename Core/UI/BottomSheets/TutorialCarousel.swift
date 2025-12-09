import SwiftUI

// MARK: - TutorialCarousel

struct TutorialCarousel: View {
  let slides: [TutorialSlide]
  @Binding var currentIndex: Int

  var body: some View {
    VStack(spacing: 24) {
      // Carousel
      TabView(selection: $currentIndex) {
        ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
          TutorialSlideView(slide: slide)
            .tag(index)
        }
      }
      .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
      .frame(maxHeight: .infinity)

      // Page Indicators
      HStack(spacing: 8) {
        ForEach(0 ..< slides.count, id: \.self) { index in
          Circle()
            .fill(index == currentIndex ? Color.accentColor : Color.grey300)
            .frame(width: 8, height: 8)
            .animation(.easeInOut(duration: 0.2), value: currentIndex)
        }
      }
    }
  }
}

// MARK: - TutorialSlideView

struct TutorialSlideView: View {
  let slide: TutorialSlide

  var body: some View {
    VStack(spacing: 20) {
      // Image
      Image(slide.imageName)
        .resizable()
        .aspectRatio(contentMode: slide.id == TutorialSlide.tutorialSlides.last?.id
          ? .fit
          : .fill)
          .frame(maxWidth: .infinity)
          .frame(height: 280)
          .clipped()

      // Text Content
      VStack(spacing: 12) {
        Text(slide.title)
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(.text01)
          .multilineTextAlignment(.center)

        Text(slide.description)
          .font(.system(size: 16, weight: .regular))
          .foregroundColor(.text02)
          .multilineTextAlignment(.center)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 20)
    }
  }
}

#Preview {
  TutorialCarousel(
    slides: TutorialSlide.tutorialSlides,
    currentIndex: .constant(0))
    .padding()
}
