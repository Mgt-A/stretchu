import XCTest
@testable import Stretchu

/// A state written by an older build must survive: old keys are read, new keys written, the XP
/// is recomputed on the new curve keeping the level and the fraction of level, the old Hall of
/// Fame becomes Pikachu-line cycles.
final class MigrationTests: XCTestCase {
    private var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
    }

    private func fixtureNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: fixturesDir.path)
            .filter { $0.hasSuffix(".json") }.map { ($0 as NSString).deletingPathExtension }.sorted()
    }

    private func isOldFormat(_ name: String) throws -> Bool {
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent("\(name).json"))
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], name)
        return raw["exercicesExclus"] != nil
    }

    private func decode(_ json: String) throws -> GameState {
        try StateStore.decoder.decode(GameState.self, from: Data(json.utf8))
    }

    // MARK: fixtures

    func testEveryOldFormatFixtureLoadsAndBecomesAPikachu() throws {
        let names = try fixtureNames().filter(isOldFormat)
        XCTAssertGreaterThanOrEqual(names.count, 5)
        for name in names {
            let data = try Data(contentsOf: fixturesDir.appendingPathComponent("\(name).json"))
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], name)
            let game = try StateStore.decoder.decode(GameState.self, from: data)
            XCTAssertEqual(game.pokemon, CurrentPokemon(lineId: "pikachu", shiny: false, branchDex: nil), "a Pichu state becomes the Pikachu line: \(name)")
            let streak = try XCTUnwrap(raw["streak"] as? [String: Any], name)
            XCTAssertEqual(game.streak.count, streak["serie"] as? Int, name)
            XCTAssertEqual(game.streak.breaksToday, streak["pausesDuJour"] as? Int, name)
            let progression = try XCTUnwrap(raw["progression"] as? [String: Any], name)
            let oldXP = try XCTUnwrap(progression["xp"] as? Int, name)
            XCTAssertEqual(game.progression.xp, XPRules.migratedXP(fromLegacy: oldXP), name)
            XCTAssertEqual(game.progression.completedCycles, progression["cyclesTermines"] as? Int, name)
            XCTAssertEqual(game.schemaVersion, GameState.currentSchemaVersion, name)
        }
    }

    func testEveryNewFormatFixtureDecodesWithItsLine() throws {
        let names = try fixtureNames().filter { !(try isOldFormat($0)) }
        XCTAssertGreaterThanOrEqual(names.count, 4)
        for name in names {
            let data = try Data(contentsOf: fixturesDir.appendingPathComponent("\(name).json"))
            let game = try StateStore.decoder.decode(GameState.self, from: data)
            XCTAssertEqual(game.schemaVersion, GameState.currentSchemaVersion, name)
            XCTAssertTrue(name.contains(game.pokemon.lineId) || name.hasPrefix("hall-of-fame"), "\(name) should be a \(game.pokemon.lineId) state")
        }
    }

    func testEveryFixtureSurvivesARoundTripInTheNewFormat() throws {
        for name in try fixtureNames() {
            let data = try Data(contentsOf: fixturesDir.appendingPathComponent("\(name).json"))
            let old = try StateStore.decoder.decode(GameState.self, from: data)
            let rewritten = try StateStore.encoder.encode(old)
            XCTAssertEqual(try StateStore.decoder.decode(GameState.self, from: rewritten), old, name)
            let text = String(decoding: rewritten, as: UTF8.self)
            XCTAssertFalse(text.contains("\"serie\""), name)
            XCTAssertFalse(text.contains("\"hallOfFame\""), name)
            XCTAssertTrue(text.contains("\"breaksToday\""), name)
            XCTAssertTrue(text.contains("\"cycles\""), name)
        }
    }

    // MARK: XP: the level and the fraction of level are kept

    func testTheMigratedXPKeepsTheLevelAndTheFractionOfLevel() {
        for xp in [0, 7, 8, 100, 35_936, 35_937, 100_000, 274_625, 274_825, 500_000, 970_299, 999_500, 999_999] {
            let oldLevel = (1...100).last { XPRules.legacyTotalXP(forLevel: $0) <= xp }!
            let migrated = XPRules.migratedXP(fromLegacy: xp)
            XCTAssertEqual(XPRules.level(forXP: migrated), min(oldLevel, 99), "level of \(xp)")
            guard oldLevel < 100 else { continue }
            let oldFraction = Double(xp - XPRules.legacyTotalXP(forLevel: oldLevel))
                / Double(XPRules.legacyTotalXP(forLevel: oldLevel + 1) - XPRules.legacyTotalXP(forLevel: oldLevel))
            let newFraction = Double(migrated - XPRules.totalXP(forLevel: oldLevel))
                / Double(XPRules.totalXP(forLevel: oldLevel + 1) - XPRules.totalXP(forLevel: oldLevel))
            XCTAssertEqual(newFraction, oldFraction, accuracy: 0.001, "fraction of \(xp)")
        }
    }

    func testTheRealStateOfTheAuthor() {
        // Level 65 with 200 XP into it (65³ = 274,625): level 65 kept, same fraction of the level.
        XCTAssertEqual(XPRules.migratedXP(fromLegacy: 274_825), 422_704)
        XCTAssertEqual(XPRules.migratedXP(fromLegacy: 274_625), 422_500)
        XCTAssertEqual(XPRules.migratedXP(fromLegacy: 0), 0)
    }

    func testAnOldStateIsMigratedOnLoadAndAFileOfTheCurrentVersionIsNot() throws {
        let old = try decode(#"{"schemaVersion":1,"progression":{"xp":274825,"cyclesTermines":0,"hallOfFame":[]}}"#)
        XCTAssertEqual(old.progression.xp, 422_704)
        XCTAssertEqual(old.progression.level, 65)
        let schema3 = try decode(#"{"schemaVersion":3,"progression":{"xp":274825,"completedCycles":0,"hallOfFame":[]}}"#)
        XCTAssertEqual(schema3.progression.xp, 422_704, "schema 3 was still on the cube curve")
        let current = try decode(#"{"schemaVersion":4,"progression":{"xp":274825,"cycles":[{"lineId":"pikachu"}]}}"#)
        XCTAssertEqual(current.progression.xp, 274_825, "schema 4 is already on the new curve")
    }

    func testMigrationRunsOnceThroughTheStore() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-migration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(contentsOf: fixturesDir.appendingPathComponent("lv65-x5.json"))
            .write(to: dir.appendingPathComponent("state.json"))
        let store = StateStore(directory: dir)
        let game = store.load()
        XCTAssertEqual(game.progression.level, 65)
        XCTAssertEqual(game.progression.xp, 422_500)
        XCTAssertEqual(game.streak.count, 40)
        try store.save(game)
        XCTAssertEqual(store.load(), game, "loading the migrated file again changes nothing")
        XCTAssertEqual(store.load().progression.xp, 422_500)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertFalse(files.contains { $0.hasPrefix("state.corrupt") }, "an old state is not corrupt")
    }

    // MARK: cycles

    func testTheOldHallOfFameBecomesPikachuCyclesWithoutAStartDate() throws {
        let game = try decode("""
        {"schemaVersion":1,"progression":{"xp":1000,"cyclesTermines":2,
         "hallOfFame":[{"date":"2026-08-01T08:00:00Z","cycle":1},{"date":"2026-09-15T08:00:00Z","cycle":2}]}}
        """)
        let cycles = game.progression.cycles
        XCTAssertEqual(cycles.count, 3, "two completed cycles and the current one")
        XCTAssertEqual(game.progression.completedCycles, 2)
        for past in game.progression.completedCycleList {
            XCTAssertEqual(past.lineId, "pikachu")
            XCTAssertNil(past.startedAt)
            XCTAssertNotNil(past.endedAt)
            XCTAssertEqual(past.reachedDexes, [25, 26])
            XCTAssertFalse(past.shiny)
        }
        XCTAssertEqual(game.progression.completedCycleList.map(\.endedAt).compactMap { $0 }.count, 2)
        XCTAssertLessThan(try XCTUnwrap(cycles[0].endedAt), try XCTUnwrap(cycles[1].endedAt))
        XCTAssertNil(cycles[2].endedAt, "the current cycle is the last one")
        XCTAssertEqual(cycles[2].lineId, "pikachu")
    }

    func testACycleCountHigherThanTheListKeepsTheCount() throws {
        let game = try decode(#"{"schemaVersion":1,"progression":{"xp":0,"cyclesTermines":3,"hallOfFame":[]}}"#)
        XCTAssertEqual(game.progression.completedCycles, 3)
        XCTAssertTrue(game.progression.completedCycleList.allSatisfy { $0.endedAt == nil && $0.startedAt == nil })
    }

    func testSchema3KeepsItsPokemonInTheCurrentCycle() throws {
        let game = try decode("""
        {"schemaVersion":3,"progression":{"xp":0,"completedCycles":0,"hallOfFame":[]},
         "pokemon":{"lineId":"eevee","shiny":true,"branchDex":136}}
        """)
        XCTAssertEqual(game.progression.current.lineId, "eevee")
        XCTAssertTrue(game.progression.current.shiny)
        XCTAssertEqual(game.progression.current.branchDex, 136)
        let text = String(decoding: try StateStore.encoder.encode(game), as: UTF8.self)
        XCTAssertFalse(text.contains("\"pokemon\""), "the Pokémon is written in the cycle")
    }

    // MARK: keys

    func testAFullOldStateKeepsEveryField() throws {
        let json = """
        {
          "schemaVersion": 1,
          "progression": {"xp": 123456, "cyclesTermines": 3,
                          "hallOfFame": [{"date": "2026-09-01T08:00:00Z", "cycle": 1}]},
          "streak": {"serie": 17, "pausesDuJour": 4, "jourCourant": "2026-10-19T00:00:00Z",
                     "historique": [{"jour": "2026-10-16T00:00:00Z", "pauses": 6}]},
          "exercicesExclus": ["Wall_Slides"],
          "exercicesDuJour": {"jour": "2026-10-19T00:00:00Z", "ids": ["Chin_Tucks", "Wrist_Circles"]},
          "reseaux": {"HomeNetwork": "home", "OfficeNetwork": "office"},
          "reglages": {"travailMinutes": 30, "etape1Secondes": 25, "etape2Secondes": 40,
                       "reportMinutes": 7, "modeParDefaut": "office"}
        }
        """
        let game = try decode(json)
        XCTAssertEqual(game.progression.xp, XPRules.migratedXP(fromLegacy: 123_456))
        XCTAssertEqual(game.progression.level, 49, "49³ = 117,649 ≤ 123,456 < 125,000")
        XCTAssertEqual(game.progression.completedCycles, 3)
        XCTAssertEqual(game.streak.count, 17)
        XCTAssertEqual(game.streak.breaksToday, 4)
        XCTAssertNotNil(game.streak.currentDay)
        XCTAssertEqual(game.streak.history.map(\.breaks), [6])
        XCTAssertEqual(game.excludedExercises, ["Wall_Slides"])
        XCTAssertEqual(game.dailyPicks.ids, ["Chin_Tucks", "Wrist_Circles"])
        XCTAssertNotNil(game.dailyPicks.day)
        XCTAssertEqual(game.networks, ["HomeNetwork": .home, "OfficeNetwork": .office])
        XCTAssertEqual(game.settings, UserSettings(workMinutes: 30, step1Seconds: 25, step2Seconds: 40,
                                                   snoozeMinutes: 7, defaultMode: .office))
        let again = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(again, game)
    }

    func testNewKeysWinOverOldOnes() throws {
        let game = try decode(#"{"streak":{"count":9,"serie":1}}"#)
        XCTAssertEqual(game.streak.count, 9)
    }
}
