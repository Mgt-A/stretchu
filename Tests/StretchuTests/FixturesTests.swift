import XCTest
@testable import Stretchu

#if STRETCHU_DEBUG
/// The files in Tests/Fixtures (used by `make demo`) must stay identical to the
/// Debug panel's prepared states.
final class FixturesTests: XCTestCase {
    private var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
    }

    func testEveryPreparedStateHasAFileAndViceVersa() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: fixturesDir.path)
            .filter { $0.hasSuffix(".json") }.map { ($0 as NSString).deletingPathExtension }.sorted()
        XCTAssertEqual(Fixtures.all.map(\.name).sorted(), files)
        XCTAssertTrue(files.contains("lv99-streak39"))
    }

    func testEveryJSONFileMatchesTheCode() throws {
        for fixture in Fixtures.all {
            let url = fixturesDir.appendingPathComponent("\(fixture.name).json")
            let data = try Data(contentsOf: url)
            let decoded = try StateStore.decoder.decode(GameState.self, from: data)
            XCTAssertEqual(decoded, fixture.state, fixture.name)
        }
    }

    func testSpeciesOfThePreparedStates() {
        // The old-format files were Pichu states: they load as the Pikachu line.
        XCTAssertEqual(Fixtures.state("lv1")?.pokemon.lineId, "pikachu")
        XCTAssertEqual(Fixtures.state("lv32-almost")?.progression.level, 32)
        XCTAssertEqual(Fixtures.state("lv33-x2")?.progression.level, 33)
        XCTAssertEqual(Fixtures.state("lv65-x5")?.species.slug, "raichu")
        XCTAssertEqual(Streak.multiplier(forStreak: Fixtures.state("lv65-x5")!.streak.count), 5.0, accuracy: 1e-9)
        XCTAssertEqual(Fixtures.state("lv99-streak39")?.progression.level, 99)
        XCTAssertEqual(Fixtures.state("pikachu-lv49-almost")?.species.slug, "pikachu")
        XCTAssertEqual(Fixtures.state("charmander-lv32-almost")?.pokemon.lineId, "charmander")
        XCTAssertEqual(Fixtures.state("eevee-lv49-almost")?.species.slug, "eevee")
        XCTAssertEqual(Fixtures.state("eevee-flareon-shiny-lv60")?.species.slug, "flareon")
        XCTAssertEqual(Fixtures.state("eevee-flareon-shiny-lv60")?.pokemon.shiny, true)
    }

    func testPreparedStatesAdoptTheCurrentDay() {
        // No currentDay: otherwise the streak would fall on load.
        for fixture in Fixtures.all { XCTAssertNil(fixture.state.streak.currentDay, fixture.name) }
    }
}
#endif
