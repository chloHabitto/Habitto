import Foundation
import Combine

/// Lightweight event bus for domain events
public class EventBus: ObservableObject {
    public static let shared = EventBus()
    
    private let subject = PassthroughSubject<DomainEvent, Never>()
    
    private init() {}
    
    /// Publish a domain event
    public func publish(_ event: DomainEvent) {
        subject.send(event)
    }
    
    /// Subscribe to domain events
    public func publisher() -> AnyPublisher<DomainEvent, Never> {
        subject.eraseToAnyPublisher()
    }
}

/// Domain events
public enum DomainEvent {
    case dailyAwardGranted(dateKey: String)
    case dailyAwardRevoked(dateKey: String)
}
