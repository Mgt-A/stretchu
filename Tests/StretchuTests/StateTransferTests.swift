import XCTest
@testable import Stretchu

final class StateTransferTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-transfer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
    }

    private func richState() throws -> GameState {
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent("hall-of-fame-4-cycles.json"))
        var game = try StateStore.decoder.decode(GameState.self, from: data)
        game.streak = Streak(count: 7, breaksToday: 2, currentDay: TestCalendar.calendar.startOfDay(for: TestCalendar.monday))
        return game
    }

    @MainActor
    func testExportThenImportRestoresLevelStreakCyclesAndPokedex() throws {
        let game = try richState()
        XCTAssertGreaterThan(game.progression.cycles.count, 1)
        let source = StateStore(directory: dir.appendingPathComponent("mac-a"))
        try source.save(game)
        let file = dir.appendingPathComponent(StateTransfer.fileName)
        try source.export(to: file, fallback: GameState())

        let imported = try StateTransfer.read(from: file)
        XCTAssertEqual(imported.game, game)
        XCTAssertEqual(imported.game.progression.level, game.progression.level)
        XCTAssertEqual(imported.game.streak.count, 7)
        XCTAssertEqual(imported.game.progression.cycles, game.progression.cycles)

        // The other Mac: its own state is replaced, and survives a restart.
        let target = StateStore(directory: dir.appendingPathComponent("mac-b"))
        try target.save(GameState())
        let model = AppModel(store: target)
        model.importState(imported)
        XCTAssertEqual(model.game.progression, game.progression)
        XCTAssertEqual(model.game.streak.count, 7)
        XCTAssertEqual(StateStore(directory: target.directory).load().progression, game.progression)
    }

    func testExportWithoutAStoredFileWritesTheGivenState() throws {
        let file = dir.appendingPathComponent("out.json")
        let game = try richState()
        try StateStore(directory: dir.appendingPathComponent("empty")).export(to: file, fallback: game)
        XCTAssertEqual(try StateTransfer.read(from: file).game, game)
    }

    func testCorruptFileIsRefused() {
        XCTAssertThrowsError(try StateTransfer.validate(Data("{ not json".utf8))) {
            XCTAssertEqual($0 as? StateTransferError, .unreadable)
        }
        XCTAssertThrowsError(try StateTransfer.validate(Data())) {
            XCTAssertEqual($0 as? StateTransferError, .unreadable)
        }
    }

    func testValidJsonThatIsNotAStateIsRefused() {
        for json in ["{}", "[1, 2]", #"{"progression": 3}"#, #"{"progression": {"xp": "lots"}}"#] {
            XCTAssertThrowsError(try StateTransfer.validate(Data(json.utf8)), json) {
                XCTAssertEqual($0 as? StateTransferError, .notAState, json)
            }
        }
    }

    func testStateFromANewerBuildIsRefused() throws {
        let newer = GameState.currentSchemaVersion + 1
        let json = #"{"schemaVersion": \#(newer), "progression": {}}"#
        XCTAssertThrowsError(try StateTransfer.validate(Data(json.utf8))) {
            XCTAssertEqual($0 as? StateTransferError, .newerVersion(newer))
        }
    }

    func testMissingFileIsRefused() {
        XCTAssertThrowsError(try StateTransfer.read(from: dir.appendingPathComponent("nope.json"))) {
            XCTAssertEqual($0 as? StateTransferError, .unreadable)
        }
    }

    func testEveryOldFormatFixtureIsAcceptedThroughTheMigration() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: fixturesDir.path).filter { $0.hasSuffix(".json") }
        XCTAssertFalse(names.isEmpty)
        for name in names {
            let data = try Data(contentsOf: fixturesDir.appendingPathComponent(name))
            let imported = try StateTransfer.validate(data)
            XCTAssertEqual(imported.game, try StateStore.decoder.decode(GameState.self, from: data), name)
            XCTAssertEqual(imported.game.schemaVersion, GameState.currentSchemaVersion, name)
        }
    }
}
