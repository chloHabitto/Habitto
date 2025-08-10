import SwiftUI

struct NotificationView: View {
    @Environment(\.dismiss) private var dismiss
    
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
}

#Preview {
    NotificationView()
} 