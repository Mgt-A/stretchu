import XCTest
@testable import Stretchu

final class StreakWeekTests: XCTestCase {
    let cal = TestCalendar.calendar
    let letters = ["L", "M", "M", "J", "V", "S", "D"]

    func testHistoryKeepsTheDayThatEnds() {
        var s = Streak(count: 5, breaksToday: 6, currentDay: cal.startOfDay(for: TestCalendar.monday))
        s.sync(now: TestCalendar.tuesday, calendar: cal)
        XCTAssertEqual(s.history.map(\.breaks), [6])
        XCTAssertEqual(s.history.first?.day, cal.startOfDay(for: TestCalendar.monday))
    }

    func testHistoryIsLimitedTo14Days() {
        var s = Streak(count: 0, breaksToday: 5, currentDay: cal.startOfDay(for: TestCalendar.monday))
        var day = TestCalendar.monday
        for _ in 0..<30 {
            day = cal.date(byAdding: .day, value: 1, to: day)!
            s.sync(now: day, calendar: cal)
            s.breaksToday = 5
        }
        XCTAssertLessThanOrEqual(s.history.count, 14)
    }

    func testThursdaysWeekWithTwoMetDays() {
        var s = Streak(count: 15, breaksToday: 7, currentDay: cal.startOfDay(for: TestCalendar.monday))
        s.sync(now: TestCalendar.tuesday, calendar: cal)      // Monday: 7
        s.breaksToday = 5
        s.sync(now: TestCalendar.wednesday, calendar: cal)    // Tuesday: 5
        s.breaksToday = 0
        s.sync(now: TestCalendar.thursday, calendar: cal)     // Wednesday: 0
        s.breaksToday = 3
        let week = s.week(now: TestCalendar.thursday, calendar: cal, letters: letters)
        XCTAssertEqual(week.map(\.letter), ["L", "M", "M", "J", "V", "S", "D"])
        XCTAssertEqual(week.map(\.state), [.met, .met, .missed, .today, .upcoming, .weekend, .weekend])
        XCTAssertEqual(week[3].breaks, 3)
    }

    func testAWeekendDayTodayIsMarked() {
        var s = Streak(count: 3, breaksToday: 1, currentDay: cal.startOfDay(for: TestCalendar.saturday))
        s.sync(now: TestCalendar.saturday, calendar: cal)
        let week = s.week(now: TestCalendar.saturday, calendar: cal, letters: letters)
        XCTAssertEqual(week[5].state, .today)
        XCTAssertEqual(week[6].state, .weekend)
    }

    func testMondayOpensANewWeek() {
        let s = Streak(count: 3, breaksToday: 0, currentDay: cal.startOfDay(for: TestCalendar.nextMonday))
        let week = s.week(now: TestCalendar.nextMonday, calendar: cal, letters: letters)
        XCTAssertEqual(week[0].state, .today)
        XCTAssertEqual(week[1].state, .upcoming)
    }

    func testAnOldStreakWithoutHistoryDecodes() throws {
        let json = #"{"pausesDuJour":2,"serie":4}"#
        let s = try StateStore.decoder.decode(Streak.self, from: Data(json.utf8))
        XCTAssertEqual(s.count, 4)
        XCTAssertEqual(s.breaksToday, 2)
        XCTAssertTrue(s.history.isEmpty)
    }

    func testLinkedNetworksArePersisted() throws {
        var game = GameState()
        game.networks["Home-5G"] = .home
        game.networks["Office-Corp"] = .office
        let decoded = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(decoded.networks, game.networks)
    }
}
