import XCTest
@testable import Stretchu

final class ExercisePickerTests: XCTestCase {
    private func exercise(_ id: String, equipment: String? = nil) -> Exercise {
        Exercise(id: id, name: id, steps: ["a"], equipment: equipment)
    }

    private lazy var catalog = [exercise("a"), exercise("b"), exercise("c", equipment: "body only"),
                                exercise("band", equipment: "bands"), exercise("roller", equipment: "foam roll")]

    private func pick(owned: Set<String> = [], program: Program? = nil, excluded: Set<String> = [],
                      already: Set<String> = [], different: String? = nil) -> Exercise {
        ExerciseCatalog.pick(from: catalog, program: program, equipment: owned, excluded: excluded,
                             alreadyPicked: already, different: different)
    }

    func testTheBuiltInFallbackHasThreeTextExercises() {
        XCTAssertEqual(ExerciseCatalog.builtIn.count, 3)
        for e in ExerciseCatalog.builtIn {
            XCTAssertLessThanOrEqual(e.steps.count, 3)
            XCTAssertTrue(e.images.isEmpty)
        }
    }

    // MARK: equipment

    func testExercisesWithoutEquipmentAreAlwaysAvailable() {
        XCTAssertTrue(Equipment.isAvailable(nil, owned: []))
        XCTAssertTrue(Equipment.isAvailable("body only", owned: []))
        XCTAssertFalse(Equipment.isAvailable("bands", owned: []))
        XCTAssertTrue(Equipment.isAvailable("bands", owned: ["bands"]))
        XCTAssertFalse(Equipment.isAvailable("foam roll", owned: ["bands"]))
    }

    func testWithoutEquipmentOnlyBodyweightExercisesAreDrawn() {
        var seen = Set<String>()
        for _ in 0..<300 { seen.insert(pick().id) }
        XCTAssertEqual(seen, ["a", "b", "c"])
    }

    func testOwnedEquipmentOpensItsExercises() {
        var seen = Set<String>()
        for _ in 0..<500 { seen.insert(pick(owned: ["bands"]).id) }
        XCTAssertEqual(seen, ["a", "b", "c", "band"])
        seen = []
        for _ in 0..<500 { seen.insert(pick(owned: ["bands", "foam roll"]).id) }
        XCTAssertEqual(seen, ["a", "b", "c", "band", "roller"])
    }

    func testHomeAndOfficeHaveTheirOwnEquipment() {
        var settings = UserSettings()
        settings.homeEquipment = ["bands"]
        XCTAssertEqual(settings.equipment(for: .home), ["bands"])
        XCTAssertEqual(settings.equipment(for: .office), [])
        settings.officeEquipment = ["foam roll"]
        XCTAssertEqual(settings.equipment(for: .office), ["foam roll"])
    }

    func testTheEquipmentIsPersisted() throws {
        var game = GameState()
        game.settings.homeEquipment = ["bands", "foam roll"]
        game.settings.officeEquipment = ["exercise ball"]
        let decoded = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(decoded.settings.homeEquipment, ["bands", "foam roll"])
        XCTAssertEqual(decoded.settings.officeEquipment, ["exercise ball"])
    }

    // MARK: program

    func testOnlyTheProgramsExercisesAreDrawn() {
        let program = Program(name: "p", exercises: ["a", "band"])
        var seen = Set<String>()
        for _ in 0..<300 { seen.insert(pick(owned: ["bands"], program: program).id) }
        XCTAssertEqual(seen, ["a", "band"])
    }

    func testTheProgramsEquipmentExercisesNeedTheEquipment() {
        let program = Program(name: "p", exercises: ["a", "band"])
        for _ in 0..<100 { XCTAssertEqual(pick(program: program).id, "a") }
    }

    func testAProgramWhoseExercisesAreAllOutOfReachFallsBackToBodyweightOnes() {
        let program = Program(name: "p", exercises: ["band", "roller"])
        var seen = Set<String>()
        for _ in 0..<300 { seen.insert(pick(program: program).id) }
        XCTAssertEqual(seen, ["a", "b", "c"], "nothing in the program is available: bodyweight exercises of the catalog")
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
        let picked = pick(excluded: ["a", "b", "c", "band", "roller"])
        XCTAssertTrue(["a", "b", "c"].contains(picked.id), "no band exercise without a band, even as a last resort")
    }

    func testTheRealCatalogAlwaysGivesSomethingWithoutEquipment() throws {
        for _ in 0..<200 {
            let e = ExerciseCatalog.pick(equipment: [], excluded: [], alreadyPicked: [], different: nil)
            XCTAssertTrue(Equipment.isAvailable(e.equipment, owned: []), e.id)
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
