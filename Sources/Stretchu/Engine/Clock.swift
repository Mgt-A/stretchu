import Foundation

/// Injectable clock: the whole engine reads the time here, never through `Date()`.
protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

/// System time shifted by an adjustable offset. Used by Debug mode
/// (advance 25 min, jump to the next workday) without touching the Mac's clock.
final class SimulatedClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    var now: Date { lock.withLock { Date().addingTimeInterval(offset) } }
    var isSimulated: Bool { lock.withLock { abs(offset) > 0.5 } }

    func advance(by seconds: TimeInterval) { lock.withLock { offset += seconds } }

    func jump(to date: Date) { lock.withLock { offset = date.timeIntervalSinceNow } }

    func reset() { lock.withLock { offset = 0 } }
}
