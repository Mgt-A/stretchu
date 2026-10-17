import XCTest
@testable import Stretchu

final class StreakTests: XCTestCase {
    let cal = TestCalendar.calendar

    private func streak(count: Int, breaks: Int, day: Date) -> Streak {
        Streak(count: count, breaksToday: breaks, currentDay: cal.startOfDay(for: day))
    }

    // MARK: multiplier min(5, 1 + streak)

    func testMultiplierForStreak0() { XCTAssertEqual(Streak.multiplier(forStreak: 0), 1.0, accuracy: 1e-9) }
    func testMultiplierForStreak1() { XCTAssertEqual(Streak.multiplier(forStreak: 1), 2.0, accuracy: 1e-9) }
    func testMultiplierForStreak2() { XCTAssertEqual(Streak.multiplier(forStreak: 2), 3.0, accuracy: 1e-9) }
    func testMultiplierForStreak4() { XCTAssertEqual(Streak.multiplier(forStreak: 4), 5.0, accuracy: 1e-9) }
    func testMultiplierCapsAt5() { XCTAssertEqual(Streak.multiplier(forStreak: 60), 5.0, accuracy: 1e-9) }

    func testTheFifthBreakIsTheFirstAtX5() {
        var game = GameState()
        game.streak = Streak(count: 0, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.monday))
        var multipliers: [Double] = []
        for _ in 0..<6 {
            for case let .xpGained(_, multiplier) in game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal) {
                multipliers.append(multiplier)
            }
        }
        XCTAssertEqual(multipliers, [1, 2, 3, 4, 5, 5])
    }

    // MARK: XP = base × multiplier

    func testXPFollowsTheMultiplier() {
        XCTAssertEqual(Streak.earnedXP(base: 200, streak: 0), 200)
        XCTAssertEqual(Streak.earnedXP(base: 200, streak: 1), 400)
        XCTAssertEqual(Streak.earnedXP(base: 200, streak: 2), 600)
        XCTAssertEqual(Streak.earnedXP(base: 200, streak: 4), 1000)
        XCTAssertEqual(Streak.earnedXP(base: 200, streak: 60), 1000)
    }

    func testAppliedMultiplierIsTheOneFromBeforeTheIncrement() {
        var game = GameState()
        game.streak = streak(count: 1, breaks: 0, day: TestCalendar.monday)
        let events = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game.progression.xp, 5_000, "streak 1 → ×2 applied before the +1")
        XCTAssertEqual(game.streak.count, 2)
        XCTAssertTrue(events.contains(.xpGained(5_000, multiplier: 2.0)))
    }

    func testCompletedBreakIncrementsStreakAndBreaksToday() {
        var s = streak(count: 0, breaks: 0, day: TestCalendar.monday)
        s.completeBreak()
        s.completeBreak()
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.breaksToday, 2)
    }

    // MARK: skip

    func testSkipResetsTheStreakToZero() {
        var game = GameState()
        game.streak = streak(count: 12, breaks: 3, day: TestCalendar.monday)
        let xpBefore = game.progression.xp
        _ = game.apply(.skipped, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game.streak.count, 0)
        XCTAssertEqual(game.progression.xp, xpBefore, "a skip gives no XP")
        XCTAssertEqual(game.streak.breaksToday, 3, "breaks already done stay counted")
    }

    // MARK: snooze has no effect

    func testSnoozeTouchesNeitherTheStreakNorXP() {
        var game = GameState()
        game.streak = streak(count: 7, breaks: 2, day: TestCalendar.monday)
        let before = game
        _ = game.apply(.snoozed, now: TestCalendar.monday, calendar: cal)
        _ = game.apply(.wakeUp, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game, before)
    }

    // MARK: day change

    func testEndOfDayWith4BreaksResetsTheStreak() {
        var s = streak(count: 15, breaks: 4, day: TestCalendar.monday)
        s.sync(now: TestCalendar.tuesday, calendar: cal)
        XCTAssertEqual(s.count, 0)
        XCTAssertEqual(s.breaksToday, 0)
    }

    func testEndOfDayWith5BreaksKeepsTheStreak() {
        var s = streak(count: 15, breaks: 5, day: TestCalendar.monday)
        s.sync(now: TestCalendar.tuesday, calendar: cal)
        XCTAssertEqual(s.count, 15)
        XCTAssertEqual(s.breaksToday, 0, "the day's counter starts over at 0")
    }

    func testSameDayChangesNothing() {
        var s = streak(count: 15, breaks: 2, day: TestCalendar.monday)
        s.sync(now: TestCalendar.date(2026, 10, 19, 23, 59), calendar: cal)
        XCTAssertEqual(s.count, 15)
        XCTAssertEqual(s.breaksToday, 2)
    }

    func testFridayWith5ThenMondayKeepsTheStreak() {
        var s = streak(count: 20, breaks: 5, day: TestCalendar.friday)
        s.sync(now: TestCalendar.nextMonday, calendar: cal)
        XCTAssertEqual(s.count, 20, "Saturday and Sunday are ignored")
    }

    func testFridayWith4ThenMondayResetsTheStreak() {
        var s = streak(count: 20, breaks: 4, day: TestCalendar.friday)
        s.sync(now: TestCalendar.nextMonday, calendar: cal)
        XCTAssertEqual(s.count, 0)
    }

    func testWeekendBreaksDoNotPenalize() {
        var s = streak(count: 20, breaks: 1, day: TestCalendar.saturday)
        s.sync(now: TestCalendar.nextMonday, calendar: cal)
        XCTAssertEqual(s.count, 20, "a Saturday with 1 break is not evaluated")
    }

    func testNoBreakOnTheWeekendNeverPenalizes() {
        var s = streak(count: 20, breaks: 0, day: TestCalendar.saturday)
        s.sync(now: TestCalendar.sunday, calendar: cal)
        s.sync(now: TestCalendar.nextMonday, calendar: cal)
        XCTAssertEqual(s.count, 20)
    }

    func testMissedWorkdayResetsTheStreak() {
        // Monday with 5 breaks, Tuesday with none at all, back on Wednesday.
        var s = streak(count: 20, breaks: 5, day: TestCalendar.monday)
        s.sync(now: TestCalendar.wednesday, calendar: cal)
        XCTAssertEqual(s.count, 0)
    }

    func testWorkdayWithoutAnyBreakResetsTheStreak() {
        var s = streak(count: 20, breaks: 5, day: TestCalendar.monday)
        s.sync(now: TestCalendar.tuesday, calendar: cal)
        XCTAssertEqual(s.count, 20)
        s.sync(now: TestCalendar.wednesday, calendar: cal)
        XCTAssertEqual(s.count, 0, "Tuesday has no break")
    }

    func testFridayBeforeALongWeekendDoesNotSkipAWorkday() {
        // Friday with 5 breaks, back on Tuesday: Monday is missed.
        var s = streak(count: 20, breaks: 5, day: TestCalendar.friday)
        s.sync(now: TestCalendar.date(2026, 10, 27), calendar: cal)
        XCTAssertEqual(s.count, 0)
    }

    func testFirstLaunchAdoptsTheDayWithoutPenalty() {
        var s = Streak(count: 5, breaksToday: 0, currentDay: nil)
        s.sync(now: TestCalendar.wednesday, calendar: cal)
        XCTAssertEqual(s.count, 5)
        XCTAssertEqual(s.currentDay, cal.startOfDay(for: TestCalendar.wednesday))
    }

    func testNextWorkdaySkipsTheWeekend() {
        XCTAssertEqual(cal.nextWorkday(after: TestCalendar.friday), cal.date(bySettingHour: 9, minute: 0, second: 0, of: TestCalendar.nextMonday))
        XCTAssertEqual(cal.nextWorkday(after: TestCalendar.saturday), cal.date(bySettingHour: 9, minute: 0, second: 0, of: TestCalendar.nextMonday))
        XCTAssertEqual(cal.nextWorkday(after: TestCalendar.monday), cal.date(bySettingHour: 9, minute: 0, second: 0, of: TestCalendar.tuesday))
    }
}
