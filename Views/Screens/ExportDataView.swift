import SwiftUI
import Foundation

struct ExportDataView: View {
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
    
    enum DataType: String, CaseIterable, Codable {
        case habits = "habits"
        case progress = "progress"
        case profile = "profile"
        case settings = "settings"
        case analytics = "analytics"
        
        var displayName: String {
            switch self {
            case .habits: return "Habits & Progress"
            case .progress: return "Completion History"
            case .profile: return "User Profile"
            case .settings: return "App Settings"
            case .analytics: return "Analytics Data"
            }
        }
        
        var icon: String {
            switch self {
            case .habits: return "Icon-Fire_Filled"
            case .progress: return "Icon-Chart_Filled"
            case .profile: return "Icon-User_Filled"
            case .settings: return "Icon-Settings_Filled"
            case .analytics: return "Icon-Analytics_Filled"
            }
        }
        
        var estimatedSize: String {
            switch self {
            case .habits: return "1.2 MB"
            case .progress: return "856 KB"
            case .profile: return "2 KB"
            case .settings: return "1 KB"
            case .analytics: return "45 KB"
            }
        }
        
        var description: String {
            switch self {
            case .habits: return "Your habits, goals, and current progress"
            case .progress: return "Historical completion records and streaks"
            case .profile: return "Your name, email, and account information"
            case .settings: return "App preferences and configuration"
            case .analytics: return "Usage statistics and performance data"
            }
        }
    }
    
    enum DateRange: String, CaseIterable, Codable {
        case last30Days = "30days"
        case last6Months = "6months"
        case lastYear = "year"
        case allTime = "all"
        
        var displayName: String {
            switch self {
            case .last30Days: return "Last 30 days"
            case .last6Months: return "Last 6 months"
            case .lastYear: return "Last year"
            case .allTime: return "All time"
            }
        }
        
        var description: String {
            switch self {
            case .last30Days: return "Export data from the past month"
            case .last6Months: return "Export data from the past 6 months"
            case .lastYear: return "Export data from the past year"
            case .allTime: return "Export all your data"
            }
        }
    }
    
    enum ExportFormat: String, CaseIterable, Codable {
        case json = "json"
        case csv = "csv"
        case pdf = "pdf"
        
        var displayName: String {
            switch self {
            case .json: return "JSON"
            case .csv: return "CSV"
            case .pdf: return "PDF Report"
            }
        }
        
        var description: String {
            switch self {
            case .json: return "Machine-readable format (recommended)"
            case .csv: return "Spreadsheet format"
            case .pdf: return "Human-readable report"
            }
        }
        
        var icon: String {
            switch self {
            case .json: return "Icon-Code_Filled"
            case .csv: return "Icon-Table_Filled"
            case .pdf: return "Icon-Document_Filled"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with close button and left-aligned title
                        ScreenHeader(
                            title: "Export Data",
                            description: "Download your personal data in your preferred format"
                        ) {
                            dismiss()
                        }
                        
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
                                        Text(selectedDataTypes.isEmpty ? "Select data types..." : "\(selectedDataTypes.count) selected")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(selectedDataTypes.isEmpty ? .text03 : .text01)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.text03)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.grey200, lineWidth: 1)
                                    )
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
                                    .background(Color.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.grey200, lineWidth: 1)
                                    )
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
                                    .background(Color.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.grey200, lineWidth: 1)
                                    )
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
                                        
                                        Text("\(selectedDataTypes.count) data types • \(selectedDateRange.displayName) • \(selectedFormat.displayName)")
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
                                .background(Color.surface)
                                .cornerRadius(12)
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
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image("Icon-Download_Filled")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                }
                                
                                Text(isExporting ? "Exporting..." : "Export Data")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
                            .cornerRadius(12)
                        }
                        .disabled(isExporting || selectedDataTypes.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
                .background(Color.surface2)
            }
            .background(Color.surface2)
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
                estimatedSize: estimatedTotalSize
            )
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
    
    private var estimatedTotalSize: String {
        let totalKB = selectedDataTypes.reduce(0) { total, dataType in
            let sizeString = dataType.estimatedSize
            let size = Double(sizeString.replacingOccurrences(of: " KB", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0
            return total + (sizeString.contains("MB") ? size * 1024 : size)
        }
        
        if totalKB >= 1024 {
            return String(format: "%.1f MB", totalKB / 1024)
        } else {
            return String(format: "%.0f KB", totalKB)
        }
    }
    
    private func performExport() async {
        isExporting = true
        
        do {
            // Create export data based on selected options
            let exportData = try await createExportData()
            
            // Generate file URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "habitto_export_\(Date().timeIntervalSince1970).\(selectedFormat.rawValue)"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            // Write data to file
            try writeExportData(exportData, to: fileURL)
            
            // Update UI on main thread
            await MainActor.run {
                self.exportFileURL = fileURL
                self.showingExportComplete = true
                self.isExporting = false
            }
            
        } catch {
            await MainActor.run {
                self.exportError = error.localizedDescription
                self.isExporting = false
            }
        }
    }
    
    private func createExportData() async throws -> Data {
        // This would integrate with BackupManager to create the actual export data
        // For now, return mock data
        let exportData = ExportData(
            dataTypes: Array(selectedDataTypes),
            dateRange: selectedDateRange,
            format: selectedFormat,
            timestamp: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(exportData)
    }
    
    private func writeExportData(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}

// MARK: - Supporting Views

struct ExportPreviewView: View {
    let selectedDataTypes: Set<ExportDataView.DataType>
    let selectedDateRange: ExportDataView.DateRange
    let selectedFormat: ExportDataView.ExportFormat
    let estimatedSize: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Export Preview",
                    description: "Review what will be included in your export"
                ) {
                    dismiss()
                }
                
                // Preview Content
                ScrollView {
                    VStack(spacing: 20) {
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
                            .background(Color.surface)
                            .cornerRadius(16)
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
                            
                            ForEach(selectedDataTypes.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { dataType in
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
                            .background(Color.surface)
                            .cornerRadius(12)
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
                            .background(Color.surface)
                            .cornerRadius(12)
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
                .background(Color.surface2)
            }
            .background(Color.surface2)
        }
    }
    
    private var sampleDataPreview: String {
        let dataTypesList = selectedDataTypes.map { $0.rawValue }.sorted().joined(separator: ", ")
        
        return """
{
  "version": "1.0",
  "exportDate": "2024-01-15T10:30:00Z",
  "format": "\(selectedFormat.rawValue)",
  "dateRange": "\(selectedDateRange.rawValue)",
  "dataTypes": [\(dataTypesList)],
  "userProfile": {
    "name": "John Doe",
    "email": "john@example.com"
  },
  "habits": [
    {
      "id": "habit_001",
      "name": "Morning Exercise",
      "goal": "30 minutes daily",
      "completions": [...]
    }
  ],
  "analytics": {
    "totalHabits": 5,
    "totalCompletions": 150,
    "averageStreak": 12
  }
}
"""
    }
}

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
        .background(Color.surface)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

struct ExportCompleteView: View {
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
                
                VStack(spacing: 16) {
                    Text("File saved to:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.text02)
                    
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.text03)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.grey100)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.surface2)
        }
    }
}

// MARK: - Data Models

struct ExportData: Codable {
    let dataTypes: [ExportDataView.DataType]
    let dateRange: ExportDataView.DateRange
    let format: ExportDataView.ExportFormat
    let timestamp: Date
    let version: String
    
    init(dataTypes: [ExportDataView.DataType], dateRange: ExportDataView.DateRange, format: ExportDataView.ExportFormat, timestamp: Date) {
        self.dataTypes = dataTypes
        self.dateRange = dateRange
        self.format = format
        self.timestamp = timestamp
        self.version = "1.0"
    }
}

#Preview {
    ExportDataView()
}
