import XCTest
@testable import Stretchu

final class LevelUpTests: XCTestCase {
    func testNoLevelUpWithoutANewLevel() {
        XCTAssertNil(LevelUp.from([.xpGained(200, multiplier: 1)], current: PokemonLine.charmander.base))
    }

    func testSimpleLevelUp() throws {
        let n = try XCTUnwrap(LevelUp.from(
            [.xpGained(680, multiplier: 3.4), .leveledUp(from: 34, to: 35)], current: PokemonLine.charmander.species[1]))
        XCTAssertEqual(n.level, 35)
        XCTAssertEqual(n.xpGained, 680)
        XCTAssertFalse(n.newSpecies)
        XCTAssertFalse(n.cycleCompleted)
    }

    func testLevelUpWithEvolution() throws {
        let n = try XCTUnwrap(LevelUp.from(
            [.xpGained(400, multiplier: 2), .leveledUp(from: 32, to: 33), .speciesReached(PokemonLine.charmander.species[1])],
            current: PokemonLine.charmander.species[1]))
        XCTAssertTrue(n.newSpecies)
        XCTAssertEqual(n.species.slug, "charmeleon")
    }

    func testCycleCompletedShowsLevel100() throws {
        let n = try XCTUnwrap(LevelUp.from(
            [.xpGained(980, multiplier: 4.9), .cycleCompleted(cycle: 2)],
            current: PokemonLine.charmander.base, finalSpecies: PokemonLine.charmander.species[2]))
        XCTAssertTrue(n.cycleCompleted)
        XCTAssertEqual(n.level, 100)
        XCTAssertEqual(n.species.slug, "charmander")
        XCTAssertEqual(n.finalSpecies?.slug, "charizard")
    }

    func testCountdownFormat() {
        XCTAssertEqual(Format.countdown(14), "0:14")
        XCTAssertEqual(Format.countdown(20), "0:20")
        XCTAssertEqual(Format.countdown(0), "0:00")
        XCTAssertEqual(Format.countdown(754), "12:34")
        XCTAssertEqual(Format.countdown(13.2), "0:14")
    }
}
