import SwiftUI

struct BaseBottomSheet<Content: View>: View {
    let title: String
    let description: String
    let onClose: () -> Void
    let content: Content
    let confirmButton: (() -> Void)?
    let confirmButtonTitle: String?
    
    init(
        title: String,
        description: String,
        onClose: @escaping () -> Void,
        confirmButton: (() -> Void)? = nil,
        confirmButtonTitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.onClose = onClose
        self.confirmButton = confirmButton
        self.confirmButtonTitle = confirmButtonTitle
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            BottomSheetHeader(
                title: title,
                description: description,
                onClose: onClose
            )
            
            // Content
            content
            
            // Confirm button if provided
            if let confirmButton = confirmButton, let confirmButtonTitle = confirmButtonTitle {
                VStack(spacing: 0) {
                    Divider()
                    
                    Button(action: confirmButton) {
                        Text(confirmButtonTitle)
                            .font(.appButtonText1)
                            .foregroundColor(.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "1C274C"))
                            .clipShape(Capsule())
                    }
                    .padding(24)
                }
            }
        }
        .background(.surface)
        .presentationDetents([.height(700)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

// MARK: - Convenience Initializers
extension BaseBottomSheet where Content == AnyView {
    init(
        title: String,
        description: String,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> some View
    ) {
        self.init(
            title: title,
            description: description,
            onClose: onClose,
            content: { AnyView(content()) }
        )
    }
}

#Preview {
    BaseBottomSheet(
        title: "Test Sheet",
        description: "This is a test description",
        onClose: {},
        confirmButton: {},
        confirmButtonTitle: "Confirm"
    ) {
        VStack {
            Text("Content goes here")
            Spacer()
        }
        .padding()
    }
} 
