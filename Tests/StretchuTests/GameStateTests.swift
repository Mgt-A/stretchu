import XCTest
@testable import Stretchu

final class GameStateTests: XCTestCase {
    let cal = TestCalendar.calendar

    func testCompletedBreakGives2500XPWithoutAStreak() {
        var game = GameState()
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game.progression.xp, 2_500)
        XCTAssertEqual(game.streak.count, 1)
        XCTAssertEqual(game.streak.breaksToday, 1)
    }

    func testTwoBreaksInARowUseTheCurrentMultiplier() {
        var game = GameState()
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)   // 2,500 (×1)
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)   // 5,000 (×2)
        XCTAssertEqual(game.progression.xp, 7_500)
    }

    func testTheDaySyncsBeforeTheBreak() {
        var game = GameState()
        game.streak = Streak(count: 9, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.monday))
        // Tuesday: Monday had no break, the streak falls before the new break.
        _ = game.apply(.breakCompleted, now: TestCalendar.tuesday, calendar: cal)
        XCTAssertEqual(game.streak.count, 1)
        XCTAssertEqual(game.progression.xp, 2_500)
    }

    func testJSONEncodingRoundTrip() throws {
        var game = GameState()
        game.progression = Progression(xp: 12_345, cycles: [
            Cycle(lineId: "pikachu", startedAt: TestCalendar.sunday, endedAt: TestCalendar.monday, shiny: true, reachedDexes: [25, 26]),
            Cycle(lineId: "charmander", startedAt: TestCalendar.monday, branchDex: nil, reachedDexes: [4]),
        ])
        game.streak = Streak(count: 4, breaksToday: 2, currentDay: cal.startOfDay(for: TestCalendar.monday))
        game.excludedExercises = ["slow-breathing"]
        let data = try StateStore.encoder.encode(game)
        let decoded = try StateStore.decoder.decode(GameState.self, from: data)
        XCTAssertEqual(decoded, game)
    }
}

final class MoodTests: XCTestCase {
    func testMoodFollowsTheMultiplier() {
        XCTAssertEqual(Mood.forStreak(0, asleep: false), .idle)
        XCTAssertEqual(Mood.forStreak(3, asleep: false), .idle, "×4")
        XCTAssertEqual(Mood.forStreak(4, asleep: false), .hop, "×5 and above: it hops")
        XCTAssertEqual(Mood.forStreak(100, asleep: false), .hop)
        XCTAssertEqual(Mood.forStreak(100, asleep: true), .sleep, "outside the hours it sleeps, whatever the streak")
    }

    func testASkipHurtsUntilTheNextCompletedBreak() {
        XCTAssertEqual(Mood.forStreak(0, asleep: false, skipped: true), .hurt)
        XCTAssertEqual(Mood.forStreak(7, asleep: false, skipped: true), .hurt, "it wins over the hop")
        XCTAssertEqual(Mood.forStreak(0, asleep: true, skipped: true), .sleep, "asleep still wins outside the hours")
        XCTAssertEqual(Mood.hurt.animationName, "Hurt")

        var streak = Streak(count: 3)
        streak.skip()
        XCTAssertTrue(streak.skippedSinceBreak)
        streak.completeBreak()
        XCTAssertFalse(streak.skippedSinceBreak)
        XCTAssertEqual(Mood.forStreak(streak.count, asleep: false, skipped: streak.skippedSinceBreak), .idle)
    }

    func testAnOldStreakWithoutTheSkipFlagDecodes() throws {
        let streak = try JSONDecoder().decode(Streak.self, from: Data(#"{"count":2,"breaksToday":1}"#.utf8))
        XCTAssertEqual(streak.count, 2)
        XCTAssertFalse(streak.skippedSinceBreak)
    }
}
