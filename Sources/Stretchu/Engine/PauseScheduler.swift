import Foundation

enum PausePhase: Equatable {
    case work, wakeUp, step1, step2
}

enum SchedulerEvent: Equatable {
    case wakeUp
    /// Wake-up is due but held back: a meeting is going on. Signalled only once.
    case wakeUpDeferred
    case step2Started
    case breakCompleted
    case skipped
    case snoozed
}

/// What the IdleMonitor knows about the user at a given moment.
struct Activity: Equatable {
    var idleSeconds: TimeInterval
    var isLocked: Bool

    static let active = Activity(idleSeconds: 0, isLocked: false)
}

struct SchedulerConfig {
    var work: TimeInterval = 25 * 60
    var snooze: TimeInterval = 5 * 60
    var maxSnoozes = 2
    var step1: TimeInterval = 30
    var step2: TimeInterval = 30
    var idleThreshold: TimeInterval = 5 * 60
    var schedule = ActiveSchedule()
}

/// State machine `work → wake-up → step 1 → step 2 → work`.
/// No timer in here: the caller runs `tick` (every second) and the
/// scheduler measures time with the injected clock.
struct PauseScheduler {
    private(set) var config: SchedulerConfig
    let clock: any Clock

    private(set) var phase: PausePhase = .work
    private(set) var snoozeCount = 0
    private(set) var isIdle = false
    /// The work block has run out but the wake-up waits for a meeting to end.
    private(set) var isDeferred = false
    /// Time elapsed in the current phase (active time only for `.work`).
    private var elapsed: TimeInterval = 0
    /// Target length of the current work block: 25 min, or 5 min after a snooze.
    private var workTarget: TimeInterval
    private var lastTick: Date
    let calendar: Calendar
    /// The break in progress was started outside the active hours (a manual one): its XP counts,
    /// the streak does not move.
    private(set) var breakStartedOutsideHours = false

    init(config: SchedulerConfig = SchedulerConfig(), clock: any Clock, calendar: Calendar = .current) {
        self.config = config
        self.clock = clock
        self.calendar = calendar
        self.workTarget = config.work
        self.lastTick = clock.now
    }

    /// The icon shows "waiting": the wake-up is held back by a meeting.
    var isWaiting: Bool { isDeferred }

    /// Stretchu is asleep: no break in progress and the clock is outside the active hours or days.
    var isOutsideHours: Bool {
        phase == .work && !config.schedule.isActive(at: clock.now, calendar: calendar)
    }

    var canSnooze: Bool { snoozeCount < config.maxSnoozes }

    /// Time left in the current phase (0 at wake-up).
    var remaining: TimeInterval {
        switch phase {
        case .work: max(0, workTarget - elapsed)
        case .wakeUp: 0
        case .step1: max(0, config.step1 - elapsed)
        case .step2: max(0, config.step2 - elapsed)
        }
    }

    /// 0...1 of the work block elapsed (the menu's "Next break" bar).
    var workFraction: Double {
        phase == .work ? min(1, elapsed / workTarget) : 1
    }

    /// 0...1 within the current step (progress bars).
    var stepFraction: Double {
        switch phase {
        case .step1: min(1, elapsed / config.step1)
        case .step2: min(1, elapsed / config.step2)
        default: 0
        }
    }

    // MARK: settings

    /// Applies new durations. The running work block takes the new length (time already worked
    /// is kept); a snooze block takes the new snooze length.
    mutating func apply(_ new: SchedulerConfig) {
        let isSnoozing = phase == .work && snoozeCount > 0 && workTarget == config.snooze
        config = new
        if phase == .work { workTarget = isSnoozing ? new.snooze : new.work }
        else if snoozeCount == 0 { workTarget = new.work }
    }

    // MARK: time

    mutating func tick(_ activity: Activity, inMeeting: Bool = false) -> [SchedulerEvent] {
        let now = clock.now
        let previous = lastTick
        let dt = max(0, now.timeIntervalSince(previous))
        lastTick = now

        switch phase {
        case .work:
            // Outside the hours nothing counts and nothing wakes up. A break in progress at the end
            // of the hours finishes normally; the block that was running starts again at the opening.
            if isOutsideHours {
                restartBlock()
                return []
            }
            // An opening went by since the last tick (the Mac slept through the night, or this is the
            // first tick of the day): the block starts now, the time before the opening is not work.
            if let opening = config.schedule.nextStart(after: previous, calendar: calendar), opening <= now {
                restartBlock()
                return []
            }
            if isDeferred {
                // The work is done: only the end of the meeting is awaited.
                return inMeeting ? [] : enterWakeUp()
            }
            // In a meeting we listen without touching the keyboard: the counter keeps going.
            // Screen locked: it stops.
            let idle = activity.isLocked || (activity.idleSeconds >= config.idleThreshold && !inMeeting)
            if idle {
                if !isIdle {
                    isIdle = true
                    // The 5 min without keyboard before detection weren't work.
                    if !activity.isLocked { elapsed = max(0, elapsed - config.idleThreshold) }
                }
                return []
            }
            isIdle = false
            elapsed += dt
            if elapsed >= workTarget {
                guard inMeeting else { return enterWakeUp() }
                elapsed = workTarget
                isDeferred = true
                return [.wakeUpDeferred]
            }
            return []

        case .wakeUp:
            return []

        case .step1:
            elapsed += dt
            if elapsed >= config.step1 {
                elapsed = min(config.step2, elapsed - config.step1)
                phase = .step2
                return [.step2Started]
            }
            return []

        case .step2:
            elapsed = min(config.step2, elapsed + dt)
            return []
        }
    }

    /// After an intentional clock jump (Debug: next day): count nothing.
    mutating func resync() {
        lastTick = clock.now
    }

    // MARK: actions

    mutating func start() {
        guard phase == .wakeUp else { return }
        phase = .step1
        elapsed = 0
    }

    /// Postpones the wake-up by 5 min, 2 times at most per break.
    @discardableResult
    mutating func snooze() -> Bool {
        guard phase == .wakeUp, canSnooze else { return false }
        snoozeCount += 1
        workTarget = config.snooze
        returnToWork(keepSnoozes: true)
        return true
    }

    /// "Done" at step 2: the break is complete.
    mutating func finish() -> [SchedulerEvent] {
        guard phase == .step2 else { return [] }
        returnToWork(keepSnoozes: false)
        return [.breakCompleted]
    }

    /// "Skip": break lost.
    mutating func skip() -> [SchedulerEvent] {
        guard phase != .work else { return [] }
        returnToWork(keepSnoozes: false)
        return [.skipped]
    }

    /// "Take a break now": immediate wake-up, only from work.
    mutating func triggerWakeUp() -> [SchedulerEvent] {
        guard phase == .work else { return [] }
        return enterWakeUp()
    }

    // MARK: Debug

    /// Completes the break right away, from any state.
    mutating func completeNow() -> [SchedulerEvent] {
        returnToWork(keepSnoozes: false)
        return [.breakCompleted]
    }

    /// Skip from any state, work included.
    mutating func skipNow() -> [SchedulerEvent] {
        returnToWork(keepSnoozes: false)
        return [.skipped]
    }

    // MARK: internals

    private mutating func restartBlock() {
        elapsed = 0
        snoozeCount = 0
        workTarget = config.work
        isIdle = false
        isDeferred = false
    }

    private mutating func enterWakeUp() -> [SchedulerEvent] {
        breakStartedOutsideHours = isOutsideHours
        phase = .wakeUp
        elapsed = 0
        isIdle = false
        isDeferred = false
        return [.wakeUp]
    }

    private mutating func returnToWork(keepSnoozes: Bool) {
        phase = .work
        elapsed = 0
        isIdle = false
        isDeferred = false
        lastTick = clock.now
        if !keepSnoozes {
            snoozeCount = 0
            workTarget = config.work
        }
    }
}
