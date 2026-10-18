import XCTest
@testable import Stretchu

final class CandyTests: XCTestCase {
    let cal = TestCalendar.calendar

    private func game(streak: Int) -> GameState {
        var g = GameState()
        g.streak = Streak(count: streak, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.monday))
        return g
    }

    func testTheTwentyFifthBreakGivesACandy() {
        var g = game(streak: 24)
        let events = g.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(g.candies, 1)
        XCTAssertTrue(events.contains(.candyEarned))
    }

    func testTheThresholdRepeats() {
        var g = game(streak: 49)
        _ = g.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(g.candies, 1, "the 50th")
    }

    func testOtherBreaksGiveNone() {
        var g = game(streak: 10)
        let events = g.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(g.candies, 0)
        XCTAssertFalse(events.contains(.candyEarned))
    }

    func testABreakOutsideTheActiveHoursDoesNotCount() {
        var g = game(streak: 24)
        _ = g.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal, outsideHours: true)
        XCTAssertEqual(g.streak.count, 24)
        XCTAssertEqual(g.candies, 0)
    }

    func testASkipRestartsTheCountTowardsTheNextCandy() {
        var g = game(streak: 24)
        _ = g.apply(.skipped, now: TestCalendar.monday, calendar: cal)
        _ = g.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(g.candies, 0)
    }

    func testACandyIsOneLevel() {
        var g = GameState()
        g.candies = 2
        g.progression.xp = XPRules.totalXP(forLevel: 10) + 123
        let events = g.useCandy(now: TestCalendar.monday)
        XCTAssertEqual(g.progression.level, 11)
        XCTAssertEqual(g.progression.xp, XPRules.totalXP(forLevel: 11))
        XCTAssertEqual(g.candies, 1)
        XCTAssertTrue(events.contains(.leveledUp(from: 10, to: 11)))
    }

    func testNoCandyNoLevel() {
        var g = GameState()
        XCTAssertEqual(g.useCandy(now: TestCalendar.monday), [])
        XCTAssertEqual(g.progression.level, 1)
    }

    func testACandyAtLevel99EndsTheCycle() {
        var g = GameState()
        g.candies = 1
        g.progression.xp = XPRules.totalXP(forLevel: 99)
        _ = g.useCandy(now: TestCalendar.monday)
        XCTAssertEqual(g.progression.completedCycles, 1)
        XCTAssertEqual(g.progression.level, 1)
    }

    func testCandiesSurviveEncodingAndOldStatesHaveNone() throws {
        var g = GameState()
        g.candies = 3
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(back.candies, 3)
        let old = try JSONDecoder().decode(GameState.self, from: Data("{}".utf8))
        XCTAssertEqual(old.candies, 0)
    }
}
