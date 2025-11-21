import SwiftUI

struct SecurityView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authManager: AuthenticationManager

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Scrollable content
        ScrollView {
          VStack(spacing: 24) {
            // Description text
            Text("Manage your account settings and security")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .padding(.top, 8)

            // Account Options - disabled (empty placeholder)
            VStack(spacing: 0) {
              // All account options disabled
            }
            .background(Color.surface)
            .cornerRadius(16)
            .padding(.horizontal, 20)
          }
          .padding(.horizontal, 0)
          .padding(.top, 0)
          .padding(.bottom, 20)
        }

      }
      .background(Color.surface2)
      .navigationTitle("Account")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }
}

#Preview {
  SecurityView()
}
