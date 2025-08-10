import SwiftUI

struct MoreTabView: View {
    @ObservedObject var state: HomeViewState
    
    var body: some View {
        WhiteSheetContainer(title: "More") {
            ScrollView {
                VStack(spacing: 16) {
                    // Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text02)
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                state.showingStreakView = true
                            }) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    Text("View Streaks")
                                        .foregroundColor(.text02)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.text05)
                                }
                                .padding()
                                .background(.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.outline, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Button(action: {
                                state.showingNotificationView = true
                            }) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.blue)
                                    Text("Notifications")
                                        .foregroundColor(.text02)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.text05)
                                }
                                .padding()
                                .background(.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.outline, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Button(action: {
                                state.cleanupDuplicateHabits()
                            }) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text("Clean Up Duplicates")
                                        .foregroundColor(.text02)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.text05)
                                }
                                .padding()
                                .background(.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.outline, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    // Data Management Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Management")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text02)
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                state.updateAllStreaks()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.green)
                                    Text("Update All Streaks")
                                        .foregroundColor(.text02)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.text05)
                                }
                                .padding()
                                .background(.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.outline, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Button(action: {
                                state.validateAllStreaks()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(.blue)
                                    Text("Validate All Streaks")
                                        .foregroundColor(.text02)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.text05)
                                }
                                .padding()
                                .background(.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.outline, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    // App Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("App Info")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text02)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Version")
                                    .foregroundColor(.text02)
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(.text05)
                            }
                            .padding()
                            .background(.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.outline, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }
}

// MARK: - Setting Item Model
struct SettingItem {
    let title: String
    let value: String?
    let hasChevron: Bool
    
    init(title: String, value: String? = nil, hasChevron: Bool = false) {
        self.title = title
        self.value = value
        self.hasChevron = hasChevron
    }
}

#Preview {
    MoreTabView(state: HomeViewState())
} 
