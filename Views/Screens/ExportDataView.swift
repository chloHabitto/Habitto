import Foundation
import SwiftUI

// MARK: - ExportDataView

struct ExportDataView: View {
  // MARK: Internal

  enum DataType: String, CaseIterable, Codable {
    case habits
    case progress
    case profile
    case settings
    case analytics

    // MARK: Internal

    var displayName: String {
      switch self {
      case .habits: "Habits & Progress"
      case .progress: "Completion History"
      case .profile: "User Profile"
      case .settings: "App Settings"
      case .analytics: "Analytics Data"
      }
    }

    var icon: String {
      switch self {
      case .habits: "Icon-Fire_Filled"
      case .progress: "Icon-Chart_Filled"
      case .profile: "Icon-User_Filled"
      case .settings: "Icon-Settings_Filled"
      case .analytics: "Icon-Analytics_Filled"
      }
    }

    var estimatedSize: String {
      switch self {
      case .habits: "Dynamic"
      case .progress: "Dynamic"
      case .profile: "1-5 KB"
      case .settings: "1-2 KB"
      case .analytics: "Dynamic"
      }
    }

    var description: String {
      switch self {
      case .habits: "Your habits, goals, and current progress"
      case .progress: "Historical completion records and streaks"
      case .profile: "Your name, email, and account information"
      case .settings: "App preferences and configuration"
      case .analytics: "Usage statistics and performance data"
      }
    }
  }

  enum DateRange: String, CaseIterable, Codable {
    case last30Days = "30days"
    case last6Months = "6months"
    case lastYear = "year"
    case allTime = "all"

    // MARK: Internal

    var displayName: String {
      switch self {
      case .last30Days: "Last 30 days"
      case .last6Months: "Last 6 months"
      case .lastYear: "Last year"
      case .allTime: "All time"
      }
    }

    var description: String {
      switch self {
      case .last30Days: "Export data from the past month"
      case .last6Months: "Export data from the past 6 months"
      case .lastYear: "Export data from the past year"
      case .allTime: "Export all your data"
      }
    }
  }

  enum ExportFormat: String, CaseIterable, Codable {
    case json
    case csv
    case pdf

    // MARK: Internal

    var displayName: String {
      switch self {
      case .json: "JSON"
      case .csv: "CSV"
      case .pdf: "PDF Report"
      }
    }

    var description: String {
      switch self {
      case .json: "Machine-readable format (recommended)"
      case .csv: "Spreadsheet format"
      case .pdf: "Human-readable report"
      }
    }

    var icon: String {
      switch self {
      case .json: "Icon-Code_Filled"
      case .csv: "Icon-Table_Filled"
      case .pdf: "Icon-Document_Filled"
      }
    }
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Scrollable content
        ScrollView {
          VStack(spacing: 24) {
            // Description text
            Text("Download your personal data in your preferred format")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .padding(.top, 8)

            // Selection Options
            VStack(spacing: 16) {
              // Data Types - Multi-select dropdown
              VStack(alignment: .leading, spacing: 8) {
                Text("Data Types")
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.text01)

                Menu {
                  ForEach(DataType.allCases, id: \.self) { dataType in
                    Button(action: {
                      if selectedDataTypes.contains(dataType) {
                        selectedDataTypes.remove(dataType)
                      } else {
                        selectedDataTypes.insert(dataType)
                      }
                    }) {
                      HStack {
                        Text(dataType.displayName)
                        Spacer()
                        if selectedDataTypes.contains(dataType) {
                          Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                        }
                      }
                    }
                  }
                } label: {
                  HStack {
                    Text(selectedDataTypes.isEmpty
                      ? "Select data types..."
                      : "\(selectedDataTypes.count) selected")
                      .font(.system(size: 16, weight: .regular))
                      .foregroundColor(selectedDataTypes.isEmpty ? .text03 : .text01)

                    Spacer()

                    Image(systemName: "chevron.down")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.text03)
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.grey200, lineWidth: 1))
                }
              }

              // Date Range - Single select dropdown
              VStack(alignment: .leading, spacing: 8) {
                Text("Date Range")
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.text01)

                Menu {
                  ForEach(DateRange.allCases, id: \.self) { range in
                    Button(action: {
                      selectedDateRange = range
                    }) {
                      HStack {
                        Text(range.displayName)
                        Spacer()
                        if selectedDateRange == range {
                          Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                        }
                      }
                    }
                  }
                } label: {
                  HStack {
                    Text(selectedDateRange.displayName)
                      .font(.system(size: 16, weight: .regular))
                      .foregroundColor(.text01)

                    Spacer()

                    Image(systemName: "chevron.down")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.text03)
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.grey200, lineWidth: 1))
                }
              }

              // Export Format - Single select dropdown
              VStack(alignment: .leading, spacing: 8) {
                Text("Export Format")
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.text01)

                Menu {
                  ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(action: {
                      selectedFormat = format
                    }) {
                      HStack {
                        Text(format.displayName)
                        Spacer()
                        if selectedFormat == format {
                          Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                        }
                      }
                    }
                  }
                } label: {
                  HStack {
                    Text(selectedFormat.displayName)
                      .font(.system(size: 16, weight: .regular))
                      .foregroundColor(.text01)

                    Spacer()

                    Image(systemName: "chevron.down")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.text03)
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.grey200, lineWidth: 1))
                }
              }
            }
            .padding(.horizontal, 20)

            // Export Summary
            Button(action: {
              showingPreview = true
            }) {
              VStack(spacing: 16) {
                HStack {
                  Image("Icon-Info_Filled")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.navy200)

                  VStack(alignment: .leading, spacing: 4) {
                    Text("Export Summary")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.text01)

                    Text(
                      "\(selectedDataTypes.count) data types • \(selectedDateRange.displayName) • \(selectedFormat.displayName)")
                      .font(.system(size: 14, weight: .regular))
                      .foregroundColor(.text03)

                    Text("Estimated size: \(estimatedTotalSize)")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.navy200)
                  }

                  Spacer()

                  Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.text03)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color("appSurface02Variant"))
                .cornerRadius(24)
              }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)

            // Export Button
            Button(action: {
              Task {
                await performExport()
              }
            }) {
              Text(isExporting ? "Exporting..." : "Export Data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .cornerRadius(28)
            }
            .disabled(isExporting || selectedDataTypes.isEmpty)
            .padding(.horizontal, 20)

            // Export Information
            VStack(spacing: 8) {
              HStack {
                Image(systemName: "info.circle")
                  .font(.system(size: 14))
                  .foregroundColor(.navy200)

                Text("File will be saved to Documents/Habitto Exports/")
                  .font(.system(size: 12, weight: .regular))
                  .foregroundColor(.text03)

                Spacer()
              }

              HStack {
                Image(systemName: "square.and.arrow.up")
                  .font(.system(size: 14))
                  .foregroundColor(.navy200)

                Text("You'll be able to share the file after export")
                  .font(.system(size: 12, weight: .regular))
                  .foregroundColor(.text03)

                Spacer()
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
          }
        }
        .background(Color("appSurface01Variant02"))
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Export Data")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .sheet(isPresented: $showingExportComplete) {
      if let fileURL = exportFileURL {
        ExportCompleteView(fileURL: fileURL) {
          dismiss()
        }
      }
    }
    .sheet(isPresented: $showingPreview) {
      ExportPreviewView(
        selectedDataTypes: selectedDataTypes,
        selectedDateRange: selectedDateRange,
        selectedFormat: selectedFormat,
        estimatedSize: estimatedTotalSize)
    }
    .alert("Export Error", isPresented: .constant(exportError != nil)) {
      Button("OK") {
        exportError = nil
      }
    } message: {
      if let error = exportError {
        Text(error)
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @StateObject private var backupManager = BackupManager.shared

  @State private var selectedDataTypes: Set<DataType> = [.habits, .progress, .profile, .settings]
  @State private var selectedDateRange = DateRange.allTime
  @State private var selectedFormat = ExportFormat.json
  @State private var isExporting = false
  @State private var showingExportComplete = false
  @State private var exportFileURL: URL?
  @State private var exportError: String?
  @State private var showingPreview = false

  private var estimatedTotalSize: String {
    // Calculate actual estimated size based on selected data types and date range
    let estimatedSize = calculateEstimatedExportSize()

    if estimatedSize >= 1024 {
      return String(format: "%.1f MB", estimatedSize / 1024)
    } else {
      return String(format: "%.0f KB", estimatedSize)
    }
  }

  private func calculateEstimatedExportSize() -> Double {
    // Base size estimates for different data types (in KB)
    let baseSizes: [DataType: Double] = [
      .habits: 2.0, // Per habit
      .progress: 0.1, // Per completion record
      .profile: 0.5, // User profile data
      .settings: 1.0, // App settings
      .analytics: 0.05 // Per usage record
    ]

    var totalSize: Double = 0

    // Estimate based on data type selection
    for dataType in selectedDataTypes {
      if let baseSize = baseSizes[dataType] {
        // Apply date range multiplier
        let rangeMultiplier = getDateRangeMultiplier()
        totalSize += baseSize * rangeMultiplier
      }
    }

    // Format-specific size adjustments
    switch selectedFormat {
    case .json:
      totalSize *= 1.2 // JSON is slightly larger due to formatting
    case .csv:
      totalSize *= 0.8 // CSV is more compact
    case .pdf:
      totalSize *= 1.5 // PDF includes formatting overhead
    }

    return max(totalSize, 1.0) // Minimum 1 KB
  }

  private func getDateRangeMultiplier() -> Double {
    switch selectedDateRange {
    case .last30Days:
      0.1 // ~10% of all data
    case .last6Months:
      0.3 // ~30% of all data
    case .lastYear:
      0.6 // ~60% of all data
    case .allTime:
      1.0 // All data
    }
  }

  private func performExport() async {
    isExporting = true

    do {
      // Validate export options
      try validateExportOptions()

      // Create export data based on selected options
      let exportData = try await createExportData()

      // Validate export data
      try validateExportData(exportData)

      // Generate file URL in organized directory structure
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let exportsDirectory = documentsPath.appendingPathComponent("Habitto Exports")

      // Create exports directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: exportsDirectory,
        withIntermediateDirectories: true,
        attributes: nil)

      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
      let fileName = "habitto_export_\(dateFormatter.string(from: Date())).\(selectedFormat.rawValue)"
      let fileURL = exportsDirectory.appendingPathComponent(fileName)

      // Write data to file
      try writeExportData(exportData, to: fileURL)

      // Verify file was written successfully
      try verifyExportedFile(fileURL)

      // Update UI on main thread
      await MainActor.run {
        exportFileURL = fileURL
        showingExportComplete = true
        isExporting = false
      }

    } catch {
      await MainActor.run {
        exportError = getErrorMessage(for: error)
        isExporting = false
      }
    }
  }

  private func validateExportOptions() throws {
    // Check if any data types are selected
    guard !selectedDataTypes.isEmpty else {
      throw ExportError.noDataTypesSelected
    }

    // Check if export format is valid
    guard ExportFormat.allCases.contains(selectedFormat) else {
      throw ExportError.invalidFormat
    }

    // Check if date range is valid
    guard DateRange.allCases.contains(selectedDateRange) else {
      throw ExportError.invalidDateRange
    }
  }

  private func validateExportData(_ data: Data) throws {
    // Check if data is not empty
    guard !data.isEmpty else {
      throw ExportError.emptyExportData
    }

    // Check if data size is reasonable (not too large)
    let maxSize = 100 * 1024 * 1024 // 100MB limit
    guard data.count < maxSize else {
      throw ExportError.exportTooLarge
    }
  }

  private func verifyExportedFile(_ fileURL: URL) throws {
    // Check if file exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ExportError.fileNotCreated
    }

    // Check file size
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
      throw ExportError.invalidFileSize
    }
  }

  private func getErrorMessage(for error: Error) -> String {
    if let exportError = error as? ExportError {
      exportError.localizedDescription
    } else if let backupError = error as? BackupError {
      "Export failed: \(backupError.localizedDescription)"
    } else {
      "Export failed: \(error.localizedDescription)"
    }
  }

  private func createExportData() async throws -> Data {
    // Get actual user data from BackupManager
    let backupData = try await backupManager.createBackupData()

    // Filter data based on selected options
    let filteredData = try await filterBackupData(backupData)

    // Generate data in selected format
    switch selectedFormat {
    case .json:
      return try await createJSONExport(filteredData)
    case .csv:
      return try await createCSVExport(filteredData)
    case .pdf:
      return try await createPDFExport(filteredData)
    }
  }

  private func writeExportData(_ data: Data, to url: URL) throws {
    try data.write(to: url)
  }

  // MARK: - Data Filtering

  private func filterBackupData(_ backupData: Data) async throws -> BackupData {
    let backup = try JSONDecoder().decode(BackupData.self, from: backupData)

    // Apply date range filtering
    let filteredBackup = try applyDateRangeFilter(backup)

    // Apply data type filtering
    let finalBackup = applyDataTypeFilter(filteredBackup)

    return finalBackup
  }

  private func applyDateRangeFilter(_ backup: BackupData) throws -> BackupData {
    let calendar = Calendar.current
    let today = Date()

    let startDate: Date
    switch selectedDateRange {
    case .last30Days:
      startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
    case .last6Months:
      startDate = calendar.date(byAdding: .month, value: -6, to: today) ?? today
    case .lastYear:
      startDate = calendar.date(byAdding: .year, value: -1, to: today) ?? today
    case .allTime:
      return backup // No filtering needed
    }

    // Filter completions by date range
    let filteredCompletions = backup.completions.filter { completion in
      completion.date >= startDate
    }

    // Filter difficulties by date range
    let filteredDifficulties = backup.difficulties.filter { difficulty in
      difficulty.date >= startDate
    }

    // Filter usage records by date range
    let filteredUsageRecords = backup.usageRecords.filter { usage in
      usage.createdAt >= startDate
    }

    // Filter habit notes by date range
    let filteredHabitNotes = backup.habitNotes.filter { note in
      note.createdAt >= startDate
    }

    // Filter habits that were created or updated in the date range
    let filteredHabits = backup.habits.filter { habit in
      habit.createdAt >= startDate || habit.updatedAt >= startDate
    }

    return BackupData(
      metadata: backup.metadata,
      habits: filteredHabits,
      completions: filteredCompletions,
      difficulties: filteredDifficulties,
      usageRecords: filteredUsageRecords,
      habitNotes: filteredHabitNotes,
      userSettings: backup.userSettings,
      legacyData: backup.legacyData,
      habitsLegacy: backup.habitsLegacy?.filter { habit in
        habit.startDate >= startDate
      })
  }

  private func applyDataTypeFilter(_ backup: BackupData) -> BackupData {
    var filteredHabits: [BackupHabitData] = []
    var filteredCompletions: [BackupCompletionRecord] = []
    var filteredDifficulties: [BackupDifficultyRecord] = []
    var filteredUsageRecords: [BackupUsageRecord] = []
    var filteredHabitNotes: [BackupHabitNote] = []
    var filteredUserSettings = BackupUserSettings()
    var filteredLegacyData: LegacyBackupData? = nil

    // Filter based on selected data types
    if selectedDataTypes.contains(.habits) {
      filteredHabits = backup.habits
      filteredCompletions = backup.completions
      filteredDifficulties = backup.difficulties
      filteredUsageRecords = backup.usageRecords
      filteredHabitNotes = backup.habitNotes
    }

    if selectedDataTypes.contains(.progress) {
      // Progress data is already included with habits
      if filteredCompletions.isEmpty {
        filteredCompletions = backup.completions
      }
      if filteredDifficulties.isEmpty {
        filteredDifficulties = backup.difficulties
      }
    }

    if selectedDataTypes.contains(.profile) {
      filteredUserSettings = backup.userSettings
    }

    if selectedDataTypes.contains(.settings) {
      if filteredUserSettings.notificationSettings.isEmpty {
        filteredUserSettings = backup.userSettings
      }
    }

    if selectedDataTypes.contains(.analytics) {
      filteredLegacyData = backup.legacyData
      if filteredUsageRecords.isEmpty {
        filteredUsageRecords = backup.usageRecords
      }
    }

    return BackupData(
      metadata: backup.metadata,
      habits: filteredHabits,
      completions: filteredCompletions,
      difficulties: filteredDifficulties,
      usageRecords: filteredUsageRecords,
      habitNotes: filteredHabitNotes,
      userSettings: filteredUserSettings,
      legacyData: filteredLegacyData,
      habitsLegacy: backup.habitsLegacy)
  }

  // MARK: - Export Format Generators

  private func createJSONExport(_ backup: BackupData) async throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted

    return try encoder.encode(backup)
  }

  private func createCSVExport(_ backup: BackupData) async throws -> Data {
    var csvContent = ""

    // Add metadata header
    csvContent += "Export Date,App Version,Device Model,OS Version,User ID\n"
    csvContent += "\(backup.metadata.createdDate),\(backup.metadata.appVersion),\(backup.metadata.deviceModel),\(backup.metadata.osVersion),\(backup.metadata.userId)\n\n"

    // Export habits
    if selectedDataTypes.contains(.habits) {
      csvContent += "=== HABITS ===\n"
      csvContent += "ID,Name,Description,Goal,Schedule,Type,Start Date,End Date,Streak,Is Completed\n"

      for habit in backup.habits {
        let escapedName = habit.name.replacingOccurrences(of: ",", with: ";")
        let escapedDescription = (habit.habitDescription ?? "").replacingOccurrences(
          of: ",",
          with: ";")
        let escapedGoal = habit.goal.replacingOccurrences(of: ",", with: ";")
        let escapedSchedule = habit.schedule.replacingOccurrences(of: ",", with: ";")

        csvContent += "\(habit.id),\(escapedName),\(escapedDescription),\(escapedGoal),\(escapedSchedule),\(habit.habitType),\(habit.startDate),\(habit.endDate?.description ?? ""),\(habit.streak),\(habit.isCompleted)\n"
      }
      csvContent += "\n"
    }

    // Export completions
    if selectedDataTypes.contains(.progress) {
      csvContent += "=== COMPLETION HISTORY ===\n"
      csvContent += "Habit ID,Date,Is Completed,Created At\n"

      for completion in backup.completions {
        csvContent += "\(completion.habitId ?? ""),\(completion.date),\(completion.isCompleted),\(completion.createdAt)\n"
      }
      csvContent += "\n"
    }

    // Export difficulties
    if selectedDataTypes.contains(.progress) {
      csvContent += "=== DIFFICULTY TRACKING ===\n"
      csvContent += "Habit ID,Date,Difficulty,Created At\n"

      for difficulty in backup.difficulties {
        csvContent += "\(difficulty.habitId ?? ""),\(difficulty.date),\(difficulty.difficulty),\(difficulty.createdAt)\n"
      }
      csvContent += "\n"
    }

    // Export usage records
    if selectedDataTypes.contains(.analytics) {
      csvContent += "=== USAGE ANALYTICS ===\n"
      csvContent += "Habit ID,Key,Value,Created At\n"

      for usage in backup.usageRecords {
        csvContent += "\(usage.habitId ?? ""),\(usage.key),\(usage.value),\(usage.createdAt)\n"
      }
      csvContent += "\n"
    }

    // Export notes
    if selectedDataTypes.contains(.habits) {
      csvContent += "=== HABIT NOTES ===\n"
      csvContent += "Habit ID,Content,Created At,Updated At\n"

      for note in backup.habitNotes {
        let escapedContent = note.content.replacingOccurrences(of: ",", with: ";")
        csvContent += "\(note.habitId ?? ""),\(escapedContent),\(note.createdAt),\(note.updatedAt)\n"
      }
      csvContent += "\n"
    }

    // Export user settings
    if selectedDataTypes.contains(.settings) {
      csvContent += "=== USER SETTINGS ===\n"
      csvContent += "Category,Key,Value\n"

      for (key, value) in backup.userSettings.notificationSettings {
        csvContent += "Notification,\(key),\(value)\n"
      }

      for (key, value) in backup.userSettings.themeSettings {
        csvContent += "Theme,\(key),\(value)\n"
      }

      for (key, value) in backup.userSettings.privacySettings {
        csvContent += "Privacy,\(key),\(value)\n"
      }

      for (key, value) in backup.userSettings.backupSettings {
        csvContent += "Backup,\(key),\(value)\n"
      }

      for (key, value) in backup.userSettings.appSettings {
        csvContent += "App,\(key),\(value)\n"
      }
    }

    return csvContent.data(using: .utf8) ?? Data()
  }

  private func createPDFExport(_ backup: BackupData) async throws -> Data {
    // For PDF generation, we'll create a simple text-based report
    // In a production app, you might want to use a proper PDF library like PDFKit

    var reportContent = """
    HABITTO DATA EXPORT REPORT
    =========================

    Export Date: \(backup.metadata.createdDate)
    App Version: \(backup.metadata.appVersion)
    Device: \(backup.metadata.deviceModel)
    OS Version: \(backup.metadata.osVersion)
    User ID: \(backup.metadata.userId)

    """

    // Add habits summary
    if selectedDataTypes.contains(.habits) {
      reportContent += "\n\nHABITS SUMMARY\n"
      reportContent += "==============\n"
      reportContent += "Total Habits: \(backup.habits.count)\n\n"

      for (index, habit) in backup.habits.enumerated() {
        reportContent += "\(index + 1). \(habit.name)\n"
        reportContent += "   Goal: \(habit.goal)\n"
        reportContent += "   Schedule: \(habit.schedule)\n"
        reportContent += "   Start Date: \(habit.startDate)\n"
        reportContent += "   Current Streak: \(habit.streak)\n"
        if let description = habit.habitDescription {
          reportContent += "   Description: \(description)\n"
        }
        reportContent += "\n"
      }
    }

    // Add progress summary
    if selectedDataTypes.contains(.progress) {
      reportContent += "\n\nPROGRESS SUMMARY\n"
      reportContent += "================\n"
      reportContent += "Total Completion Records: \(backup.completions.count)\n"
      reportContent += "Total Difficulty Records: \(backup.difficulties.count)\n"

      let completedCount = backup.completions.filter { $0.isCompleted }.count
      let totalCompletions = backup.completions.count
      let completionRate = totalCompletions > 0
        ? Double(completedCount) / Double(totalCompletions) * 100
        : 0

      reportContent += "Completion Rate: \(String(format: "%.1f", completionRate))%\n"
      reportContent += "Completed Tasks: \(completedCount) / \(totalCompletions)\n\n"
    }

    // Add analytics summary
    if selectedDataTypes.contains(.analytics) {
      reportContent += "\n\nANALYTICS SUMMARY\n"
      reportContent += "=================\n"
      reportContent += "Total Usage Records: \(backup.usageRecords.count)\n"
      reportContent += "Total Notes: \(backup.habitNotes.count)\n"

      if let legacyData = backup.legacyData {
        reportContent += "Total App Launches: \(legacyData.totalAppLaunches)\n"
        reportContent += "Total Habits Created: \(legacyData.totalHabitsCreated)\n"
        reportContent += "Total Completions: \(legacyData.totalCompletions)\n"
      }
      reportContent += "\n"
    }

    // Add settings summary
    if selectedDataTypes.contains(.settings) {
      reportContent += "\n\nSETTINGS SUMMARY\n"
      reportContent += "================\n"

      let enabledNotifications = backup.userSettings.notificationSettings.filter { $0.value }.count
      let totalNotifications = backup.userSettings.notificationSettings.count

      reportContent += "Notifications Enabled: \(enabledNotifications) / \(totalNotifications)\n"
      reportContent += "Color Scheme: \(backup.userSettings.themeSettings["colorSchemePreference"] ?? "system")\n"
      reportContent += "Language: \(backup.userSettings.appSettings["language"] ?? "en")\n"
      reportContent += "Timezone: \(backup.userSettings.appSettings["timezone"] ?? "system")\n\n"
    }

    reportContent += "\n\n--- End of Report ---\n"
    reportContent += "Generated by Habitto Export Tool\n"
    reportContent += "For support, contact: support@habitto.app\n"

    return reportContent.data(using: .utf8) ?? Data()
  }
}

// MARK: - ExportPreviewView

struct ExportPreviewView: View {
  // MARK: Internal

  let selectedDataTypes: Set<ExportDataView.DataType>
  let selectedDateRange: ExportDataView.DateRange
  let selectedFormat: ExportDataView.ExportFormat
  let estimatedSize: String

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Preview Content
        ScrollView {
          VStack(spacing: 20) {
            // Description text
            Text("Review what will be included in your export")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .padding(.top, 8)

            // Export Overview
            VStack(spacing: 16) {
              HStack {
                Image("Icon-Download_Filled")
                  .renderingMode(.template)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 24, height: 24)
                  .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 4) {
                  Text("Export Overview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.text01)

                  Text("\(selectedFormat.displayName) format • \(estimatedSize)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text03)
                }

                Spacer()
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 16)
              .background(Color("appSurface02Variant"))
              .cornerRadius(24)
            }
            .padding(.horizontal, 20)

            // Data Types Preview
            VStack(spacing: 16) {
              HStack {
                Text("Included Data Types")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.text01)

                Spacer()
              }
              .padding(.horizontal, 20)

              ForEach(
                selectedDataTypes.sorted(by: { $0.displayName < $1.displayName }),
                id: \.self)
              { dataType in
                DataTypePreviewRow(dataType: dataType)
              }
            }
            .padding(.bottom, 20)

            // Date Range Preview
            VStack(spacing: 16) {
              HStack {
                Text("Date Range")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.text01)

                Spacer()
              }
              .padding(.horizontal, 20)

              HStack {
                Image(systemName: "calendar")
                  .renderingMode(.template)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 20, height: 20)
                  .foregroundColor(.navy200)

                VStack(alignment: .leading, spacing: 2) {
                  Text(selectedDateRange.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                  Text(selectedDateRange.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text03)
                }

                Spacer()
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 12)
              .background(Color("appSurface02Variant"))
              .cornerRadius(24)
            }
            .padding(.horizontal, 20)

            // Format Preview
            VStack(spacing: 16) {
              HStack {
                Text("Export Format")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.text01)

                Spacer()
              }
              .padding(.horizontal, 20)

              HStack {
                Image(selectedFormat.icon)
                  .renderingMode(.template)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 20, height: 20)
                  .foregroundColor(.navy200)

                VStack(alignment: .leading, spacing: 2) {
                  Text(selectedFormat.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                  Text(selectedFormat.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text03)
                }

                Spacer()
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 12)
              .background(Color("appSurface02Variant"))
              .cornerRadius(24)
            }
            .padding(.horizontal, 20)

            // Sample Data Preview
            VStack(spacing: 16) {
              HStack {
                Text("Sample Data Structure")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.text01)

                Spacer()
              }
              .padding(.horizontal, 20)

              VStack(alignment: .leading, spacing: 8) {
                Text(sampleDataPreview)
                  .font(.system(size: 12, weight: .regular, design: .monospaced))
                  .foregroundColor(.text02)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .background(Color.grey100)
                  .cornerRadius(8)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
          }
        }
        .background(Color("appSurface01Variant02"))
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Export Preview")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  private var sampleDataPreview: String {
    let dataTypesList = selectedDataTypes.map { $0.rawValue }.sorted().joined(separator: ", ")

    return """
    {
      "version": "1.0",
      "exportDate": "\(Date().ISO8601Format())",
      "format": "\(selectedFormat.rawValue)",
      "dateRange": "\(selectedDateRange.rawValue)",
      "dataTypes": [\(dataTypesList)],
      "metadata": {
        "appVersion": "1.0.0",
        "deviceModel": "iPhone",
        "osVersion": "iOS 17.0",
        "userId": "user_***"
      },
      "habits": [
        {
          "id": "habit_***",
          "name": "Your habit name",
          "goal": "Your habit goal",
          "schedule": "Your schedule",
          "startDate": "2024-01-01",
          "streak": 25
        }
      ],
      "completions": [
        {
          "habitId": "habit_***",
          "date": "2024-01-15",
          "isCompleted": true
        }
      ],
      "analytics": {
        "totalHabits": "Based on your data",
        "totalCompletions": "Based on your data",
        "completionRate": "Calculated from your progress"
      }
    }
    """
  }
}

// MARK: - DataTypePreviewRow

struct DataTypePreviewRow: View {
  let dataType: ExportDataView.DataType

  var body: some View {
    HStack {
      Image(dataType.icon)
        .renderingMode(.template)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .foregroundColor(.navy200)

      VStack(alignment: .leading, spacing: 2) {
        Text(dataType.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.text01)
        Text(dataType.description)
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(.text03)
      }

      Spacer()

      HStack(spacing: 8) {
        Text(dataType.estimatedSize)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.text03)

        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)
          .font(.system(size: 16))
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Color("appSurface02Variant"))
    .cornerRadius(24)
    .padding(.horizontal, 20)
  }
}

// MARK: - ExportCompleteView

struct ExportCompleteView: View {
  // MARK: Internal

  let fileURL: URL
  let onDismiss: () -> Void

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        Spacer()

        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.green)

        VStack(spacing: 8) {
          Text("Export Complete!")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.text01)

          Text("Your data has been exported successfully")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
        }

        // File Information Card
        VStack(spacing: 16) {
          HStack {
            Image(systemName: "doc.text")
              .font(.system(size: 20))
              .foregroundColor(.navy200)

            VStack(alignment: .leading, spacing: 4) {
              Text("Exported File")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.text01)

              Text(fileURL.lastPathComponent)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.text03)
                .lineLimit(2)
            }

            Spacer()

            Button(action: {
              showingFileInfo.toggle()
            }) {
              Image(systemName: "info.circle")
                .font(.system(size: 20))
                .foregroundColor(.navy200)
            }
          }

          if showingFileInfo {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("File Location:")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundColor(.text02)
                Spacer()
              }

              Text("Documents/Habitto Exports/")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.text03)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.grey100)
                .cornerRadius(8)

              if let fileSize = getFileSize() {
                HStack {
                  Text("File Size:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.text02)
                  Spacer()
                  Text(fileSize)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.text03)
                }
              }
            }
            .padding(.top, 8)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color("appSurface02Variant"))
        .cornerRadius(24)
        .padding(.horizontal, 20)

        Spacer()

        // Action Buttons
        VStack(spacing: 12) {
          // Share Button
          Button(action: {
            showingShareSheet = true
          }) {
            HStack {
              Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .medium))
              Text("Share File")
                .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.primary)
            .cornerRadius(12)
          }

          // Done Button
          Button("Done") {
            onDismiss()
          }
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.text02)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(Color("appSurface02Variant"))
          .cornerRadius(24)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }
      .background(Color("appSurface01Variant02"))
    }
    .sheet(isPresented: $showingShareSheet) {
      ShareSheet(activityItems: [fileURL])
    }
  }

  // MARK: Private

  @State private var showingShareSheet = false
  @State private var showingFileInfo = false

  private func getFileSize() -> String? {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
      if let fileSize = attributes[.size] as? Int64 {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
      }
    } catch {
      print("Error getting file size: \(error)")
    }
    return nil
  }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context _: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: nil)
    return controller
  }

  func updateUIViewController(_: UIActivityViewController, context _: Context) {
    // No updates needed
  }
}

// MARK: - ExportData

struct ExportData: Codable {
  // MARK: Lifecycle

  init(
    dataTypes: [ExportDataView.DataType],
    dateRange: ExportDataView.DateRange,
    format: ExportDataView.ExportFormat,
    timestamp: Date)
  {
    self.dataTypes = dataTypes
    self.dateRange = dateRange
    self.format = format
    self.timestamp = timestamp
    self.version = "1.0"
  }

  // MARK: Internal

  let dataTypes: [ExportDataView.DataType]
  let dateRange: ExportDataView.DateRange
  let format: ExportDataView.ExportFormat
  let timestamp: Date
  let version: String
}

// MARK: - ExportError

enum ExportError: Error, LocalizedError {
  case noDataTypesSelected
  case invalidFormat
  case invalidDateRange
  case emptyExportData
  case exportTooLarge
  case fileNotCreated
  case invalidFileSize
  case dataFilteringFailed
  case formatGenerationFailed

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noDataTypesSelected:
      "Please select at least one data type to export"
    case .invalidFormat:
      "Invalid export format selected"
    case .invalidDateRange:
      "Invalid date range selected"
    case .emptyExportData:
      "No data available for export with current settings"
    case .exportTooLarge:
      "Export data is too large (maximum 100MB)"
    case .fileNotCreated:
      "Failed to create export file"
    case .invalidFileSize:
      "Export file has invalid size"
    case .dataFilteringFailed:
      "Failed to filter data for export"
    case .formatGenerationFailed:
      "Failed to generate data in selected format"
    }
  }
}

#Preview {
  ExportDataView()
}
