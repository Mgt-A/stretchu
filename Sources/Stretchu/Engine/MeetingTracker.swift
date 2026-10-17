import Foundation

/// "In a meeting" state from mic/camera samples.
/// A meeting starts as soon as a mic or camera is in use, and ends after
/// 10 s without any use (a shorter gap between two activations doesn't count).
struct MeetingTracker {
    let clock: any Clock
    let endDelay: TimeInterval

    private(set) var inMeeting = false
    private var lastUse: Date?

    init(clock: any Clock, endDelay: TimeInterval = 10) {
        self.clock = clock
        self.endDelay = endDelay
    }

    mutating func sample(inUse: Bool) {
        let now = clock.now
        if inUse {
            lastUse = now
            inMeeting = true
        } else if inMeeting, let last = lastUse, now.timeIntervalSince(last) >= endDelay {
            inMeeting = false
        }
    }
}
