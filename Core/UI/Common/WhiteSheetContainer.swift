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
    scrollOffset: CGFloat = 0,
    headerVisible: Bool = true,
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
    self.scrollOffset = scrollOffset
    self.headerVisible = headerVisible
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
  let scrollOffset: CGFloat
  let headerVisible: Bool
  let content: Content

  var body: some View {
    VStack(spacing: 0) {
      // Header section with dynamic height
      headerSection
        .background(headerBackground)
        .frame(height: scrollResponsive ? calculateHeaderHeight() : nil)  // Dynamic height
        .clipped()  // Hide overflow when collapsed
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: headerVisible)

      // Content area - naturally expands as header collapses
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(contentBackground)
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
  
  /// Calculate header height based on header visibility
  /// Returns full height (90pt) when visible, 0pt when hidden
  private func calculateHeaderHeight() -> CGFloat {
    let fullHeaderHeight: CGFloat = 90  // Approximate header height
    return headerVisible ? fullHeaderHeight : 0
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
    scrollOffset: CGFloat = 0,
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
      scrollOffset: scrollOffset,
      content: content)
  }

  /// Creates a white sheet container with title and subtitle
  init(
    title: String,
    subtitle: String,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    scrollOffset: CGFloat = 0,
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
      scrollOffset: scrollOffset,
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
    scrollOffset: CGFloat = 0,
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
      scrollOffset: scrollOffset,
      content: content)
  }

  /// Creates a white sheet container with only custom header content (no title)
  init(
    headerContent: @escaping () -> AnyView,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    headerCollapseThreshold: CGFloat = 50,
    scrollOffset: CGFloat = 0,
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
      scrollOffset: scrollOffset,
      content: content)
  }

  /// Creates a white sheet container with title and right button
  init(
    title: String,
    rightButton: @escaping () -> AnyView,
    headerBackground: Color = .surface,
    contentBackground: Color = .surface,
    scrollResponsive: Bool = false,
    scrollOffset: CGFloat = 0,
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
      scrollOffset: scrollOffset,
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
