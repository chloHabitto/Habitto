import SwiftUI

struct WhiteSheetContainer<Content: View>: View {
    let title: String?
    let subtitle: String?
    let headerContent: (() -> AnyView)?
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        headerContent: (() -> AnyView)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerContent = headerContent
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section with title
            headerSection
            
            // Content area
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .roundedTopBackground()
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            if let title = title {
                HStack {
                    Text(title)
                        .font(.appTitleLargeEmphasised)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
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
        self.init(title: title, subtitle: nil, headerContent: nil, content: content)
    }
    
    /// Creates a white sheet container with title and subtitle
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, headerContent: nil, content: content)
    }
    
    /// Creates a white sheet container with custom header content
    init(title: String, headerContent: @escaping () -> AnyView, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: nil, headerContent: headerContent, content: content)
    }
    
    /// Creates a white sheet container with only custom header content (no title)
    init(headerContent: @escaping () -> AnyView, @ViewBuilder content: () -> Content) {
        self.init(title: nil, subtitle: nil, headerContent: headerContent, content: content)
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