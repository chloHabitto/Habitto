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
    contentBackground: Color? = nil,
    @ViewBuilder content: () -> Content)
  {
    self.title = title
    self.subtitle = subtitle
    self.headerContent = headerContent
    self.rightButton = rightButton
    self.showGrabber = showGrabber
    // Use .surface as default (adapts to dark mode), or use provided color
    self.contentBackground = contentBackground ?? .surface
    self.content = content()
  }

  // MARK: Internal

  let title: String?
  let subtitle: String?
  let headerContent: (() -> AnyView)?
  let rightButton: (() -> AnyView)?
  let showGrabber: Bool
  let contentBackground: Color
  let content: Content

  var body: some View {
    VStack(spacing: 0) {
      // Header section with surface background
      headerSection
        .background(.surface)

      // Content area with custom background
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 40) // Padding to prevent content from being covered by bottom navigation
        .background(contentBackground)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
    .ignoresSafeArea(edges: .bottom)
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
            .foregroundColor(.onPrimaryContainer)

          Spacer()

          if let rightButton {
            rightButton()
          }
        }
        .padding(.horizontal, 16)
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
}

// MARK: - Convenience Initializers

extension WhiteSheetContainer {
  /// Creates a white sheet container with just a title
  init(title: String, contentBackground: Color? = nil, @ViewBuilder content: () -> Content) {
    self.init(
      title: title,
      subtitle: nil,
      headerContent: nil,
      rightButton: nil,
      showGrabber: false,
      contentBackground: contentBackground,
      content: content)
  }

  /// Creates a white sheet container with title and subtitle
  init(
    title: String,
    subtitle: String,
    contentBackground: Color? = nil,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: subtitle,
      headerContent: nil,
      rightButton: nil,
      showGrabber: false,
      contentBackground: contentBackground,
      content: content)
  }

  /// Creates a white sheet container with custom header content
  init(
    title: String,
    headerContent: @escaping () -> AnyView,
    contentBackground: Color? = nil,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: nil,
      headerContent: headerContent,
      rightButton: nil,
      showGrabber: false,
      contentBackground: contentBackground,
      content: content)
  }

  /// Creates a white sheet container with only custom header content (no title)
  init(
    headerContent: @escaping () -> AnyView,
    contentBackground: Color? = nil,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: nil,
      subtitle: nil,
      headerContent: headerContent,
      rightButton: nil,
      showGrabber: false,
      contentBackground: contentBackground,
      content: content)
  }

  /// Creates a white sheet container with title and right button
  init(
    title: String,
    rightButton: @escaping () -> AnyView,
    contentBackground: Color? = nil,
    @ViewBuilder content: () -> Content)
  {
    self.init(
      title: title,
      subtitle: nil,
      headerContent: nil,
      rightButton: rightButton,
      contentBackground: contentBackground,
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
