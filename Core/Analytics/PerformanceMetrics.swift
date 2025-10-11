import Foundation
import SwiftUI

// MARK: - PerformanceMetrics

/// Tracks various performance metrics for the app
@MainActor
class PerformanceMetrics: ObservableObject {
  // MARK: Lifecycle

  private init() {
    loadHistoricalMetrics()
  }

  // MARK: Internal

  static let shared = PerformanceMetrics()

  // MARK: - Published Properties

  @Published var isMonitoring = false
  @Published var currentMetrics = AppMetrics()
  @Published var historicalMetrics: [AppMetrics] = []

  // MARK: - Public Methods

  /// Start monitoring performance metrics
  func startMonitoring() {
    guard !isMonitoring else { return }

    isMonitoring = true
    currentMetrics = AppMetrics()

    // Start periodic monitoring
    monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        await self?.updateMetrics()
      }
    }

    print("📊 PerformanceMetrics: Started monitoring")
  }

  /// Stop monitoring performance metrics
  func stopMonitoring() {
    monitoringTimer?.invalidate()
    monitoringTimer = nil
    isMonitoring = false

    // Save final metrics
    saveCurrentMetrics()

    print("📊 PerformanceMetrics: Stopped monitoring")
  }

  /// Record a specific event
  func recordEvent(_ event: PerformanceEvent) {
    // Skip performance monitoring during vacation mode
    if VacationManager.shared.isActive {
      print(
        "📊 PerformanceMetrics: Skipping event during vacation mode - \(event.type.rawValue): \(event.description)")
      return
    }

    currentMetrics.events.append(event)

    // Update relevant counters
    switch event.type {
    case .dataLoad:
      currentMetrics.dataLoadCount += 1
    case .dataSave:
      currentMetrics.dataSaveCount += 1
    case .uiRender:
      currentMetrics.uiRenderCount += 1
    case .networkRequest:
      currentMetrics.networkRequestCount += 1
    case .error:
      currentMetrics.errorCount += 1
    case .userAction:
      currentMetrics.userActionCount += 1
    }

    print("📊 PerformanceMetrics: Recorded event - \(event.type.rawValue): \(event.description)")
  }

  /// Record timing for a specific operation
  func recordTiming(_ operation: String, duration: TimeInterval) {
    // Skip performance monitoring during vacation mode
    if VacationManager.shared.isActive {
      print(
        "📊 PerformanceMetrics: Skipping timing during vacation mode - \(operation): \(String(format: "%.3f", duration))s")
      return
    }

    let timing = PerformanceTiming(operation: operation, duration: duration)
    currentMetrics.timings.append(timing)

    // Update average timing if it's a known operation
    updateAverageTiming(for: operation, duration: duration)

    print(
      "📊 PerformanceMetrics: Recorded timing - \(operation): \(String(format: "%.3f", duration))s")
  }

  /// Record memory usage
  func recordMemoryUsage() {
    // Skip performance monitoring during vacation mode
    if VacationManager.shared.isActive {
      print("📊 PerformanceMetrics: Skipping memory monitoring during vacation mode")
      return
    }

    let memoryInfo = getMemoryInfo()
    currentMetrics.memoryUsage = memoryInfo.used
    currentMetrics.peakMemoryUsage = max(currentMetrics.peakMemoryUsage, memoryInfo.used)

    print(
      "📊 PerformanceMetrics: Memory usage - \(memoryInfo.used)MB (Peak: \(currentMetrics.peakMemoryUsage)MB)")
  }

  /// Record storage usage
  func recordStorageUsage() {
    // Skip performance monitoring during vacation mode
    if VacationManager.shared.isActive {
      print("📊 PerformanceMetrics: Skipping storage monitoring during vacation mode")
      return
    }

    let storageInfo = getStorageInfo()
    currentMetrics.storageUsage = storageInfo.used
    currentMetrics.habitsCount = storageInfo.habitsCount

    print(
      "📊 PerformanceMetrics: Storage usage - \(storageInfo.used)MB (\(storageInfo.habitsCount) habits)")
  }

  /// Get performance summary
  func getPerformanceSummary() -> PerformanceSummary {
    PerformanceSummary(
      averageDataLoadTime: getAverageTiming(for: "dataLoad"),
      averageDataSaveTime: getAverageTiming(for: "dataSave"),
      averageUIRenderTime: getAverageTiming(for: "uiRender"),
      totalEvents: currentMetrics.events.count,
      errorRate: calculateErrorRate(),
      memoryEfficiency: calculateMemoryEfficiency(),
      storageEfficiency: calculateStorageEfficiency())
  }

  // MARK: Private

  // MARK: - Private Properties

  private var monitoringTimer: Timer?
  private let metricsStorage = MetricsStorage()
  private let maxHistoricalEntries = 100

  // MARK: - Private Methods

  private func updateMetrics() async {
    recordMemoryUsage()
    recordStorageUsage()

    // Update session duration
    currentMetrics.sessionDuration = Date().timeIntervalSince(currentMetrics.sessionStartTime)
  }

  private func saveCurrentMetrics() {
    currentMetrics.sessionEndTime = Date()
    historicalMetrics.append(currentMetrics)

    // Keep only recent entries
    if historicalMetrics.count > maxHistoricalEntries {
      historicalMetrics = Array(historicalMetrics.suffix(maxHistoricalEntries))
    }

    // Save to persistent storage
    metricsStorage.saveMetrics(historicalMetrics)
  }

  private func loadHistoricalMetrics() {
    historicalMetrics = metricsStorage.loadMetrics()
  }

  private func updateAverageTiming(for operation: String, duration: TimeInterval) {
    if currentMetrics.averageTimings[operation] == nil {
      currentMetrics.averageTimings[operation] = duration
    } else {
      let currentAverage = currentMetrics.averageTimings[operation]!
      let count = currentMetrics.timings.filter { $0.operation == operation }.count
      currentMetrics
        .averageTimings[operation] = (currentAverage * Double(count - 1) + duration) / Double(count)
    }
  }

  private func getAverageTiming(for operation: String) -> TimeInterval {
    currentMetrics.averageTimings[operation] ?? 0.0
  }

  private func calculateErrorRate() -> Double {
    guard !currentMetrics.events.isEmpty else { return 0.0 }
    let errorCount = currentMetrics.events.filter { $0.type == .error }.count
    return Double(errorCount) / Double(currentMetrics.events.count)
  }

  private func calculateMemoryEfficiency() -> Double {
    guard currentMetrics.peakMemoryUsage > 0 else { return 1.0 }
    return min(1.0, 100.0 / currentMetrics.peakMemoryUsage) // Higher is better
  }

  private func calculateStorageEfficiency() -> Double {
    guard currentMetrics.habitsCount > 0 else { return 1.0 }
    let bytesPerHabit = (currentMetrics.storageUsage * 1024 * 1024) /
      Double(currentMetrics.habitsCount)
    return min(1.0, 1000.0 / bytesPerHabit) // Higher is better
  }

  private func getMemoryInfo() -> (used: Double, available: Double) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          $0,
          &count)
      }
    }

    if kerr == KERN_SUCCESS {
      let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
      let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
      let availableMB = totalMB - usedMB
      return (used: usedMB, available: availableMB)
    }

    return (used: 0.0, available: 0.0)
  }

  private func getStorageInfo() -> (used: Double, habitsCount: Int) {
    // Get UserDefaults storage size
    let userDefaults = UserDefaults.standard
    let dictionary = userDefaults.dictionaryRepresentation()

    var totalSize = 0
    var habitsCount = 0

    for (key, value) in dictionary {
      if key.hasPrefix("Habit_") {
        habitsCount += 1
      }

      // Estimate size (rough calculation)
      if let data = value as? Data {
        totalSize += data.count
      } else if let string = value as? String {
        totalSize += string.utf8.count
      } else if value is NSNumber {
        totalSize += MemoryLayout<NSNumber>.size
      }
    }

    let usedMB = Double(totalSize) / 1024.0 / 1024.0
    return (used: usedMB, habitsCount: habitsCount)
  }
}

// MARK: - AppMetrics

struct AppMetrics: Codable {
  var sessionStartTime = Date()
  var sessionEndTime: Date?
  var sessionDuration: TimeInterval = 0

  var events: [PerformanceEvent] = []
  var timings: [PerformanceTiming] = []

  var dataLoadCount = 0
  var dataSaveCount = 0
  var uiRenderCount = 0
  var networkRequestCount = 0
  var errorCount = 0
  var userActionCount = 0

  var memoryUsage = 0.0
  var peakMemoryUsage = 0.0
  var storageUsage = 0.0
  var habitsCount = 0

  var averageTimings: [String: TimeInterval] = [:]
}

// MARK: - PerformanceEvent

struct PerformanceEvent: Codable, Identifiable {
  // MARK: Lifecycle

  init(type: EventType, description: String, metadata: [String: String] = [:]) {
    self.type = type
    self.description = description
    self.timestamp = Date()
    self.metadata = metadata
  }

  // MARK: Internal

  var id = UUID()
  let type: EventType
  let description: String
  let timestamp: Date
  let metadata: [String: String]
}

// MARK: - EventType

enum EventType: String, Codable, CaseIterable {
  case dataLoad = "data_load"
  case dataSave = "data_save"
  case uiRender = "ui_render"
  case networkRequest = "network_request"
  case error
  case userAction = "user_action"
}

// MARK: - PerformanceTiming

struct PerformanceTiming: Codable, Identifiable {
  // MARK: Lifecycle

  init(operation: String, duration: TimeInterval) {
    self.operation = operation
    self.duration = duration
    self.timestamp = Date()
  }

  // MARK: Internal

  var id = UUID()
  let operation: String
  let duration: TimeInterval
  let timestamp: Date
}

// MARK: - PerformanceSummary

struct PerformanceSummary {
  let averageDataLoadTime: TimeInterval
  let averageDataSaveTime: TimeInterval
  let averageUIRenderTime: TimeInterval
  let totalEvents: Int
  let errorRate: Double
  let memoryEfficiency: Double
  let storageEfficiency: Double

  var overallScore: Double {
    let timingScore =
      (1.0 - (averageDataLoadTime + averageDataSaveTime + averageUIRenderTime) / 3.0) * 0.4
    let errorScore = (1.0 - errorRate) * 0.3
    let efficiencyScore = (memoryEfficiency + storageEfficiency) / 2.0 * 0.3
    return min(1.0, max(0.0, timingScore + errorScore + efficiencyScore))
  }
}

// MARK: - MetricsStorage

class MetricsStorage {
  // MARK: Internal

  func saveMetrics(_ metrics: [AppMetrics]) {
    do {
      let data = try JSONEncoder().encode(metrics)
      userDefaults.set(data, forKey: metricsKey)
    } catch {
      print("❌ MetricsStorage: Failed to save metrics - \(error.localizedDescription)")
    }
  }

  func loadMetrics() -> [AppMetrics] {
    guard let data = userDefaults.data(forKey: metricsKey) else { return [] }

    do {
      return try JSONDecoder().decode([AppMetrics].self, from: data)
    } catch {
      print("❌ MetricsStorage: Failed to load metrics - \(error.localizedDescription)")
      return []
    }
  }

  func clearMetrics() {
    userDefaults.removeObject(forKey: metricsKey)
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let metricsKey = "PerformanceMetrics"
}
