import XCTest
@testable import Stretchu

final class ExercisePickerTests: XCTestCase {
    private func exercise(_ id: String) -> Exercise {
        Exercise(id: id, name: id, steps: ["a"])
    }

    private lazy var catalog = [exercise("a"), exercise("b"), exercise("c")]

    private func pick(excluded: Set<String> = [], already: Set<String> = [], different: String? = nil) -> Exercise {
        ExerciseCatalog.pick(from: catalog, excluded: excluded, alreadyPicked: already, different: different)
    }

    func testTheBuiltInFallbackHasThreeTextExercises() {
        XCTAssertEqual(ExerciseCatalog.builtIn.count, 3)
        for e in ExerciseCatalog.builtIn {
            XCTAssertLessThanOrEqual(e.steps.count, 3)
            XCTAssertTrue(e.images.isEmpty)
        }
    }

    func testEveryExerciseOfTheCatalogCanBeDrawn() {
        var seen = Set<String>()
        for _ in 0..<300 { seen.insert(pick().id) }
        XCTAssertEqual(seen, ["a", "b", "c"])
    }

    // MARK: exclusions and history

    func testPickExcludesHiddenExercises() {
        for _ in 0..<30 { XCTAssertEqual(pick(excluded: ["a", "b"]).id, "c") }
    }

    func testNoRepeatWithinTheDay() {
        var already = Set<String>()
        for _ in 0..<3 {
            let picked = pick(already: already)
            XCTAssertFalse(already.contains(picked.id), "\(picked.id) already picked today")
            already.insert(picked.id)
        }
        XCTAssertEqual(already.count, 3)
    }

    func testEverythingAlreadyPickedStartsOverWithoutBlocking() {
        XCTAssertTrue(["a", "b", "c"].contains(pick(already: ["a", "b", "c"]).id))
    }

    func testAnotherExerciseDiffersFromTheCurrentOne() {
        for _ in 0..<50 { XCTAssertNotEqual(pick(different: "a").id, "a") }
    }

    func testEverythingHiddenStillGivesSomethingAvailable() {
        let picked = pick(excluded: ["a", "b", "c"])
        XCTAssertTrue(["a", "b", "c"].contains(picked.id))
    }

    func testTheRealCatalogAlwaysGivesSomething() throws {
        for _ in 0..<200 {
            let e = ExerciseCatalog.pick(excluded: [], alreadyPicked: [], different: nil)
            XCTAssertTrue(ExerciseCatalog.english.contains { $0.id == e.id }, e.id)
        }
    }

    // MARK: daily history

    func testDailyHistoryEmptiesOnTheDayChange() {
        let cal = TestCalendar.calendar
        var h = DailyPicks()
        h.record("a", now: TestCalendar.monday, calendar: cal)
        h.record("b", now: TestCalendar.monday, calendar: cal)
        XCTAssertEqual(h.ids(for: TestCalendar.monday, calendar: cal), ["a", "b"])
        XCTAssertEqual(h.ids(for: TestCalendar.tuesday, calendar: cal), [])
        h.record("c", now: TestCalendar.tuesday, calendar: cal)
        XCTAssertEqual(h.ids(for: TestCalendar.tuesday, calendar: cal), ["c"])
    }

    func testAnOldStateWithoutHistoryStillDecodes() throws {
        let json = #"{"exercicesExclus":[],"progression":{"cyclesTermines":0,"hallOfFame":[],"xp":10},"schemaVersion":1,"streak":{"pausesDuJour":0,"serie":0}}"#
        let game = try StateStore.decoder.decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(game.progression.xp, XPRules.migratedXP(fromLegacy: 10), "old XP is recomputed on the new curve")
        XCTAssertTrue(game.dailyPicks.ids.isEmpty)
    }
}
