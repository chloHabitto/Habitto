import SwiftUI

// Extension to add specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Custom modifier for white background with rounded top corners
struct RoundedTopBackground: ViewModifier {
    let radius: CGFloat
    
    init(radius: CGFloat = 20) {
        self.radius = radius
    }
    
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedCorner(radius: radius, corners: [.topLeft, .topRight]))
    }
}

// Extension to make it easy to use
extension View {
    func roundedTopBackground(radius: CGFloat = 20) -> some View {
        self.modifier(RoundedTopBackground(radius: radius))
    }
} 
