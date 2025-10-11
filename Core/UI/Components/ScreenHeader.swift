import SwiftUI

struct ScreenHeader: View {
    let title: String
    let description: String?
    let onClose: () -> Void
    
    init(title: String, description: String? = nil, onClose: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top row with close button
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Title section - left aligned
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.appHeadlineSmallEmphasised)
                    .foregroundColor(.text01)
                    .accessibilityAddTraits(.isHeader)

                if let description = description {
                    Text(description)
                        .font(.appTitleSmall)
                        .foregroundColor(.text05)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .padding(.top, 24)
    }
}

#Preview {
    VStack {
        ScreenHeader(
            title: "Sample Title",
            description: "This is a sample description for the header component."
        ) {
            print("Close tapped")
        }
        
        Spacer()
    }
    .background(Color.surface2)
}
