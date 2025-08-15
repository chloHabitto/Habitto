import SwiftUI

struct DataPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Text("Data & Privacy Screen")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.text04)
                
                Spacer()
            }
            .background(Color.surface2)
            .navigationTitle("Data & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    DataPrivacyView()
}
