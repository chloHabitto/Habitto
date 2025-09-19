import Foundation
import OSLog

// MARK: - Atomic File Writer
/// Provides atomic file writing using temporary files and atomic replacement
/// This ensures data integrity even if the app crashes during a write operation
final class AtomicFileWriter {
    private let logger = Logger(subsystem: "com.habitto.app", category: "AtomicFileWriter")
    
    // MARK: - Atomic Write Methods
    
    /// Writes data atomically to a file using a temporary file and atomic replacement
    /// - Parameters:
    ///   - data: The data to write
    ///   - to url: The target file URL
    ///   - options: Write options (default: .atomic)
    /// - Throws: AtomicFileWriterError if the operation fails
    func writeAtomically(_ data: Data, to url: URL, options: Data.WritingOptions = [.atomic]) throws {
        let tempURL = createTemporaryFileURL(for: url)
        
        do {
            // Write to temporary file first
            try data.write(to: tempURL, options: options)
            logger.debug("Data written to temporary file: \(tempURL.lastPathComponent)")
            
            // Atomically replace the target file
            try replaceFileAtomically(from: tempURL, to: url)
            logger.debug("File replaced atomically: \(url.lastPathComponent)")
            
        } catch {
            // Clean up temporary file on error
            cleanupTemporaryFile(at: tempURL)
            throw AtomicFileWriterError.writeFailed(underlyingError: error)
        }
    }
    
    /// Writes a string atomically to a file
    /// - Parameters:
    ///   - string: The string to write
    ///   - to url: The target file URL
    ///   - encoding: The string encoding (default: .utf8)
    /// - Throws: AtomicFileWriterError if the operation fails
    func writeAtomically(_ string: String, to url: URL, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw AtomicFileWriterError.encodingFailed
        }
        try writeAtomically(data, to: url)
    }
    
    /// Writes a Codable object atomically to a file as JSON
    /// - Parameters:
    ///   - object: The Codable object to write
    ///   - to url: The target file URL
    ///   - encoder: The JSON encoder to use (default: JSONEncoder())
    /// - Throws: AtomicFileWriterError if the operation fails
    func writeAtomically<T: Codable>(_ object: T, to url: URL, encoder: JSONEncoder = JSONEncoder()) throws {
        do {
            let data = try encoder.encode(object)
            try writeAtomically(data, to: url)
        } catch {
            throw AtomicFileWriterError.encodingFailed
        }
    }
    
    /// Reads data from a file with error handling
    /// - Parameter url: The file URL to read from
    /// - Returns: The data if successful, nil if file doesn't exist
    /// - Throws: AtomicFileWriterError if reading fails
    func readData(from url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            throw AtomicFileWriterError.readFailed(underlyingError: error)
        }
    }
    
    /// Reads a string from a file
    /// - Parameters:
    ///   - url: The file URL to read from
    ///   - encoding: The string encoding (default: .utf8)
    /// - Returns: The string if successful, nil if file doesn't exist
    /// - Throws: AtomicFileWriterError if reading fails
    func readString(from url: URL, encoding: String.Encoding = .utf8) throws -> String? {
        guard let data = try readData(from: url) else {
            return nil
        }
        
        return String(data: data, encoding: encoding)
    }
    
    /// Reads a Codable object from a file
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - from url: The file URL to read from
    ///   - decoder: The JSON decoder to use (default: JSONDecoder())
    /// - Returns: The decoded object if successful, nil if file doesn't exist
    /// - Throws: AtomicFileWriterError if reading fails
    func readObject<T: Codable>(_ type: T.Type, from url: URL, decoder: JSONDecoder = JSONDecoder()) throws -> T? {
        guard let data = try readData(from: url) else {
            return nil
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AtomicFileWriterError.decodingFailed(underlyingError: error)
        }
    }
    
    // MARK: - Private Methods
    
    /// Creates a temporary file URL for atomic writing
    /// - Parameter targetURL: The target file URL
    /// - Returns: A temporary file URL in the same directory
    private func createTemporaryFileURL(for targetURL: URL) -> URL {
        let tempDirectory = targetURL.deletingLastPathComponent()
        let tempFileName = ".\(targetURL.lastPathComponent).tmp.\(UUID().uuidString)"
        return tempDirectory.appendingPathComponent(tempFileName)
    }
    
    /// Replaces the target file atomically with the temporary file
    /// - Parameters:
    ///   - from tempURL: The temporary file URL
    ///   - to targetURL: The target file URL
    /// - Throws: AtomicFileWriterError if the replacement fails
    private func replaceFileAtomically(from tempURL: URL, to targetURL: URL) throws {
        let fileManager = FileManager.default
        
        // Ensure the target directory exists
        let targetDirectory = targetURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }
        
        // Remove target file if it exists
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        
        // Move temporary file to target location
        try fileManager.moveItem(at: tempURL, to: targetURL)
    }
    
    /// Cleans up a temporary file
    /// - Parameter url: The temporary file URL to clean up
    private func cleanupTemporaryFile(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                logger.debug("Cleaned up temporary file: \(url.lastPathComponent)")
            }
        } catch {
            logger.warning("Failed to clean up temporary file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Atomic File Writer Error

enum AtomicFileWriterError: LocalizedError {
    case writeFailed(underlyingError: Error)
    case readFailed(underlyingError: Error)
    case encodingFailed
    case decodingFailed(underlyingError: Error)
    case fileSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .writeFailed(let error):
            return "Failed to write file atomically: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .writeFailed:
            return "Check available disk space and file permissions"
        case .readFailed:
            return "Verify the file exists and is readable"
        case .encodingFailed:
            return "Check that the data can be encoded properly"
        case .decodingFailed:
            return "Verify the file contains valid data"
        case .fileSystemError:
            return "Check file system permissions and available space"
        }
    }
}
