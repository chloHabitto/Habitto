import Foundation
import SwiftUI

// MARK: - BackgroundQueueManager

/// Manages background operations to keep the main thread free for UI updates
@MainActor
class BackgroundQueueManager: ObservableObject {
  // MARK: Lifecycle

  // MARK: - Initialization

  private init() { }

  // MARK: Internal

  static let shared = BackgroundQueueManager()

  // MARK: - Published Properties

  @Published var isProcessing = false
  @Published var activeOperations = 0

  // MARK: - Public Methods

  /// Execute a task on the background queue
  func execute<T>(_ task: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      backgroundQueue.async { [weak self] in
        do {
          let result = try task()
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume(returning: result)
        } catch {
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Execute a task on the background queue without returning a value
  func execute(_ task: @escaping () throws -> Void) async throws {
    try await withCheckedThrowingContinuation { continuation in
      backgroundQueue.async { [weak self] in
        do {
          try task()
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume()
        } catch {
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Execute a task on the serial queue (for operations that need to be sequential)
  func executeSerial<T>(_ task: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      serialQueue.async { [weak self] in
        do {
          let result = try task()
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume(returning: result)
        } catch {
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Execute a task on the serial queue without returning a value
  func executeSerial(_ task: @escaping () throws -> Void) async throws {
    try await withCheckedThrowingContinuation { continuation in
      serialQueue.async { [weak self] in
        do {
          try task()
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume()
        } catch {
          Task { @MainActor in
            self?.activeOperations -= 1
            if self?.activeOperations == 0 {
              self?.isProcessing = false
            }
          }
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Execute a task on the background queue with completion handler
  func execute<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void)
  {
    Task { @MainActor in
      activeOperations += 1
      isProcessing = true
    }

    backgroundQueue.async { [weak self] in
      do {
        let result = try task()
        Task { @MainActor in
          self?.activeOperations -= 1
          if self?.activeOperations == 0 {
            self?.isProcessing = false
          }
        }
        completion(.success(result))
      } catch {
        Task { @MainActor in
          self?.activeOperations -= 1
          if self?.activeOperations == 0 {
            self?.isProcessing = false
          }
        }
        completion(.failure(error))
      }
    }
  }

  /// Execute a task on the serial queue with completion handler
  func executeSerial<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void)
  {
    Task { @MainActor in
      activeOperations += 1
      isProcessing = true
    }

    serialQueue.async { [weak self] in
      do {
        let result = try task()
        Task { @MainActor in
          self?.activeOperations -= 1
          if self?.activeOperations == 0 {
            self?.isProcessing = false
          }
        }
        completion(.success(result))
      } catch {
        Task { @MainActor in
          self?.activeOperations -= 1
          if self?.activeOperations == 0 {
            self?.isProcessing = false
          }
        }
        completion(.failure(error))
      }
    }
  }

  /// Execute a task on the main queue (for UI updates)
  func executeOnMain<T>(_ task: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          let result = try task()
          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Execute a task on the main queue without returning a value
  func executeOnMain(_ task: @escaping () throws -> Void) async throws {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          try task()
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Execute a task on the main queue with completion handler
  func executeOnMain<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void)
  {
    DispatchQueue.main.async {
      do {
        let result = try task()
        completion(.success(result))
      } catch {
        completion(.failure(error))
      }
    }
  }

  // MARK: Private

  private let backgroundQueue = DispatchQueue(label: "com.habitto.background", qos: .userInitiated)
  private let serialQueue = DispatchQueue(label: "com.habitto.serial", qos: .userInitiated)
}

// MARK: - Convenience Extensions

extension BackgroundQueueManager {
  /// Execute a task on the background queue and return the result on the main queue
  func executeOnBackgroundReturnOnMain<T>(_ task: @escaping () throws -> T) async throws -> T {
    let result = try await execute(task)
    return try await executeOnMain { result }
  }

  /// Execute a task on the background queue and return the result on the main queue with completion
  func executeOnBackgroundReturnOnMain<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void)
  {
    execute(task) { [weak self] result in
      switch result {
      case .success(let value):
        self?.executeOnMain({ value }, completion: completion)
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
