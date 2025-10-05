import SwiftUI

// MARK: - Emoji Keyboard Bottom Sheet
struct EmojiKeyboardBottomSheet: View {
    @Binding var selectedEmoji: String
    let onClose: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var hasAppeared = false
    
    var body: some View {
        BaseBottomSheet(
            title: "Choose Icon",
            description: "Select an emoji for your habit",
            onClose: onClose
        ) {
            VStack(spacing: 20) {
                // Current selection display
                if !selectedEmoji.isEmpty {
                    VStack(spacing: 12) {
                        Text("Current Selection")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.surface2)
                                .frame(width: 80, height: 80)
                            
                            Text(selectedEmoji)
                                .font(.system(size: 40))
                        }
                    }
                }
                
                // Hidden emoji text field that forces keyboard to appear
                EmojiTextField(
                    selectedEmoji: $selectedEmoji,
                    onEmojiSelected: { emoji in
                        selectedEmoji = emoji
                    },
                    isFocused: isTextFieldFocused,
                    onFocusChange: { focused in
                        isTextFieldFocused = focused
                    }
                )
                .opacity(0)
                .frame(height: 0)
                .allowsHitTesting(false)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                
                // Force keyboard to appear immediately when sheet opens
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
                
                // Multiple aggressive attempts to ensure keyboard appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isTextFieldFocused = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isTextFieldFocused = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
                
                // Final attempt after sheet animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isTextFieldFocused = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var selectedEmoji = "🏃‍♂️"
    
    return VStack {
        Text("Selected: \(selectedEmoji)")
            .font(.title)
        
        Button("Open Emoji Picker") {
            // This would be handled by the parent view
        }
    }
    .sheet(isPresented: .constant(true)) {
        EmojiKeyboardBottomSheet(
            selectedEmoji: $selectedEmoji,
            onClose: {}
        )
    }
}
