import Foundation

// MARK: - DualWriteHabitRepository

final class DualWriteHabitRepository: HabitRepositoryProtocol, ObservableObject {
  // MARK: Lifecycle

  init(primary: any HabitRepositoryProtocol, secondary: any HabitRepositoryProtocol, fallbackReads: Bool) {
    self.primary = primary
    self.secondary = secondary
    self.fallbackReads = fallbackReads
  }

  // MARK: Internal

  typealias DataType = Habit

  // MARK: - Repository Protocol Implementation

  func habits() -> AsyncThrowingStream<[Habit], Error> {
    let primaryStream = primary.habits()
    if !fallbackReads { return primaryStream }
    return AsyncThrowingStream { cont in
      Task {
        do {
          for try await list in primaryStream {
            if list.isEmpty {
              if let fallback = try await secondary.habits().firstValue() {
                cont.yield(fallback)
                continue
              }
            }
            cont.yield(list)
          }
          cont.finish()
        } catch { cont.finish(throwing: error) }
      }
    }
  }

  func habit(by id: String) -> AsyncThrowingStream<Habit?, Error> {
    let primaryStream = primary.habit(by: id)
    if !fallbackReads { return primaryStream }
    return AsyncThrowingStream { cont in
      Task {
        do {
          var emitted = false
          for try await v in primaryStream {
            emitted = true
            cont.yield(v)
          }
          if !emitted {
            if let fallback = try await secondary.habit(by: id).firstValue() {
              cont.yield(fallback)
            }
          }
          cont.finish()
        } catch { cont.finish(throwing: error) }
      }
    }
  }

  func create(_ item: Habit) async throws {
    try await primary.create(item)
    Task {
      do {
        try await secondary.create(item)
        TelemetryService.shared.increment("dualwrite.habit.create")
      } catch {
        print("⚠️ DualWrite: Secondary create failed: \(error.localizedDescription)")
      }
    }
  }

  func update(_ item: Habit) async throws {
    try await primary.update(item)
    Task {
      do {
        try await secondary.update(item)
        TelemetryService.shared.increment("dualwrite.habit.update")
      } catch {
        print("⚠️ DualWrite: Secondary update failed: \(error.localizedDescription)")
      }
    }
  }

  func delete(id: String) async throws {
    try await primary.delete(id: id)
    Task {
      do {
        try await secondary.delete(id: id)
        TelemetryService.shared.increment("dualwrite.habit.delete")
      } catch {
        print("⚠️ DualWrite: Secondary delete failed: \(error.localizedDescription)")
      }
    }
  }

  func habits(for date: Date) async throws -> [Habit] {
    let primaryHabits = try await primary.habits(for: date)
    if primaryHabits.isEmpty, fallbackReads {
      return try await secondary.habits(for: date)
    }
    return primaryHabits
  }

  func markComplete(habitId: String, date: Date, count: Int) async throws -> Int {
    let primaryResult = try await primary.markComplete(habitId: habitId, date: date, count: count)
    Task {
      do {
        _ = try await secondary.markComplete(habitId: habitId, date: date, count: count)
        TelemetryService.shared.increment("dualwrite.habit.markComplete")
      } catch {
        // Secondary write failed, but primary succeeded
        print("⚠️ DualWrite: Secondary markComplete failed: \(error.localizedDescription)")
      }
    }
    return primaryResult
  }

  func getCompletionCount(habitId: String, date: Date) async throws -> Int {
    let primaryCount = try await primary.getCompletionCount(habitId: habitId, date: date)
    if primaryCount == 0, fallbackReads {
      return try await secondary.getCompletionCount(habitId: habitId, date: date)
    }
    return primaryCount
  }

  // MARK: Private

  private let primary: any HabitRepositoryProtocol // Firestore
  private let secondary: any HabitRepositoryProtocol // Local
  private let fallbackReads: Bool
}