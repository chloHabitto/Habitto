import SwiftUI

// MARK: - BackupTestingView

/// Testing interface for backup system functionality
struct BackupTestingView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Header
        headerSection

        // Test Controls
        testControlsSection

        // Results
        if !testingSuite.testResults.isEmpty {
          testResultsSection
        } else {
          emptyStateSection
        }

        Spacer()
      }
      .navigationTitle("Backup Testing")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }

  // MARK: Private

  @StateObject private var testingSuite = BackupTestingSuite.shared
  @Environment(\.dismiss) private var dismiss

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 16) {
      Image(systemName: "testtube.2")
        .font(.system(size: 48))
        .foregroundColor(.blue)

      Text("Backup System Testing")
        .font(.title2)
        .fontWeight(.semibold)

      Text(
        "Comprehensive testing suite for backup functionality, data integrity, and system reliability.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
    .padding(.top, 20)
    .padding(.bottom, 30)
  }

  // MARK: - Test Controls Section

  private var testControlsSection: some View {
    VStack(spacing: 16) {
      Button(action: {
        Task {
          await testingSuite.runAllTests()
        }
      }) {
        HStack {
          if testingSuite.isRunningTests {
            ProgressView()
              .scaleEffect(0.8)
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
          } else {
            Image(systemName: "play.fill")
          }

          Text(testingSuite.isRunningTests ? "Running Tests..." : "Run All Tests")
            .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
          LinearGradient(
            colors: [.blue, .blue.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing))
        .cornerRadius(12)
      }
      .disabled(testingSuite.isRunningTests)
      .padding(.horizontal, 20)

      if !testingSuite.testResults.isEmpty {
        HStack(spacing: 16) {
          Button("Clear Results") {
            testingSuite.clearTestResults()
          }
          .foregroundColor(.red)

          Spacer()

          Text(testingSuite.getTestSummary())
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
      }
    }
  }

  // MARK: - Empty State Section

  private var emptyStateSection: some View {
    VStack(spacing: 20) {
      Image(systemName: "checkmark.circle")
        .font(.system(size: 64))
        .foregroundColor(.green.opacity(0.6))

      Text("No Tests Run Yet")
        .font(.title3)
        .fontWeight(.medium)

      Text("Tap 'Run All Tests' to begin comprehensive testing of the backup system.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .padding(.top, 60)
  }

  // MARK: - Test Results Section

  private var testResultsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Test Results")
        .font(.headline)
        .padding(.horizontal, 20)

      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(testingSuite.testResults) { result in
            TestResultRow(result: result)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
    }
  }
}

// MARK: - TestResultRow

struct TestResultRow: View {
  let result: BackupTestResult

  var body: some View {
    HStack(spacing: 16) {
      // Status Icon
      Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.title2)
        .foregroundColor(result.success ? .green : .red)

      // Test Info
      VStack(alignment: .leading, spacing: 4) {
        Text(result.name)
          .font(.body)
          .fontWeight(.medium)

        HStack {
          Text(result.formattedDuration)
            .font(.caption)
            .foregroundColor(.secondary)

          if !result.success, let error = result.error {
            Text("• \(error)")
              .font(.caption)
              .foregroundColor(.red)
              .lineLimit(2)
          }
        }
      }

      Spacer()
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
              lineWidth: 1)))
  }
}

// MARK: - BackupTestingView_Previews

struct BackupTestingView_Previews: PreviewProvider {
  static var previews: some View {
    BackupTestingView()
  }
}
