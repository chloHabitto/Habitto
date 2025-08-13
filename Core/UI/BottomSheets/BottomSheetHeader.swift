import SwiftUI

struct BottomSheetHeader: View {
    let title: String
    let description: String
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Close button row
            HStack {
                Button(action: onClose) {
                    Image(.iconClose)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.text04)
                        .frame(width: 48, height: 48)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 16)
            
            // Title and description container
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appHeadlineSmallEmphasised)
                    .foregroundColor(.text01)
                Text(description)
                    .font(.appTitleSmall)
                    .foregroundColor(.text05)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    BottomSheetHeader(
        title: "Select Icon",
        description: "Choose an icon for your habit",
        onClose: {}
    )
} 
