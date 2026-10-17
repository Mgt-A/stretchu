import XCTest
@testable import Stretchu

final class MeetingTrackerTests: XCTestCase {
    var clock: FakeClock!
    var tracker: MeetingTracker!

    override func setUp() {
        clock = FakeClock()
        tracker = MeetingTracker(clock: clock)
    }

    /// One sample per second, like the app's tick.
    private func run(_ seconds: Int, inUse: Bool) {
        for _ in 0..<seconds {
            clock.advance(1)
            tracker.sample(inUse: inUse)
        }
    }

    func testNoMeetingAtStart() {
        XCTAssertFalse(tracker.inMeeting)
    }

    func testActiveMicOrCameraStartsAMeeting() {
        run(1, inUse: true)
        XCTAssertTrue(tracker.inMeeting)
    }

    func testAGapUnder10SecondsEndsNothing() {
        run(30, inUse: true)
        run(9, inUse: false)
        XCTAssertTrue(tracker.inMeeting)
    }

    func testTheMeetingEndsAfter10SecondsWithoutUse() {
        run(30, inUse: true)
        run(10, inUse: false)
        XCTAssertFalse(tracker.inMeeting)
    }

    func testUseBefore10SecondsResetsTheCounter() {
        run(30, inUse: true)
        run(8, inUse: false)
        run(1, inUse: true)
        run(8, inUse: false)
        XCTAssertTrue(tracker.inMeeting)
        run(2, inUse: false)
        XCTAssertFalse(tracker.inMeeting)
    }

    func testNoUseOutsideAMeetingStaysFalse() {
        run(60, inUse: false)
        XCTAssertFalse(tracker.inMeeting)
    }

    func testPollingEvery5SecondsEndsAtTheLatest15SecondsLater() {
        // Polling every 5 s: last use seen at t, end detected at t + 15 s at the latest.
        for _ in 0..<6 { clock.advance(5); tracker.sample(inUse: true) }
        var secondsUntilTheEnd = 0
        while tracker.inMeeting {
            clock.advance(5)
            tracker.sample(inUse: false)
            secondsUntilTheEnd += 5
        }
        XCTAssertLessThanOrEqual(secondsUntilTheEnd, 15)
    }
}

final class SchedulerMeetingTests: XCTestCase {
    var clock: FakeClock!
    var scheduler: PauseScheduler!

    override func setUp() {
        clock = FakeClock()
        scheduler = PauseScheduler(clock: clock, calendar: TestCalendar.calendar)
    }

    @discardableResult
    private func run(_ seconds: Int, meeting: Bool = false, activity: Activity = .active) -> [SchedulerEvent] {
        var events: [SchedulerEvent] = []
        for _ in 0..<seconds {
            clock.advance(1)
            events += scheduler.tick(activity, inMeeting: meeting)
        }
        return events
    }

    func testNoWakeUpDuringAMeeting() {
        let events = run(25 * 60 + 60, meeting: true)
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertTrue(scheduler.isDeferred)
        XCTAssertEqual(events, [.wakeUpDeferred], "signalled only once")
    }

    func testTheWakeUpShowsOnTheTickAfterTheMeetingEnds() {
        run(25 * 60 + 60, meeting: true)
        let events = run(1, meeting: false)
        XCTAssertEqual(events, [.wakeUp])
        XCTAssertEqual(scheduler.phase, .wakeUp)
        XCTAssertFalse(scheduler.isDeferred)
    }

    func testAMeetingBeforeTheDeadlineOnlyDefersAtTheDeadline() {
        run(24 * 60, meeting: true)
        XCTAssertFalse(scheduler.isDeferred)
        run(2 * 60, meeting: true)
        XCTAssertTrue(scheduler.isDeferred)
    }

    func testAMeetingThatEndsBeforeTheDeadlineChangesNothing() {
        run(10 * 60, meeting: true)
        run(15 * 60, meeting: false)
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    func testInactivityDoesNotLeaveTheWait() {
        run(25 * 60, meeting: true)
        run(10 * 60, meeting: true, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertTrue(scheduler.isDeferred)
        XCTAssertEqual(run(1, meeting: false, activity: Activity(idleSeconds: 3600, isLocked: false)), [.wakeUp])
    }

    func testASnoozeIsAlsoDeferredByAMeeting() {
        run(25 * 60)
        XCTAssertTrue(scheduler.snooze())
        run(5 * 60, meeting: true)
        XCTAssertTrue(scheduler.isDeferred)
        XCTAssertEqual(run(1, meeting: false), [.wakeUp])
        XCTAssertEqual(scheduler.snoozeCount, 1, "the snooze already taken stays counted")
    }

    func testAMeetingDoesNotInterruptABreakInProgress() {
        run(25 * 60)
        scheduler.start()
        run(10, meeting: true)
        XCTAssertEqual(scheduler.phase, .step1)
        run(20, meeting: true)
        XCTAssertEqual(scheduler.phase, .step2)
    }

    func testAMeetingNeitherHidesNorClosesAWakeUpAlreadyShown() {
        run(25 * 60)
        run(60, meeting: true)
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    func testManualBreakWorksInAMeeting() {
        XCTAssertEqual(scheduler.triggerWakeUp(), [.wakeUp])
    }

    func testSkipOrCompleteLeaveTheWait() {
        run(25 * 60 + 5, meeting: true)
        XCTAssertTrue(scheduler.isDeferred)
        _ = scheduler.completeNow()
        XCTAssertFalse(scheduler.isDeferred)
        XCTAssertEqual(scheduler.phase, .work)
    }

    func testTheMeetingOnlyCountsInActiveTime() {
        // Work time keeps running during the meeting.
        run(10 * 60, meeting: true)
        XCTAssertEqual(scheduler.remaining, 15 * 60, accuracy: 1)
    }

    func testDeferredWakeUpHasNoEffectOnTheStreakOrXP() {
        var game = GameState()
        game.streak = Streak(count: 9, breaksToday: 3, currentDay: TestCalendar.calendar.startOfDay(for: TestCalendar.monday))
        game.progression = Progression(xp: 5_000)
        let before = game
        _ = game.apply(.wakeUpDeferred, now: TestCalendar.monday, calendar: TestCalendar.calendar)
        XCTAssertEqual(game, before)
    }
}

final class MeetingCounterTests: XCTestCase {
    var clock: FakeClock!
    var scheduler: PauseScheduler!

    override func setUp() {
        clock = FakeClock()
        scheduler = PauseScheduler(clock: clock, calendar: TestCalendar.calendar)
    }

    private func run(_ seconds: Int, meeting: Bool, activity: Activity) {
        for _ in 0..<seconds { clock.advance(1); _ = scheduler.tick(activity, inMeeting: meeting) }
    }

    func testInAMeetingWithoutTouchingTheKeyboardTheCounterKeepsGoing() {
        // We listen to the call: more than 5 min without keyboard or mouse, the timer doesn't stop.
        run(60, meeting: true, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertFalse(scheduler.isIdle)
        XCTAssertEqual(scheduler.remaining, 25 * 60 - 60, accuracy: 1)
    }

    func testOutsideAMeetingInactivityStillStopsTheCounter() {
        run(60, meeting: false, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertTrue(scheduler.isIdle)
    }

    func testALockedScreenStopsTheCounterEvenInAMeeting() {
        run(60, meeting: true, activity: Activity(idleSeconds: 0, isLocked: true))
        XCTAssertTrue(scheduler.isIdle)
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 1)
    }

    func testALongMeetingWithoutKeyboardDefersTheWakeUpThenPingsAfterTheEnd() {
        run(25 * 60, meeting: true, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertTrue(scheduler.isDeferred, "the counter ran out during the call")
        XCTAssertEqual(scheduler.phase, .work)
        run(10 * 60, meeting: true, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertEqual(scheduler.phase, .work, "no ping during the meeting")
        var events: [SchedulerEvent] = []
        clock.advance(1)
        events += scheduler.tick(.active, inMeeting: false)
        XCTAssertEqual(events, [.wakeUp])
    }
}
