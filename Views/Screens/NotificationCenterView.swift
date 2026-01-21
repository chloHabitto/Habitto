import SwiftUI

struct NotificationCenterView: View {
  // MARK: Internal
  
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      ZStack {
        Color("appSurface01Variant02")
          .ignoresSafeArea()
        
        // Empty state (for now, always shown)
        VStack(spacing: 16) {
          Spacer()
          
          // Bell icon
          Image("Icon-Bell_Filled")
            .renderingMode(.template)
            .resizable()
            .frame(width: 48, height: 48)
            .foregroundColor(.text04)
          
          // Title
          Text("No notifications")
            .font(.appHeadlineMediumEmphasised)
            .foregroundColor(.text01)
          
          // Subtitle
          Text("You're all caught up!")
            .font(.appBodyMedium)
            .foregroundColor(.text04)
          
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .navigationTitle("Notifications")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
              .foregroundColor(.text01)
          }
        }
      }
    }
  }
}

#Preview {
  NotificationCenterView()
}
