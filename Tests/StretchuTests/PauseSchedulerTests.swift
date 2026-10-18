import XCTest
@testable import Stretchu

final class PauseSchedulerTests: XCTestCase {
    var clock: FakeClock!
    var scheduler: PauseScheduler!

    override func setUp() {
        clock = FakeClock()
        scheduler = PauseScheduler(clock: clock, calendar: TestCalendar.calendar)
    }

    /// Moves the clock in 1 s steps, calling tick at each step.
    @discardableResult
    private func run(_ seconds: Int, activity: Activity = .active) -> [SchedulerEvent] {
        var events: [SchedulerEvent] = []
        for _ in 0..<seconds {
            clock.advance(1)
            events += scheduler.tick(activity)
        }
        return events
    }

    // MARK: work → wake-up

    func testStartsInWorkWith25Minutes() {
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 0.001)
    }

    func testWakeUpAfter25ActiveMinutes() {
        let events = run(25 * 60)
        XCTAssertEqual(scheduler.phase, .wakeUp)
        XCTAssertEqual(events, [.wakeUp])
    }

    func testNoWakeUpBefore25Minutes() {
        run(25 * 60 - 1)
        XCTAssertEqual(scheduler.phase, .work)
    }

    // MARK: inactivity

    func testIdleTimeDoesNotCount() {
        run(10 * 60)
        run(60 * 60, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertTrue(scheduler.isIdle)
        // The first 5 minutes of inactivity are taken off the block.
        XCTAssertEqual(scheduler.remaining, 25 * 60 - 5 * 60, accuracy: 1)
    }

    func testLockedScreenPausesTheTimer() {
        run(10 * 60)
        let before = scheduler.remaining
        run(30 * 60, activity: Activity(idleSeconds: 0, isLocked: true))
        XCTAssertEqual(scheduler.remaining, before, accuracy: 1)
        XCTAssertEqual(scheduler.phase, .work)
    }

    func testAutomaticResumeOnReturn() {
        run(60, activity: Activity(idleSeconds: 400, isLocked: false))
        let paused = scheduler.remaining
        run(30)
        XCTAssertFalse(scheduler.isIdle)
        XCTAssertEqual(scheduler.remaining, paused - 30, accuracy: 1)
    }

    func testInactivityBelowTheThresholdStillCountsAsActive() {
        run(60, activity: Activity(idleSeconds: 299, isLocked: false))
        XCTAssertFalse(scheduler.isIdle)
        XCTAssertEqual(scheduler.remaining, 25 * 60 - 60, accuracy: 1)
    }

    func testTheBlockOnlyCountsActiveTime() {
        run(10 * 60)
        run(20 * 60, activity: Activity(idleSeconds: 3600, isLocked: false))
        run(10 * 60)
        // 10 active minutes, 5 idle minutes taken off, then 10 active minutes: 10 are left.
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertEqual(scheduler.remaining, 10 * 60, accuracy: 1)
        run(10 * 60)
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    // MARK: wake-up → step 1 → step 2

    func testStartLaunchesStep1Of30Seconds() {
        run(25 * 60)
        scheduler.start()
        XCTAssertEqual(scheduler.phase, .step1)
        XCTAssertEqual(scheduler.remaining, 30, accuracy: 0.001)
    }

    func testStep1MovesToStep2ByItselfAfter30Seconds() {
        run(25 * 60)
        scheduler.start()
        let events = run(30)
        XCTAssertEqual(scheduler.phase, .step2)
        XCTAssertEqual(events, [.step2Started])
        XCTAssertEqual(scheduler.remaining, 30, accuracy: 0.001)
    }

    func testSkipStep1GoesToStep2WithoutWaiting() {
        run(25 * 60)
        scheduler.start()
        run(5)
        XCTAssertEqual(scheduler.skipStep1(), [.step2Started])
        XCTAssertEqual(scheduler.phase, .step2)
        XCTAssertEqual(scheduler.remaining, 30, accuracy: 0.001, "step 2 starts with its full length")
    }

    func testSkipStep1CannotFireTwiceNorOutsideStep1() {
        XCTAssertEqual(scheduler.skipStep1(), [], "from work")
        run(25 * 60)
        XCTAssertEqual(scheduler.skipStep1(), [], "from wake-up")
        scheduler.start()
        XCTAssertEqual(scheduler.skipStep1(), [.step2Started])
        XCTAssertEqual(scheduler.skipStep1(), [], "second click")
        run(30)
        XCTAssertEqual(scheduler.phase, .step2, "the old step 1 countdown does not fire again")
        XCTAssertEqual(scheduler.remaining, 0, accuracy: 0.001)
    }

    func testSkipStep1ThenDoneCountsAsACompletedBreak() {
        run(25 * 60)
        scheduler.start()
        var game = GameState()
        for e in scheduler.skipStep1() { _ = game.apply(e, now: TestCalendar.monday, calendar: TestCalendar.calendar) }
        XCTAssertEqual(game.progression.xp, 0, "skipping step 1 gives nothing by itself")
        for e in scheduler.finish() { _ = game.apply(e, now: TestCalendar.monday, calendar: TestCalendar.calendar) }
        XCTAssertEqual(game.progression.xp, 2_500, "same XP as a break whose step 1 ran its course")
    }

    func testStep1CountsEvenWithoutActivity() {
        run(25 * 60)
        scheduler.start()
        run(30, activity: Activity(idleSeconds: 3600, isLocked: false))
        XCTAssertEqual(scheduler.phase, .step2, "standing in front of the screen, the break moves on by itself")
    }

    func testStep2LastsThirtySecondsThenWaitsForDone() {
        run(25 * 60)
        scheduler.start()
        run(30)
        run(30)
        XCTAssertEqual(scheduler.phase, .step2)
        XCTAssertEqual(scheduler.remaining, 0, accuracy: 0.001)
    }

    func testFinishReturnsToWorkAndReportsTheCompletedBreak() {
        run(25 * 60)
        scheduler.start()
        run(50)
        let events = scheduler.finish()
        XCTAssertEqual(events, [.breakCompleted])
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 0.001)
    }

    func testFinishIsRefusedBeforeStep2() {
        run(25 * 60)
        XCTAssertEqual(scheduler.finish(), [])
        scheduler.start()
        XCTAssertEqual(scheduler.finish(), [])
        XCTAssertEqual(scheduler.phase, .step1)
    }

    // MARK: later

    func testSnoozePostponesBy5Minutes() {
        run(25 * 60)
        XCTAssertTrue(scheduler.snooze())
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertEqual(scheduler.remaining, 5 * 60, accuracy: 0.001)
        let events = run(5 * 60)
        XCTAssertEqual(events, [.wakeUp])
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    func testSnoozeIsLimitedToTwicePerBreak() {
        run(25 * 60)
        XCTAssertTrue(scheduler.snooze())
        run(5 * 60)
        XCTAssertTrue(scheduler.snooze())
        run(5 * 60)
        XCTAssertFalse(scheduler.canSnooze)
        XCTAssertFalse(scheduler.snooze())
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    func testSnoozesResetToZeroAfterABreak() {
        run(25 * 60)
        _ = scheduler.snooze()
        run(5 * 60)
        _ = scheduler.snooze()
        run(5 * 60)
        scheduler.start()
        run(50)
        _ = scheduler.finish()
        run(25 * 60)
        XCTAssertTrue(scheduler.canSnooze)
        XCTAssertEqual(scheduler.snoozeCount, 0)
    }

    // MARK: skip

    func testSkipReturnsToWorkAndReportsTheSkip() {
        run(25 * 60)
        let events = scheduler.skip()
        XCTAssertEqual(events, [.skipped])
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 0.001)
    }

    // MARK: manual trigger and time jump

    func testTriggerWakeUpFromWork() {
        run(60)
        XCTAssertEqual(scheduler.triggerWakeUp(), [.wakeUp])
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    func testTriggerWakeUpIsIgnoredWhileABreakIsRunning() {
        run(25 * 60)
        scheduler.start()
        XCTAssertEqual(scheduler.triggerWakeUp(), [])
        XCTAssertEqual(scheduler.phase, .step1)
    }

    func testAdvancing25MinutesTriggersTheWakeUp() {
        clock.advance(25 * 60)
        let events = scheduler.tick(.active)
        XCTAssertEqual(events, [.wakeUp])
    }

    func testResyncIgnoresAClockJump() {
        clock.advance(24 * 3600)
        scheduler.resync()
        XCTAssertEqual(scheduler.tick(.active), [])
        XCTAssertEqual(scheduler.phase, .work)
    }

    func testCompleteNowWorksFromAnyState() {
        XCTAssertEqual(scheduler.completeNow(), [.breakCompleted])
        XCTAssertEqual(scheduler.phase, .work)
    }
}
