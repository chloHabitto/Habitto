//
//  MigrationDebugView.swift
//  Habitto
//
//  Debug view for testing Firebase migration
//

import SwiftUI

// MARK: - MigrationDebugView

/// Debug view for monitoring and testing Firebase migration
/// Add this to your app temporarily for easy verification
struct MigrationDebugView: View {
  @StateObject private var viewModel = MigrationDebugViewModel()
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          // Status Card
          StatusCard(viewModel: viewModel)
          
          // Action Buttons
          VStack(spacing: 12) {
            Button(action: {
              Task {
                await viewModel.checkStatus()
              }
            }) {
              Label("Check Migration Status", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: {
              Task {
                await viewModel.compareHabits()
              }
            }) {
              Label("Compare Local vs Firestore", systemImage: "arrow.left.arrow.right")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: {
              Task {
                await viewModel.showFirestoreHabits()
              }
            }) {
              Label("Show Firestore Habits", systemImage: "cloud")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: {
              Task {
                await viewModel.runMigration()
              }
            }) {
              Label("Run Migration Now", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(viewModel.isRunning)
          }
          .padding(.horizontal)
          
          // Console Output
          if !viewModel.consoleOutput.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Console Output")
                .font(.headline)
                .padding(.horizontal)
              
              ScrollView {
                Text(viewModel.consoleOutput)
                  .font(.system(.caption, design: .monospaced))
                  .padding()
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color.black.opacity(0.05))
                  .cornerRadius(8)
              }
              .frame(height: 300)
              .padding(.horizontal)
            }
          }
        }
        .padding(.vertical)
      }
      .navigationTitle("Migration Debug")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - StatusCard

private struct StatusCard: View {
  @ObservedObject var viewModel: MigrationDebugViewModel
  
  var body: some View {
    VStack(spacing: 16) {
      // Title
      HStack {
        Image(systemName: statusIcon)
          .foregroundColor(statusColor)
        Text("Migration Status")
          .font(.headline)
        Spacer()
      }
      
      // Status Info
      if let report = viewModel.report {
        VStack(alignment: .leading, spacing: 12) {
          InfoRow(label: "User ID", value: report.userId)
          InfoRow(label: "Authenticated", value: report.isAuthenticated ? "✅ Yes" : "❌ No")
          
          if let state = report.migrationState {
            InfoRow(label: "State", value: state.status.rawValue.capitalized)
            if let error = state.error {
              InfoRow(label: "Error", value: error, color: .red)
            }
          } else {
            InfoRow(label: "State", value: "Not Started", color: .orange)
          }
          
          Divider()
          
          InfoRow(label: "Local Habits", value: "\(report.localHabitCount)")
          InfoRow(label: "Firestore Habits", value: "\(report.firestoreHabitCount)")
          
          if report.localHabitCount == report.firestoreHabitCount && report.firestoreHabitCount > 0 {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
              Text("Counts match!")
                .font(.caption)
                .foregroundColor(.green)
            }
          }
        }
      } else {
        Text("Tap 'Check Migration Status' to load")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      // Overall Status
      if let report = viewModel.report {
        HStack {
          Spacer()
          Text(report.isComplete ? "✅ COMPLETE" : "⚠️ INCOMPLETE")
            .font(.headline)
            .foregroundColor(report.isComplete ? .green : .orange)
          Spacer()
        }
        .padding(.top, 8)
      }
      
      // Progress
      if viewModel.isRunning {
        ProgressView()
          .progressViewStyle(.circular)
      }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    .padding(.horizontal)
  }
  
  private var statusIcon: String {
    guard let report = viewModel.report else { return "questionmark.circle" }
    return report.isComplete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
  }
  
  private var statusColor: Color {
    guard let report = viewModel.report else { return .gray }
    return report.isComplete ? .green : .orange
  }
}

// MARK: - InfoRow

private struct InfoRow: View {
  let label: String
  let value: String
  var color: Color = .primary
  
  var body: some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
      Spacer()
      Text(value)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(color)
    }
  }
}

// MARK: - MigrationDebugViewModel

@MainActor
class MigrationDebugViewModel: ObservableObject {
  @Published var report: MigrationReport?
  @Published var consoleOutput: String = ""
  @Published var isRunning: Bool = false
  
  func checkStatus() async {
    isRunning = true
    consoleOutput = "🔍 Checking migration status...\n\n"
    
    report = await MigrationVerificationHelper.shared.getMigrationReport()
    
    if let report = report {
      consoleOutput += "✅ Status check complete\n\n"
      consoleOutput += formatReport(report)
    } else {
      consoleOutput += "❌ Failed to get status\n"
    }
    
    isRunning = false
  }
  
  func compareHabits() async {
    isRunning = true
    consoleOutput = "🔍 Comparing habits...\n\n"
    
    // Capture print output
    await MigrationVerificationHelper.shared.compareHabits()
    
    consoleOutput += "✅ Comparison complete (check Xcode console for details)\n"
    
    isRunning = false
  }
  
  func showFirestoreHabits() async {
    isRunning = true
    consoleOutput = "📚 Loading Firestore habits...\n\n"
    
    // Capture print output
    await MigrationVerificationHelper.shared.printFirestoreHabits()
    
    consoleOutput += "✅ Firestore habits loaded (check Xcode console for details)\n"
    
    isRunning = false
  }
  
  func runMigration() async {
    isRunning = true
    consoleOutput = "🚀 Starting migration...\n\n"
    
    await BackfillJob.shared.run()
    
    consoleOutput += "✅ Migration completed\n"
    
    // Refresh status
    await checkStatus()
    
    isRunning = false
  }
  
  private func formatReport(_ report: MigrationReport) -> String {
    var output = ""
    
    output += "👤 User: \(report.userId)\n"
    output += "🔐 Auth: \(report.isAuthenticated ? "✅" : "❌")\n\n"
    
    if let state = report.migrationState {
      output += "📋 State: \(state.status.rawValue)\n"
      if let error = state.error {
        output += "❌ Error: \(error)\n"
      }
    } else {
      output += "📋 State: Not Started\n"
    }
    
    output += "\n📊 Habits:\n"
    output += "   Local: \(report.localHabitCount)\n"
    output += "   Firestore: \(report.firestoreHabitCount)\n"
    
    if report.localHabitCount == report.firestoreHabitCount && report.firestoreHabitCount > 0 {
      output += "   ✅ Match!\n"
    } else if report.firestoreHabitCount < report.localHabitCount {
      output += "   ⚠️ Partial migration\n"
    }
    
    output += "\n🎯 Status: \(report.isComplete ? "✅ COMPLETE" : "⚠️ INCOMPLETE")\n"
    
    if !report.errors.isEmpty {
      output += "\n❌ Issues:\n"
      for error in report.errors {
        output += "   • \(error)\n"
      }
    }
    
    return output
  }
}

// MARK: - Preview

#Preview {
  MigrationDebugView()
}

