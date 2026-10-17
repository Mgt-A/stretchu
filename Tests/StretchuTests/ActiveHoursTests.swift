import XCTest
@testable import Stretchu

final class ActiveHoursTests: XCTestCase {
    private let cal = TestCalendar.calendar
    private var clock: FakeClock!
    private var scheduler: PauseScheduler!

    private func make(at date: Date, schedule: ActiveSchedule = ActiveSchedule()) {
        clock = FakeClock(date)
        var config = SchedulerConfig()
        config.schedule = schedule
        scheduler = PauseScheduler(config: config, clock: clock, calendar: cal)
    }

    @discardableResult
    private func run(_ seconds: Int, activity: Activity = .active) -> [SchedulerEvent] {
        var events: [SchedulerEvent] = []
        for _ in 0..<seconds {
            clock.advance(1)
            events += scheduler.tick(activity)
        }
        return events
    }

    // MARK: the schedule itself

    func testTheDefaultIsHalfPastEightToSixOnWeekdays() {
        let s = ActiveSchedule()
        XCTAssertEqual(s.startMinute, 8 * 60 + 30)
        XCTAssertEqual(s.endMinute, 18 * 60)
        XCTAssertEqual(s.days, [2, 3, 4, 5, 6])
    }

    func testTheStartIsIncludedAndTheEndIsNot() {
        let s = ActiveSchedule()
        XCTAssertFalse(s.isActive(at: TestCalendar.date(2026, 10, 19, 8, 29), calendar: cal))
        XCTAssertTrue(s.isActive(at: TestCalendar.date(2026, 10, 19, 8, 30), calendar: cal))
        XCTAssertTrue(s.isActive(at: TestCalendar.date(2026, 10, 19, 17, 59), calendar: cal))
        XCTAssertFalse(s.isActive(at: TestCalendar.date(2026, 10, 19, 18, 0), calendar: cal))
        XCTAssertFalse(s.isActive(at: TestCalendar.date(2026, 10, 24, 10, 0), calendar: cal), "Saturday")
    }

    func testTheNextOpening() {
        let s = ActiveSchedule()
        XCTAssertEqual(s.nextStart(after: TestCalendar.date(2026, 10, 19, 7, 0), calendar: cal), TestCalendar.date(2026, 10, 19, 8, 30), "today")
        XCTAssertEqual(s.nextStart(after: TestCalendar.date(2026, 10, 19, 19, 0), calendar: cal), TestCalendar.date(2026, 10, 20, 8, 30), "tomorrow")
        XCTAssertEqual(s.nextStart(after: TestCalendar.date(2026, 10, 23, 19, 0), calendar: cal), TestCalendar.date(2026, 10, 26, 8, 30), "Friday evening: Monday")
    }

    func testClampingKeepsQuarterHoursAndAnEndAfterTheStart() {
        let s = ActiveSchedule(startMinute: 8 * 60 + 37, endMinute: 8 * 60 + 40, days: []).clamped()
        XCTAssertEqual(s.startMinute % 15, 0)
        XCTAssertGreaterThan(s.endMinute, s.startMinute)
        XCTAssertEqual(s.days, ActiveSchedule.defaultDays, "no day at all falls back to the default")
    }

    func testAnOlderStateWithoutScheduleGetsTheDefault() throws {
        let settings = try JSONDecoder().decode(UserSettings.self, from: Data(#"{"workMinutes":30}"#.utf8))
        XCTAssertEqual(settings.schedule, ActiveSchedule())
        let round = try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(
            UserSettings(schedule: ActiveSchedule(startMinute: 540, endMinute: 1020, days: [2, 4]))))
        XCTAssertEqual(round.schedule, ActiveSchedule(startMinute: 540, endMinute: 1020, days: [2, 4]))
    }

    // MARK: the scheduler

    func testItNeverWakesUpOutsideTheHours() {
        make(at: TestCalendar.date(2026, 10, 19, 7, 0))
        XCTAssertEqual(run(60 * 60), [])
        XCTAssertTrue(scheduler.isOutsideHours)
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 0.001, "the counter did not move")
    }

    func testTheTimerStartsAtTheOpening() {
        make(at: TestCalendar.date(2026, 10, 19, 8, 0))
        XCTAssertEqual(run(30 * 60 + 25 * 60 - 1), [], "opening at 8:30, first wake-up not before 8:55")
        XCTAssertEqual(run(1), [.wakeUp])
        XCTAssertEqual(clock.now, TestCalendar.date(2026, 10, 19, 8, 55))
    }

    func testNoWakeUpAfterTheEnd() {
        make(at: TestCalendar.date(2026, 10, 19, 17, 40))
        XCTAssertEqual(run(30 * 60), [], "17:40 + 25 min is after 18:00: nothing")
        XCTAssertTrue(scheduler.isOutsideHours)
    }

    func testAWakeUpDueBeforeTheEndStillHappens() {
        make(at: TestCalendar.date(2026, 10, 19, 17, 30))
        XCTAssertEqual(run(25 * 60), [.wakeUp])
    }

    func testABreakInProgressAtTheEndFinishesNormally() {
        make(at: TestCalendar.date(2026, 10, 19, 17, 30))
        run(25 * 60)
        scheduler.start()
        clock.set(TestCalendar.date(2026, 10, 19, 18, 1))
        XCTAssertEqual(scheduler.phase, .step1)
        run(20)
        XCTAssertEqual(scheduler.phase, .step2)
        XCTAssertEqual(scheduler.finish(), [.breakCompleted])
        XCTAssertEqual(scheduler.phase, .work)
        XCTAssertTrue(scheduler.isOutsideHours)
    }

    func testItResumesOnTheNextActiveDay() {
        make(at: TestCalendar.date(2026, 10, 23, 17, 50)) // Friday
        run(20 * 60)
        clock.set(TestCalendar.date(2026, 10, 26, 8, 29)) // Monday, before the opening
        XCTAssertEqual(run(60), [], "the first tick of the morning only restarts the clock")
        XCTAssertFalse(scheduler.isOutsideHours)
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 1.5)
        XCTAssertEqual(run(25 * 60), [.wakeUp])
    }

    func testTheMorningAfterASleepingMacStartsAFreshBlock() {
        make(at: TestCalendar.date(2026, 10, 19, 17, 40))
        run(15 * 60) // 15 min worked, then the Mac sleeps
        clock.set(TestCalendar.date(2026, 10, 20, 9, 0))
        XCTAssertEqual(scheduler.tick(.active), [], "not 14 hours of work")
        XCTAssertEqual(scheduler.remaining, 25 * 60, accuracy: 0.001)
    }

    func testAnUncheckedDayBehavesLikeTheWeekend() {
        make(at: TestCalendar.date(2026, 10, 21, 10, 0), schedule: ActiveSchedule(days: [2, 3, 5, 6])) // Wednesday off
        XCTAssertEqual(run(60 * 60), [])
        XCTAssertTrue(scheduler.isOutsideHours)
    }

    func testAManualBreakOutsideTheHoursIsPossible() {
        make(at: TestCalendar.date(2026, 10, 19, 21, 0))
        XCTAssertEqual(scheduler.triggerWakeUp(), [.wakeUp])
        XCTAssertTrue(scheduler.breakStartedOutsideHours)
    }

    func testABreakStartedInsideTheHoursIsNotFlagged() {
        make(at: TestCalendar.date(2026, 10, 19, 10, 0))
        _ = scheduler.triggerWakeUp()
        XCTAssertFalse(scheduler.breakStartedOutsideHours)
    }

    // MARK: the streak

    func testAManualBreakOutsideTheHoursGivesXPWithTheMultiplierButTheStreakStays() {
        var game = GameState()
        game.streak = Streak(count: 1, breaksToday: 2, currentDay: cal.startOfDay(for: TestCalendar.monday))
        let events = game.apply(.breakCompleted, now: TestCalendar.date(2026, 10, 19, 21, 0), calendar: cal, outsideHours: true)
        XCTAssertEqual(game.progression.xp, 5_000, "2,500 × 2.0")
        XCTAssertTrue(events.contains(.xpGained(5_000, multiplier: 2.0)))
        XCTAssertEqual(game.streak.count, 1)
        XCTAssertEqual(game.streak.breaksToday, 2)
    }

    func testSkippingAManualBreakOutsideTheHoursBreaksNothing() {
        var game = GameState()
        game.streak = Streak(count: 1, breaksToday: 2, currentDay: cal.startOfDay(for: TestCalendar.monday))
        XCTAssertEqual(game.apply(.skipped, now: TestCalendar.date(2026, 10, 19, 21, 0), calendar: cal, outsideHours: true), [])
        XCTAssertEqual(game.streak.count, 1)
    }

    func testAnUncheckedDayNeitherCountsNorBreaksTheStreak() {
        let days: Set<Int> = [2, 3, 5, 6] // Wednesday off
        var s = Streak(count: 7, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.tuesday))
        s.breaksToday = 5
        s.sync(now: TestCalendar.wednesday, calendar: cal, days: days) // Tuesday was fine
        s.sync(now: TestCalendar.thursday, calendar: cal, days: days) // Wednesday: no breaks, but off
        XCTAssertEqual(s.count, 7)
        s.sync(now: TestCalendar.friday, calendar: cal, days: days) // Thursday: no breaks, active
        XCTAssertEqual(s.count, 0)
    }

    func testTheWeekRowShowsAnUncheckedDayAsOff() {
        var s = Streak(count: 1, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.thursday))
        s.sync(now: TestCalendar.thursday, calendar: cal, days: [2, 3, 5, 6])
        let week = s.week(now: TestCalendar.thursday, calendar: cal, days: [2, 3, 5, 6], letters: ["L", "M", "M", "J", "V", "S", "D"])
        XCTAssertEqual(week[2].state, .weekend)
    }

    // MARK: texts

    func testTheResumeText() {
        let friday = TestCalendar.date(2026, 10, 23, 19, 0)
        XCTAssertEqual(Format.clockTime(minute: 510, language: "fr"), "8 h 30")
        XCTAssertEqual(Format.clockTime(minute: 1080, language: "fr"), "18 h")
        XCTAssertEqual(Format.clockTime(minute: 510, language: "en"), "8:30 AM")
        XCTAssertEqual(Format.clockTime(minute: 1080, language: "en"), "6:00 PM")
        let tomorrow = TestCalendar.date(2026, 10, 24, 8, 30)
        XCTAssertEqual(Format.resume(at: tomorrow, from: friday, calendar: cal, language: "fr"), "Reprise demain à 8 h 30")
        XCTAssertEqual(Format.resume(at: tomorrow, from: friday, calendar: cal, language: "en"), "Resumes tomorrow at 8:30 AM")
        let monday = TestCalendar.date(2026, 10, 26, 8, 30)
        XCTAssertEqual(Format.resume(at: monday, from: friday, calendar: cal, language: "en", locale: Locale(identifier: "en")), "Resumes Monday at 8:30 AM")
        XCTAssertEqual(Format.resume(at: TestCalendar.date(2026, 10, 19, 8, 30), from: TestCalendar.date(2026, 10, 19, 7, 0), calendar: cal, language: "fr"), "Reprise à 8 h 30")
    }
}
