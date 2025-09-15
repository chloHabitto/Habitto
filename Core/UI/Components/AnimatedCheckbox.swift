import SwiftUI

struct AnimatedCheckbox: View {
    let isChecked: Bool
    let accentColor: Color
    let isAnimating: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isChecked ? accentColor : Color.white)
                    .frame(width: 30, height: 30)
                    .animation(.easeInOut(duration: 0.6), value: isChecked)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1), value: isAnimating)
                
                // Stroke circle
                Circle()
                    .stroke(isChecked ? Color.white : Color.outline3, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6), value: isChecked)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1), value: isAnimating)
                
                // Checkmark
                AnimatedCheckmarkShape()
                    .trim(from: 0, to: isChecked ? 1 : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 16, height: 12)
                    .opacity(isHovered && !isChecked ? 0.3 : (isChecked ? 1 : 0))
                    .animation(.easeInOut(duration: 0.6), value: isChecked)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AnimatedCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Create checkmark path centered in the frame
        let point1 = CGPoint(x: rect.width * 0.25, y: rect.height * 0.5)
        let point2 = CGPoint(x: rect.width * 0.45, y: rect.height * 0.75)
        let point3 = CGPoint(x: rect.width * 0.85, y: rect.height * 0.25)
        
        path.move(to: point1)
        path.addLine(to: point2)
        path.addLine(to: point3)
        
        return path
    }
}

// Preview for testing
#Preview {
    VStack(spacing: 20) {
        Text("Animated Checkbox Examples")
            .font(.title2)
        
        HStack(spacing: 30) {
            // Unchecked state
            AnimatedCheckbox(
                isChecked: false,
                accentColor: .green,
                isAnimating: false,
                action: {}
            )
            
            // Checked state
            AnimatedCheckbox(
                isChecked: true,
                accentColor: .blue,
                isAnimating: false,
                action: {}
            )
            
            // Animating state
            AnimatedCheckbox(
                isChecked: true,
                accentColor: .purple,
                isAnimating: true,
                action: {}
            )
        }
        
        Text("Unchecked, Checked, Animating")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
