import SwiftUI

struct WhiteSheetContainer<Content: View>: View {
    let title: String?
    let subtitle: String?
    let headerContent: (() -> AnyView)?
    let rightButton: (() -> AnyView)?
    let showGrabber: Bool
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        headerContent: (() -> AnyView)? = nil,
        rightButton: (() -> AnyView)? = nil,
        showGrabber: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerContent = headerContent
        self.rightButton = rightButton
        self.showGrabber = showGrabber
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section with title
            headerSection
            
            // Content area
            content
        }
        .roundedTopBackground()
    }
    
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
            
            if let title = title {
                HStack {
                    Text(title)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Spacer()
                    
                    if let rightButton = rightButton {
                        rightButton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
//                .background(.red)
            }
            
            if let subtitle = subtitle {
                HStack {
                    Text(subtitle)
                        .font(.appTitleSmall)
                        .foregroundColor(.text04)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            if let headerContent = headerContent {
                headerContent()
            }
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 0)
        .frame(alignment: .top)
    }

}

// MARK: - Convenience Initializers
extension WhiteSheetContainer {
    /// Creates a white sheet container with just a title
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: nil, headerContent: nil, rightButton: nil, showGrabber: false, content: content)
    }
    
    /// Creates a white sheet container with title and subtitle
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, headerContent: nil, rightButton: nil, showGrabber: false, content: content)
    }
    
    /// Creates a white sheet container with custom header content
    init(title: String, headerContent: @escaping () -> AnyView, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: nil, headerContent: headerContent, rightButton: nil, showGrabber: false, content: content)
    }
    
    /// Creates a white sheet container with only custom header content (no title)
    init(headerContent: @escaping () -> AnyView, @ViewBuilder content: () -> Content) {
        self.init(title: nil, subtitle: nil, headerContent: headerContent, rightButton: nil, showGrabber: false, content: content)
    }
    
    /// Creates a white sheet container with title and right button
    init(title: String, rightButton: @escaping () -> AnyView, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: nil, headerContent: nil, rightButton: rightButton, content: content)
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
            subtitle: "Track your habit progress"
        ) {
            VStack(spacing: 16) {
                Text("Progress content goes here")
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
