import Combine
import Foundation

// MARK: - EventBus

/// Lightweight event bus for domain events
public class EventBus: ObservableObject {
  // MARK: Lifecycle

  private init() { }

  // MARK: Public

  public static let shared = EventBus()

  /// Publish a domain event
  public func publish(_ event: DomainEvent) {
    subject.send(event)
  }

  /// Subscribe to domain events
  public func publisher() -> AnyPublisher<DomainEvent, Never> {
    subject.eraseToAnyPublisher()
  }

  // MARK: Private

  private let subject = PassthroughSubject<DomainEvent, Never>()
}

// MARK: - DomainEvent

/// Domain events
public enum DomainEvent {
  case dailyAwardGranted(dateKey: String)
  case dailyAwardRevoked(dateKey: String)
}
