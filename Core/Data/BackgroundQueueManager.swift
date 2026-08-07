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

  // MARK: - Operation Counter

  /// Begin tracking a background operation. Must be called on the main actor
  /// before hopping onto a GCD queue.
  private func beginOperation() {
    activeOperations += 1
    isProcessing = true
  }

  /// End tracking a background operation. Floors at 0 as a safety net;
  /// callers must still pair every begin with exactly one end.
  private func endOperation() {
    activeOperations = max(0, activeOperations - 1)
    if activeOperations == 0 {
      isProcessing = false
    }
  }

  // MARK: - Public Methods

  /// Execute a task on the background queue
  func execute<T>(_ task: @escaping () throws -> T) async throws -> T {
    beginOperation()
    do {
      let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
        backgroundQueue.async {
          do {
            continuation.resume(returning: try task())
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
      endOperation()
      return result
    } catch {
      endOperation()
      throw error
    }
  }

  /// Execute a task on the background queue without returning a value
  func execute(_ task: @escaping () throws -> Void) async throws {
    beginOperation()
    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        backgroundQueue.async {
          do {
            try task()
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
      endOperation()
    } catch {
      endOperation()
      throw error
    }
  }

  /// Execute a task on the serial queue (for operations that need to be sequential)
  func executeSerial<T>(_ task: @escaping () throws -> T) async throws -> T {
    beginOperation()
    do {
      let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
        serialQueue.async {
          do {
            continuation.resume(returning: try task())
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
      endOperation()
      return result
    } catch {
      endOperation()
      throw error
    }
  }

  /// Execute a task on the serial queue without returning a value
  func executeSerial(_ task: @escaping () throws -> Void) async throws {
    beginOperation()
    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        serialQueue.async {
          do {
            try task()
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
      endOperation()
    } catch {
      endOperation()
      throw error
    }
  }

  /// Execute a task on the background queue with completion handler
  func execute<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void)
  {
    beginOperation()

    backgroundQueue.async { [weak self] in
      let outcome: Result<T, Error>
      do {
        outcome = .success(try task())
      } catch {
        outcome = .failure(error)
      }
      Task { @MainActor in
        self?.endOperation()
        completion(outcome)
      }
    }
  }

  /// Execute a task on the serial queue with completion handler
  func executeSerial<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void)
  {
    beginOperation()

    serialQueue.async { [weak self] in
      let outcome: Result<T, Error>
      do {
        outcome = .success(try task())
      } catch {
        outcome = .failure(error)
      }
      Task { @MainActor in
        self?.endOperation()
        completion(outcome)
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

#if DEBUG
extension BackgroundQueueManager {
  /// Focused repro for operation-counter drift.
  /// Fires concurrent async + completion-handler work and reports the final counter state.
  func runCounterIntegrityRepro() async -> (passed: Bool, activeOperations: Int, isProcessing: Bool) {
    enum ReproError: Error { case boom }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<6 {
        group.addTask { @MainActor in
          _ = try? await self.execute {
            Thread.sleep(forTimeInterval: 0.005)
            return 1
          }
        }
        group.addTask { @MainActor in
          _ = try? await self.execute { throw ReproError.boom }
        }
        group.addTask { @MainActor in
          _ = try? await self.executeSerial {
            Thread.sleep(forTimeInterval: 0.005)
            return 1
          }
        }
        group.addTask { @MainActor in
          _ = try? await self.executeSerial { throw ReproError.boom }
        }
      }

      for _ in 0..<4 {
        group.addTask { @MainActor in
          await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.execute({
              Thread.sleep(forTimeInterval: 0.005)
              return 1
            }, completion: { _ in cont.resume() })
          }
        }
        group.addTask { @MainActor in
          await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.execute({ throw ReproError.boom }, completion: { _ in cont.resume() })
          }
        }
        group.addTask { @MainActor in
          await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.executeSerial({ 1 }, completion: { _ in cont.resume() })
          }
        }
        group.addTask { @MainActor in
          await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.executeSerial({ throw ReproError.boom }, completion: { _ in cont.resume() })
          }
        }
      }
    }

    let passed = activeOperations == 0 && isProcessing == false
    return (passed, activeOperations, isProcessing)
  }
}
#endif
