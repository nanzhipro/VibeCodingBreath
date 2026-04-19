import Foundation
import CoreGraphics

struct CGEventIdleTimeSource: IdleTimeSource {
    static let watchedEvents: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .leftMouseDragged,
        .rightMouseDragged,
        .scrollWheel,
        .keyDown,
        .flagsChanged
    ]

    func secondsSinceLastEvent() -> TimeInterval {
        let values = Self.watchedEvents.map { evt in
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: evt)
        }
        return values.min() ?? .greatestFiniteMagnitude
    }
}

@MainActor
final class IdleMonitor: IdleProviding {
    private let source: IdleTimeSource
    private let threshold: TimeInterval
    private let interval: TimeInterval
    private var pollTask: Task<Void, Never>?

    private(set) var isIdle: Bool = false
    var onChange: ((Bool) -> Void)?

    init(source: IdleTimeSource = CGEventIdleTimeSource(),
         threshold: TimeInterval = Constants.idleThreshold,
         interval: TimeInterval = Constants.pollInterval) {
        self.source = source
        self.threshold = threshold
        self.interval = interval
    }

    func start() {
        guard pollTask == nil else { return }
        let interval = self.interval
        pollTask = Task { @MainActor [weak self] in
            self?.tick()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                self?.tick()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func tick() {
        let seconds = source.secondsSinceLastEvent()
        let newIdle = seconds >= threshold
        guard newIdle != isIdle else { return }
        isIdle = newIdle
        AppLogger.idle.debug("idle edge -> \(newIdle ? "idle" : "active", privacy: .public)")
        onChange?(newIdle)
    }
}
