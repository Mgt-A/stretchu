import XCTest
@testable import Stretchu

/// Calibration: 2,500 XP per break, level 100 at 1,000,000 XP.
/// 10 breaks per workday at ×5 reach level 100 on the 8th day (8.0 days).
final class ProgressionCalibrationTests: XCTestCase {
    private let cal = TestCalendar.calendar

    private struct Day { var day: Int; var fraction: Double }

    /// Plays workdays of 10 breaks, from a streak of `startStreak`.
    /// Returns the first (day, fraction of that day) at which each level was reached.
    private func simulate(startStreak: Int, levels: [Int], line: PokemonLine = .pikachu) -> [Int: Day] {
        var game = GameState()
        game.pokemon = CurrentPokemon(lineId: line.id)
        game.streak = Streak(count: startStreak, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.monday))
        var reached: [Int: Day] = [:]
        var date = TestCalendar.monday
        for day in 1...40 {
            while !cal.isWorkday(date) { date = cal.date(byAdding: .day, value: 1, to: date)! }
            for step in 0..<10 {
                _ = game.apply(.breakCompleted, now: date, calendar: cal, random: { 1 })
                if game.progression.completedCycles > 0 {
                    reached[100] = reached[100] ?? Day(day: day, fraction: Double(step + 1) / 10)
                    return reached
                }
                for level in levels where reached[level] == nil && game.progression.level >= level {
                    reached[level] = Day(day: day, fraction: Double(step + 1) / 10)
                }
            }
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        return reached
    }

    func testLevel100IsReachedOnTheEighthWorkdayAtX5() {
        let reached = simulate(startStreak: 40, levels: [])
        let day = reached[100]
        XCTAssertEqual(day?.day, 8)
        let days = Double((day?.day ?? 0) - 1) + (day?.fraction ?? 0)
        XCTAssertEqual(days, 8.0, accuracy: 0.15, "about 8 workdays at ×5")
    }

    func testTheDailyXPAtX5() {
        // 10 × 2,500 × 5 = 125,000 XP a day.
        var game = GameState()
        game.streak = Streak(count: 40, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.monday))
        for _ in 0..<10 {
            _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        }
        XCTAssertEqual(game.progression.xp, 125_000)
    }

    func testEvolutionDays() {
        let reached = simulate(startStreak: 40, levels: [10, 33, 50, 66])
        func days(_ level: Int) -> Double { Double(reached[level]!.day - 1) + reached[level]!.fraction }
        XCTAssertEqual(days(10), 0.1, accuracy: 0.1, "level 10 on the first day")
        XCTAssertEqual(days(33), 0.8, accuracy: 0.15)
        XCTAssertEqual(days(50), 2.0, accuracy: 0.15)
        XCTAssertEqual(days(66), 3.5, accuracy: 0.15)
    }

    func testFromAStreakOfZeroItTakesLonger() {
        let reached = simulate(startStreak: 0, levels: [])
        let day = reached[100]?.day ?? 0
        XCTAssertTrue((9...10).contains(day), "about 9.6 days from a streak of 0 (the multiplier has to climb): day \(day)")
    }

    func testTheNextCycleKeepsTheStreakSoItIsFasterThanTheFirst() {
        // A second cycle starts at ×5 (the streak survives): 8 days, not 9.6.
        var game = GameState()
        game.progression = Progression(xp: 999_999)
        game.streak = Streak(count: 40, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.monday))
        _ = game.apply(.breakCompleted, now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(game.progression.completedCycles, 1)
        XCTAssertEqual(game.streak.multiplier, 5.0, accuracy: 1e-9)
    }
}
