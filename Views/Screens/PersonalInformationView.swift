import SwiftUI

struct PersonalInformationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Text("Personal Information Screen")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.text04)
                
                Spacer()
            }
            .background(Color.surface2)
            .navigationTitle("Personal Information")
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
    PersonalInformationView()
}
