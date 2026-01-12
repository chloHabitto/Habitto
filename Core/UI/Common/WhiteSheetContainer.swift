import SwiftUI

// MARK: - WhiteSheetContainer

struct WhiteSheetContainer<Content: View>: View {
  // MARK: Lifecycle

  init(
    title: String? = nil,
    subtitle: String? = nil,
    headerContent: (() -> AnyView)? = nil,
    rightButton: (() -> AnyView)? = nil,
    showGrabber: Bool = false,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    headerCollapseThreshold: CGFloat = 50,
    @ViewBuilder content: () -> Content)
  {
    self.title = title
    self.subtitle = subtitle
    self.headerContent = headerContent
    self.rightButton = rightButton
    self.showGrabber = showGrabber
    self.headerBackground = headerBackground
    self.contentBackground = contentBackground
    self.scrollResponsive = scrollResponsive
    self.headerCollapseThreshold = headerCollapseThreshold
    self.content = content()
  }

  // MARK: Internal

  let title: String?
  let subtitle: String?
  let headerContent: (() -> AnyView)?
  let rightButton: (() -> AnyView)?
  let showGrabber: Bool
  let headerBackground: Color
  let contentBackground: Color
  let scrollResponsive: Bool
  let headerCollapseThreshold: CGFloat
  let content: Content
  
  @State private var scrollOffset: CGFloat = 0

  var body: some View {
    VStack(spacing: 0) {
      // Header section with custom background
      headerSection
        .background(headerBackground)
        .offset(y: scrollResponsive ? calculateHeaderOffset() : 0)
        .opacity(scrollResponsive ? calculateHeaderOpacity() : 1)
        .animation(.easeOut(duration: 0.2), value: scrollOffset)

      // Content area with custom background
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(contentBackground)
        .modifier(ScrollOffsetModifier(
          scrollResponsive: scrollResponsive,
          onOffsetChange: { offset in
            scrollOffset = offset
          }))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
    .ignoresSafeArea(.container, edges: .bottom)
  }

  // MARK: Private

  private var headerSection: some View {
    VStack(spacing: 0) {
      // Grabber indicator (if enabled)
      if showGrabber {
        RoundedRectangle(cornerRadius: 2.5)
          .fill(Color(.systemGray3))
          .frame(width: 36, height: 5)
          .padding(.top, 8)
          .padding(.bottom, 4)
      }

      if let title {
        HStack {
          Text(title)
            .font(.appTitleMediumEmphasised)
            .foregroundColor(.text02)

          Spacer()

          if let rightButton {
            rightButton()
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
//                .background(.red)
      }

      if let subtitle {
        HStack {
          Text(subtitle)
            .font(.appTitleSmall)
            .foregroundColor(.text04)

          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
      }

      if let headerContent {
        headerContent()
      }
    }
    .padding(.horizontal, 0)
    .padding(.bottom, 0)
    .frame(maxWidth: .infinity, minHeight: showGrabber ? 20 : 0, alignment: .top)
  }
  
  // MARK: - Scroll-Responsive Calculations
  
  private func calculateHeaderOffset() -> CGFloat {
    // Header height is approximately 100pt (90pt + buffer)
    let headerHeight: CGFloat = 100
    // Negative offset to move header up (hide it)
    let offset = -min(scrollOffset, headerHeight)
    return offset
  }
  
  private func calculateHeaderOpacity() -> Double {
    // Start fading when scroll exceeds threshold
    let fadeStart = headerCollapseThreshold
    let fadeEnd: CGFloat = 100 // Full header height
    
    if scrollOffset < fadeStart {
      return 1.0
    } else if scrollOffset >= fadeEnd {
      return 0.0
    } else {
      // Linear fade between threshold and full height
      let progress = (scrollOffset - fadeStart) / (fadeEnd - fadeStart)
      return Double(1.0 - progress)
    }
  }
}

// MARK: - ScrollOffsetModifier

struct ScrollOffsetModifier: ViewModifier {
  let scrollResponsive: Bool
  let onOffsetChange: (CGFloat) -> Void
  
  func body(content: Content) -> some View {
    if scrollResponsive {
      content
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
          // Debug logging to verify values
          print("📜 Scroll offset (raw): \(offset)")
          
          // When scrolling down, the GeometryReader's minY decreases (becomes negative)
          // We want positive values for scroll distance, so negate it
          // At rest (not scrolled), minY should be 0 or close to 0
          // As we scroll down, minY becomes negative
          let positiveOffset = max(0, -offset)
          print("📜 Scroll offset (positive): \(positiveOffset)")
          onOffsetChange(positiveOffset)
        }
    } else {
      content
    }
  }
}

// MARK: - Convenience Initializers

extension WhiteSheetContainer {
  /// Creates a white sheet container with just a title
  init(
    title: String,
    headerBackground: Color = .surface,
    contentBackground: Color = .white,
    scrollResponsive: Bool = false,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: nil,
      headerContent: nil,
      rightButton: nil,
      showGrabber: false,
      headerBackground: headerBackground,
      contentBackground: contentBackground,
      scrollResponsive: scrollResponsive,
      headerCollapseThreshold: 50,
      content: content)
  }

  /// Creates a white sheet container with title and subtitle
  init(
    title: String,
    subtitle: String,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: subtitle,
      headerContent: nil,
      rightButton: nil,
      showGrabber: false,
      headerBackground: headerBackground,
      contentBackground: contentBackground,
      scrollResponsive: scrollResponsive,
      headerCollapseThreshold: 50,
      content: content)
  }

  /// Creates a white sheet container with custom header content
  init(
    title: String,
    headerContent: @escaping () -> AnyView,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    headerCollapseThreshold: CGFloat = 50,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: nil,
      headerContent: headerContent,
      rightButton: nil,
      showGrabber: false,
      headerBackground: headerBackground,
      contentBackground: contentBackground,
      scrollResponsive: scrollResponsive,
      headerCollapseThreshold: headerCollapseThreshold,
      content: content)
  }

  /// Creates a white sheet container with only custom header content (no title)
  init(
    headerContent: @escaping () -> AnyView,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    headerCollapseThreshold: CGFloat = 50,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: nil,
      subtitle: nil,
      headerContent: headerContent,
      rightButton: nil,
      showGrabber: false,
      headerBackground: headerBackground,
      contentBackground: contentBackground,
      scrollResponsive: scrollResponsive,
      headerCollapseThreshold: headerCollapseThreshold,
      content: content)
  }

  /// Creates a white sheet container with title and right button
  init(
    title: String,
    rightButton: @escaping () -> AnyView,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: nil,
      headerContent: nil,
      rightButton: rightButton,
      showGrabber: false,
      headerBackground: headerBackground,
      contentBackground: contentBackground,
      scrollResponsive: scrollResponsive,
      headerCollapseThreshold: 50,
      content: content)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    WhiteSheetContainer(title: "My Habits") {
      VStack(spacing: 16) {
        Text("Habit content goes here")
          .font(.appBodyMedium)
          .foregroundColor(.text01)

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }

    WhiteSheetContainer(
      title: "Progress",
      subtitle: "Track your habit progress",
      contentBackground: .surface2)
    {
      VStack(spacing: 16) {
        Text("Progress content goes here")
          .font(.appBodyMedium)
          .foregroundColor(.text01)

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }

    WhiteSheetContainer(
      title: "Custom Background",
      contentBackground: .primary.opacity(0.1))
    {
      VStack(spacing: 16) {
        Text("Content with custom background")
          .font(.appBodyMedium)
          .foregroundColor(.text01)

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }
  }
  .background(Color.primary)
  .ignoresSafeArea()
}
