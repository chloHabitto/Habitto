import SwiftUI

struct ThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    // Track original values to detect changes
    @State private var originalTheme: AppTheme
    @State private var selectedTheme: AppTheme
    
    // Toast state
    @State private var showSuccessToast = false
    
    init() {
        let currentTheme = ThemeManager.shared.selectedTheme
        self._originalTheme = State(initialValue: currentTheme)
        self._selectedTheme = State(initialValue: currentTheme)
    }
    
    // Check if any changes were made
    private var hasChanges: Bool {
        return selectedTheme != originalTheme
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content with save button
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Theme Options Section
                            themeOptionsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 100) // Extra bottom padding for save button
                    }
                    
                    // Save button at bottom
                    saveButton
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
            .overlay(
                // Success Toast
                successToast
                    .offset(y: showSuccessToast ? 10 : -190)
                    .opacity(showSuccessToast ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: showSuccessToast)
            )
        }
    }
    
    // MARK: - Theme Options Section
    private var themeOptionsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Color Theme")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
            
            // Options container
            VStack(spacing: 0) {
                ForEach(Array(AppTheme.allCases.enumerated()), id: \.offset) { index, theme in
                    themeOptionRow(theme: theme, isSelected: selectedTheme == theme)
                    
                    if index < AppTheme.allCases.count - 1 {
                        Divider()
                            .background(Color(.systemGray4))
                            .padding(.leading, 20)
                    }
                }
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Theme Option Row
    private func themeOptionRow(theme: AppTheme, isSelected: Bool) -> some View {
        Button(action: {
            selectedTheme = theme
        }) {
            HStack(spacing: 16) {
                // Color preview circle
                Circle()
                    .fill(theme.previewColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name)
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                    
                    Text(theme.description)
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.primary : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        VStack(spacing: 0) {
            // Gradient overlay to fade content behind button
            LinearGradient(
                gradient: Gradient(colors: [Color.surface2.opacity(0), Color.surface2]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            // Button container
            HStack {
                HabittoButton.largeFillPrimary(
                    text: "Save",
                    state: hasChanges ? .default : .disabled,
                    action: saveChanges
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
        }
    }
    
    // MARK: - Success Toast
    private var successToast: some View {
        GeometryReader { geometry in
            VStack {
                HStack(spacing: 12) {
                    // Check icon
                    ZStack {
                        Circle()
                            .fill(Color.green500)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Success text
                    Text("Theme updated successfully")
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surface)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .frame(width: geometry.size.width - 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Save Action
    private func saveChanges() {
        // Update the theme with selected value
        themeManager.selectedTheme = selectedTheme
        
        // Update original value to reflect the new saved state
        originalTheme = selectedTheme
        
        // Show success toast
        showSuccessToast = true
        
        // Hide toast and dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccessToast = false
            
            // Dismiss the view after toast animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
}

#Preview {
    ThemeView()
}
