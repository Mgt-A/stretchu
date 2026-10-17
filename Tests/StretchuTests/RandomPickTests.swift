import XCTest
@testable import Stretchu

final class RandomPickTests: XCTestCase {
    private let pikachu = LineCatalog.line(id: "pikachu")!
    private let charmander = LineCatalog.line(id: "charmander")!
    private let squirtle = LineCatalog.line(id: "squirtle")!
    private let bulbasaur = LineCatalog.line(id: "bulbasaur")!
    private var lines: [PokemonLine] { [pikachu, charmander, squirtle, bulbasaur] }
    private let always: (Int) -> Bool = { _ in true }

    /// A source that replays a fixed list, then repeats the last value.
    private func source(_ values: [Double]) -> () -> Double {
        var i = 0
        return { defer { i += 1 }; return values[min(i, values.count - 1)] }
    }

    func testALineWhoseBaseIsInThePokedexCannotComeOut() {
        let obtained: Set<Int> = [pikachu.base.dex, charmander.base.dex]
        let ids = Set(RandomPick.candidates(lines: lines, obtained: obtained).map(\.id))
        XCTAssertEqual(ids, [squirtle.id, bulbasaur.id])
        for value in stride(from: 0.0, to: 1.0, by: 0.05) {
            let draw = RandomPick.draw(lines: lines, obtained: obtained, afterAbandon: false, random: { value }, shinyExists: always)
            XCTAssertTrue([squirtle.id, bulbasaur.id].contains(draw?.lineId ?? ""))
        }
    }

    func testWhenEverythingIsObtainedEveryLineIsPossibleAgain() {
        let all = Set(lines.map(\.base.dex))
        XCTAssertEqual(RandomPick.candidates(lines: lines, obtained: all).count, lines.count)
    }

    func testTheShinyChanceIs30PercentForARandomDraw() {
        // The source gives the index, then the reel (14 values), then the shiny roll.
        func shiny(_ roll: Double) -> Bool {
            var calls = 0
            let draw = RandomPick.draw(lines: lines, obtained: [], afterAbandon: false,
                                       random: { calls += 1; return calls == 1 + RandomPick.reelLength + 1 ? roll : 0.5 },
                                       shinyExists: always)
            return draw!.shiny
        }
        XCTAssertTrue(shiny(0.29))
        XCTAssertFalse(shiny(0.30))
        XCTAssertEqual(LineCatalog.randomShinyChance, 0.30)
        XCTAssertEqual(LineCatalog.shinyChance, 0.20, "a manual choice stays at 20 %")
    }

    func testRightAfterAGiveUpTheShinyIsNeverDrawn() {
        let draw = RandomPick.draw(lines: lines, obtained: [], afterAbandon: true, random: { 0.0 }, shinyExists: always)
        XCTAssertEqual(draw?.shiny, false)
    }

    func testALineWithoutAShinyNeverGetsOne() {
        let draw = RandomPick.draw(lines: lines, obtained: [], afterAbandon: false, random: { 0.0 }, shinyExists: { _ in false })
        XCTAssertEqual(draw?.shiny, false)
    }

    func testTheReelNeverShowsTheSameLineTwiceInARowNorTheResult() {
        for seed in 0..<50 {
            var generator = SystemRandomNumberGenerator()
            _ = seed
            let draw = RandomPick.draw(lines: lines, obtained: [], afterAbandon: false,
                                       random: { Double.random(in: 0..<1, using: &generator) }, shinyExists: always)!
            XCTAssertEqual(draw.reel.count, RandomPick.reelLength)
            XCTAssertFalse(draw.reel.contains(draw.lineId))
            for (a, b) in zip(draw.reel, draw.reel.dropFirst()) { XCTAssertNotEqual(a, b) }
        }
    }

    func testTheReelWorksWithTwoLinesOnly() {
        let two = [pikachu, charmander]
        let reel = RandomPick.reel(from: two, result: pikachu, random: source([0.1, 0.9]))
        XCTAssertFalse(reel.isEmpty)
        XCTAssertTrue(reel.allSatisfy { $0.id == charmander.id })
    }

    func testTheSameSourceGivesTheSameDraw() {
        let a = RandomPick.draw(lines: lines, obtained: [], afterAbandon: false, random: source([0.3, 0.7, 0.1]), shinyExists: always)
        let b = RandomPick.draw(lines: lines, obtained: [], afterAbandon: false, random: source([0.3, 0.7, 0.1]), shinyExists: always)
        XCTAssertEqual(a, b)
    }

    func testAChosenShinyIsKeptWhenTheNextCycleStarts() {
        var game = GameState()
        game.chooseNextPokemon(lineId: squirtle.id, shiny: true, random: { 0.99 })
        XCTAssertTrue(game.pokemon.shiny)
        game.chooseNextPokemon(lineId: squirtle.id, shiny: false, random: { 0.0 })
        XCTAssertFalse(game.pokemon.shiny)
    }
}
