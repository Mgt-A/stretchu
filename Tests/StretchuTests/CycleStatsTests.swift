import XCTest
@testable import Stretchu

final class CycleStatsTests: XCTestCase {
    private let cal = TestCalendar.calendar

    func testBreaksSkipsAndDaysAreCountedInTheCurrentCycle() {
        var game = GameState()
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        _ = game.apply(.skipped, now: TestCalendar.monday, calendar: cal)
        _ = game.apply(.breakCompleted, now: TestCalendar.tuesday, calendar: cal)
        let stats = game.progression.current.stats
        XCTAssertEqual(stats?.breaks, 3)
        XCTAssertEqual(stats?.skips, 1)
        XCTAssertEqual(stats?.activeDays, 2)
        XCTAssertEqual(stats?.bestDay, 2)
        XCTAssertEqual(stats?.bestStreak, 2, "the skip reset the streak, the best one stays")
        XCTAssertEqual(stats?.skipRate ?? 0, 0.25, accuracy: 0.001)
    }

    func testABreakOutsideActiveHoursCountsButItsSkipDoesNot() {
        var game = GameState()
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal, outsideHours: true)
        _ = game.apply(.skipped, now: TestCalendar.monday, calendar: cal, outsideHours: true)
        XCTAssertEqual(game.progression.current.stats?.breaks, 1)
        XCTAssertEqual(game.progression.current.stats?.skips, 0)
        XCTAssertEqual(game.progression.current.stats?.bestStreak, 0, "the streak did not move")
    }

    func testAnOldCycleHasNoStatsAndTheFirstEventStartsCounting() throws {
        let json = #"{"lineId":"pikachu","shiny":false,"reachedDexes":[25]}"#.data(using: .utf8)!
        let old = try JSONDecoder().decode(Cycle.self, from: json)
        XCTAssertNil(old.stats)

        var game = GameState()
        game.progression.current.stats = nil
        _ = game.apply(.skipped, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game.progression.current.stats?.skips, 1)
    }

    func testTheCycleEndingBreakIsCountedAndTheNextCycleStartsAtZero() {
        var game = GameState()
        game.progression.xp = XPRules.maxXP - 1
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game.progression.cycles.count, 2)
        XCTAssertEqual(game.progression.cycles[0].stats?.breaks, 1)
        XCTAssertEqual(game.progression.current.stats, CycleStats())
    }

    func testStatsSurviveEncodingAndAbandonStartsAFreshCount() throws {
        var game = GameState()
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        let back = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(back.progression.current.stats, game.progression.current.stats)
        game.abandonCurrentCycle(now: TestCalendar.tuesday)
        XCTAssertEqual(game.progression.current.stats, CycleStats())
    }
}
