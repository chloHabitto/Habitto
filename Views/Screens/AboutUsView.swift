import SwiftUI

struct AboutUsView: View {
    var body: some View {
        VStack {
            Spacer()
            
            Text("About us")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.text01)
            
            Spacer()
        }
        .background(Color.surface2)
        .navigationTitle("About us")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Dismiss the view
                    // This will be handled by the sheet presentation
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AboutUsView()
    }
}
