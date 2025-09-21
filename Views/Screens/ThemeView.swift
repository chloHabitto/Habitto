import SwiftUI

struct ThemeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Coming Soon Section
                        comingSoonSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.surface2)
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.text01)
                    }
                }
            }
        }
    }
    
    // MARK: - Coming Soon Section
    private var comingSoonSection: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.text04)
            
            // Title
            Text("Theme Options")
                .font(.appTitleLargeEmphasised)
                .foregroundColor(.text01)
                .multilineTextAlignment(.center)
            
            // Description
            Text("Theme customization options will be available in a future update.")
                .font(.appBodyMedium)
                .foregroundColor(.text03)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    ThemeView()
}
