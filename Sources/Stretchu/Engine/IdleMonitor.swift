import AppKit

/// Keyboard/mouse inactivity and screen lock.
@MainActor
final class IdleMonitor {
    private(set) var isLocked = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = true }
        })
        observers.append(center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = false }
        })
    }

    /// Seconds since the last keyboard/mouse event, all types combined.
    var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    var activity: Activity {
        Activity(idleSeconds: idleSeconds, isLocked: isLocked)
    }
}
