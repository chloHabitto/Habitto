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
    HStack(spacing: 12) {
      // Deleted message
      Text("\"\(habitName)\" deleted")
        .font(.appBodyLarge)
        .foregroundColor(.white)
        .lineLimit(1)
      
      Spacer()
      
      // Undo button
      Button(action: {
        onUndo()
      }) {
        Text("Undo")
          .font(.appBodyLargeEmphasised)
          .foregroundColor(.accentColor)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.white.opacity(0.2))
          )
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemGray6).opacity(0.95))
    )
    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    .onAppear {
      // Auto-dismiss after 5 seconds
      DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
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
