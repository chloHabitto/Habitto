import Foundation

/// ISO 8601 date formatting utilities for consistent date handling across the app
class ISO8601DateHelper {
    static let shared = ISO8601DateHelper()
    
    private let iso8601Formatter: ISO8601DateFormatter
    private let iso8601WithFractionalSecondsFormatter: ISO8601DateFormatter
    
    private init() {
        // Standard ISO 8601 formatter
        self.iso8601Formatter = ISO8601DateFormatter()
        self.iso8601Formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
        
        // ISO 8601 with fractional seconds for high precision
        self.iso8601WithFractionalSecondsFormatter = ISO8601DateFormatter()
        self.iso8601WithFractionalSecondsFormatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withFractionalSeconds
        ]
    }
    
    // MARK: - Date to String Conversion
    
    /// Convert Date to ISO 8601 string (standard format)
    func string(from date: Date) -> String {
        return iso8601Formatter.string(from: date)
    }
    
    /// Convert Date to ISO 8601 string with fractional seconds
    func stringWithFractionalSeconds(from date: Date) -> String {
        return iso8601WithFractionalSecondsFormatter.string(from: date)
    }
    
    /// Convert Date to ISO 8601 string for storage (UTC timezone)
    func storageString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    // MARK: - String to Date Conversion
    
    /// Convert ISO 8601 string to Date (standard format)
    func date(from string: String) -> Date? {
        return iso8601Formatter.date(from: string)
    }
    
    /// Convert ISO 8601 string with fractional seconds to Date
    func dateWithFractionalSeconds(from string: String) -> Date? {
        return iso8601WithFractionalSecondsFormatter.date(from: string)
    }
    
    /// Convert ISO 8601 string to Date with fallback parsing
    func dateWithFallback(from string: String) -> Date? {
        // Try standard format first
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        
        // Try with fractional seconds
        if let date = iso8601WithFractionalSecondsFormatter.date(from: string) {
            return date
        }
        
        // Try with different timezone formats
        let formatters = [
            createFormatter(options: [.withInternetDateTime, .withDashSeparatorInDate]),
            createFormatter(options: [.withInternetDateTime, .withDashSeparatorInDate, .withFractionalSeconds]),
            createFormatter(options: [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime])
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func createFormatter(options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter
    }
    
    /// Get current date as ISO 8601 string
    func currentDateString() -> String {
        return string(from: Date())
    }
    
    /// Get current date as ISO 8601 string with fractional seconds
    func currentDateStringWithFractionalSeconds() -> String {
        return stringWithFractionalSeconds(from: Date())
    }
    
    /// Validate if a string is a valid ISO 8601 date
    func isValidISO8601Date(_ string: String) -> Bool {
        return dateWithFallback(from: string) != nil
    }
}

// MARK: - Convenience Extensions

extension Date {
    /// Convert Date to ISO 8601 string using the shared helper
    var iso8601String: String {
        return ISO8601DateHelper.shared.string(from: self)
    }
    
    /// Convert Date to ISO 8601 string with fractional seconds
    var iso8601StringWithFractionalSeconds: String {
        return ISO8601DateHelper.shared.stringWithFractionalSeconds(from: self)
    }
    
    /// Convert Date to ISO 8601 string for storage (UTC)
    var iso8601StorageString: String {
        return ISO8601DateHelper.shared.storageString(from: self)
    }
}

extension String {
    /// Convert ISO 8601 string to Date using the shared helper
    var iso8601Date: Date? {
        return ISO8601DateHelper.shared.dateWithFallback(from: self)
    }
    
    /// Check if string is a valid ISO 8601 date
    var isValidISO8601Date: Bool {
        return ISO8601DateHelper.shared.isValidISO8601Date(self)
    }
}
