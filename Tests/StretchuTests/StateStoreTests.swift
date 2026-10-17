import XCTest
@testable import Stretchu

final class StateStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileGivesAFreshState() {
        let store = StateStore(directory: dir)
        XCTAssertEqual(store.load(), GameState())
    }

    func testSaveThenReload() throws {
        let store = StateStore(directory: dir)
        var game = GameState()
        game.progression = Progression(xp: 4_242)
        game.streak = Streak(count: 6, breaksToday: 1, currentDay: TestCalendar.calendar.startOfDay(for: TestCalendar.monday))
        try store.save(game)
        // Another StateStore on the same folder = an app restart.
        XCTAssertEqual(StateStore(directory: dir).load(), game)
    }

    func testCorruptFileIsSetAsideAndReplacedByAFreshState() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("state.json"))
        let store = StateStore(directory: dir)
        XCTAssertEqual(store.load(), GameState())
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(leftovers.contains { $0.hasPrefix("state.corrupt") })
    }

    func testSavedFileUsesTheEnglishKeysOnly() throws {
        let store = StateStore(directory: dir)
        var game = GameState()
        game.streak = Streak(count: 4, breaksToday: 2, currentDay: TestCalendar.calendar.startOfDay(for: TestCalendar.monday))
        game.excludedExercises = ["Chin_Tucks"]
        game.networks = ["Home-5G": .home]
        try store.save(game)
        let json = try String(contentsOf: store.fileURL, encoding: .utf8)
        for key in ["schemaVersion", "cycles", "lineId", "breaksToday", "currentDay", "excludedExercises",
                    "dailyPicks", "networks", "settings", "workMinutes", "snoozeMinutes", "defaultMode"] {
            XCTAssertTrue(json.contains("\"\(key)\""), key)
        }
        for oldKey in ["cyclesTermines", "completedCycles", "hallOfFame", "pausesDuJour", "jourCourant", "serie", "exercicesExclus",
                       "exercicesDuJour", "reseaux", "reglages", "travailMinutes", "reportMinutes", "modeParDefaut"] {
            XCTAssertFalse(json.contains("\"\(oldKey)\""), oldKey)
        }
    }
}
