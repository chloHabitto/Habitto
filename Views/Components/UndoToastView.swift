import SwiftUI

// MARK: - UndoToastView

/// A toast notification that appears after habit deletion with an undo button
struct UndoToastView: View {
  // MARK: Lifecycle
  
  init(habitName: String, onUndo: @escaping () -> Void, onDismiss: @escaping () -> Void) {
    self.habitName = habitName
    self.onUndo = onUndo
    self.onDismiss = onDismiss
  }
  
  // MARK: Internal
  
  let habitName: String
  let onUndo: () -> Void
  let onDismiss: () -> Void
  
  var body: some View {
    HStack(spacing: 0) {
      // Deleted message with its own padding
      Text("\"\(habitName)\" deleted")
        .font(.appBodyLarge)
        .foregroundColor(.appText01Inverse)
        .lineLimit(1)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
      
      Spacer(minLength: 0)
      
      // Undo button with outer padding as part of touch area
      Button(action: {
        onUndo()
      }) {
        Text("Undo")
          .font(.appBodyLargeEmphasised)
          .foregroundColor(.appText01Inverse)
          .padding(.horizontal, 10)
          .frame(height: 32)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.appSurface10)
          )
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.appInverseSurface80)
    )
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    .onAppear {
      // Auto-dismiss after 3.5 seconds
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
        onDismiss()
      }
    }
  }
}

// MARK: - Preview

#Preview {
  ZStack {
    Color.gray.ignoresSafeArea()
    
    VStack {
      Spacer()
      
      UndoToastView(
        habitName: "Morning Yoga",
        onUndo: {
          print("Undo tapped")
        },
        onDismiss: {
          print("Toast dismissed")
        }
      )
      .padding(.horizontal, 16)
      .padding(.bottom, 100) // Above tab bar
    }
  }
}
