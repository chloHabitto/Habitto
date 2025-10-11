import SwiftUI

struct NotificationView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack {
        Spacer()

        Text("Notifications")
          .font(.appHeadlineMediumEmphasised)
          .foregroundColor(.text01)

        Text("No notifications yet")
          .font(.appBodyMedium)
          .foregroundColor(.text04)
          .padding(.top, 8)

        Spacer()
      }
      .navigationTitle("Notifications")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
}

#Preview {
  NotificationView()
}
