#!/usr/bin/env swift
/**
 Focused repro for BackgroundQueueManager operation-counter integrity.

 Mirrors the fixed beginOperation/endOperation pattern used by
 Core/Data/BackgroundQueueManager.swift (async + completion-handler paths)
 and asserts the counter returns to exactly 0 with isProcessing == false.

 Run: swift Scripts/verify_background_queue_counter.swift
 */

import Foundation

@MainActor
final class CounterQueue {
  private(set) var activeOperations = 0
  private(set) var isProcessing = false

  private let backgroundQueue = DispatchQueue(label: "repro.background", qos: .userInitiated)
  private let serialQueue = DispatchQueue(label: "repro.serial", qos: .userInitiated)

  private func beginOperation() {
    activeOperations += 1
    isProcessing = true
  }

  private func endOperation() {
    activeOperations = max(0, activeOperations - 1)
    if activeOperations == 0 {
      isProcessing = false
    }
  }

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

  func execute<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
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

  func executeSerial<T>(
    _ task: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
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
}

enum ReproError: Error { case boom }

@MainActor
func runRepro() async -> Int {
  let queue = CounterQueue()

  await withTaskGroup(of: Void.self) { group in
    for i in 0..<8 {
      group.addTask { @MainActor in
        _ = try? await queue.execute {
          Thread.sleep(forTimeInterval: 0.005)
          return i
        }
      }
      group.addTask { @MainActor in
        _ = try? await queue.execute { throw ReproError.boom }
      }
      group.addTask { @MainActor in
        _ = try? await queue.executeSerial {
          Thread.sleep(forTimeInterval: 0.005)
          return i
        }
      }
      group.addTask { @MainActor in
        _ = try? await queue.executeSerial { throw ReproError.boom }
      }
    }

    for _ in 0..<4 {
      group.addTask { @MainActor in
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
          queue.execute({
            Thread.sleep(forTimeInterval: 0.01)
            return 1
          }, completion: { _ in cont.resume() })
        }
      }
      group.addTask { @MainActor in
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
          queue.execute({ throw ReproError.boom }, completion: { _ in cont.resume() })
        }
      }
      group.addTask { @MainActor in
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
          queue.executeSerial({ 1 }, completion: { _ in cont.resume() })
        }
      }
      group.addTask { @MainActor in
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
          queue.executeSerial({ throw ReproError.boom }, completion: { _ in cont.resume() })
        }
      }
    }
  }

  let passed = queue.activeOperations == 0 && queue.isProcessing == false
  print("activeOperations=\(queue.activeOperations) isProcessing=\(queue.isProcessing)")
  if passed {
    print("PASS: counter returned to 0 and isProcessing is false")
    return 0
  } else {
    print("FAIL: expected activeOperations==0 and isProcessing==false")
    return 1
  }
}

let code = await runRepro()
exit(Int32(code))
