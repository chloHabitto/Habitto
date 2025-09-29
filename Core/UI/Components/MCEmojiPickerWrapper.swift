import SwiftUI
import MCEmojiPicker

// MARK: - SwiftUI Wrapper for MCEmojiPicker
struct MCEmojiPickerWrapper: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    let onEmojiSelected: (String) -> Void
    
    var body: some View {
        MCEmojiPickerRepresentableController(
            isPresented: $isPresented,
            selectedEmoji: $selectedEmoji,
            arrowDirection: .up,
            customHeight: 400.0,
            horizontalInset: .zero,
            isDismissAfterChoosing: true,
            selectedEmojiCategoryTintColor: UIColor.systemBlue,
            feedBackGeneratorStyle: .light
        )
    }
}

// MARK: - Convenience Extension for Easy Usage
extension View {
    func mcEmojiPicker(
        isPresented: Binding<Bool>,
        selectedEmoji: Binding<String>,
        onEmojiSelected: @escaping (String) -> Void = { _ in }
    ) -> some View {
        self.background(
            MCEmojiPickerWrapper(
                selectedEmoji: selectedEmoji,
                isPresented: isPresented,
                onEmojiSelected: onEmojiSelected
            )
        )
    }
}

#Preview {
    @Previewable @State var selectedEmoji = "😀"
    @Previewable @State var isPresented = false
    
    return VStack {
        Text("Selected: \(selectedEmoji)")
            .font(.title)
        
        Button("Select Emoji") {
            isPresented = true
        }
        .mcEmojiPicker(
            isPresented: $isPresented,
            selectedEmoji: $selectedEmoji
        )
    }
    .padding()
}
