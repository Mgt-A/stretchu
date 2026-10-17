import XCTest
@testable import Stretchu

/// Choosing the next Pokémon, giving a cycle up, the stone of Eevee.
final class CycleChoiceTests: XCTestCase {
    private func game(xp: Int = 0, line: String = "pikachu") -> GameState {
        var g = GameState()
        g.progression = Progression(xp: xp, cycles: [Cycle(lineId: line, startedAt: TestCalendar.monday)])
        g.streak = Streak(count: 24, breaksToday: 3, currentDay: TestCalendar.calendar.startOfDay(for: TestCalendar.tuesday))
        return g
    }

    // MARK: choosing

    func testChoosingTheNextPokemonDrawsAFreshShiny() throws {
        try requireSprites()
        var g = game()
        g.chooseNextPokemon(lineId: "charmander", random: { 0.05 })
        XCTAssertEqual(g.pokemon, CurrentPokemon(lineId: "charmander", shiny: true, branchDex: nil))
        g.chooseNextPokemon(lineId: "charmander", random: { 0.9 })
        XCTAssertFalse(g.pokemon.shiny, "each hatching draws again")
    }

    func testChoosingResetsTheSpeciesReachedOfTheNewCycleOnly() {
        var g = game(xp: 0, line: "pikachu")
        g.progression.cycles.insert(Cycle(lineId: "pikachu", reachedDexes: [25, 26]), at: 0)
        g.chooseNextPokemon(lineId: "squirtle", random: { 0.9 })
        XCTAssertEqual(g.progression.current.reachedDexes, [7])
        XCTAssertEqual(g.progression.cycles[0].reachedDexes, [25, 26], "the Hall of Fame is not touched")
    }

    func testTheCycleThatEndedKeepsGoingWithTheSameLineIfNothingIsChosen() {
        var g = game(xp: 999_999)
        _ = g.apply(.breakCompleted, now: TestCalendar.tuesday, calendar: TestCalendar.calendar, random: { 0.9 })
        XCTAssertEqual(g.progression.completedCycles, 1)
        XCTAssertEqual(g.pokemon.lineId, "pikachu", "closed without choosing: same line, level 1")
        XCTAssertEqual(g.progression.level, 1)
    }

    // MARK: abandoning

    func testAnAbandonedCycleDisappearsFromTheHallOfFame() {
        var g = game(xp: 300_000)
        g.progression.cycles.insert(Cycle(lineId: "charmander", startedAt: TestCalendar.sunday, endedAt: TestCalendar.monday, reachedDexes: [4, 5, 6]), at: 0)
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        XCTAssertEqual(g.progression.completedCycles, 1, "the abandoned cycle is not counted")
        XCTAssertEqual(HallOfFame.rows(g.progression).count, 2, "the current cycle and the one completed")
        XCTAssertEqual(g.progression.current.startedAt, TestCalendar.wednesday)
    }

    func testAnAbandonedCycleDoesNotCountInThePokedex() {
        var g = game(xp: 300_000)   // Pikachu line, level 54: Raichu reached
        XCTAssertEqual(Pokedex.obtainedDexes(g.progression.cycles), [25, 26])
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        XCTAssertEqual(Pokedex.obtainedDexes(g.progression.cycles), [25], "Raichu was only reached in the abandoned cycle")
    }

    func testAbandoningGoesBackToLevelOneAndKeepsTheStreak() {
        var g = game(xp: 300_000)
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        XCTAssertEqual(g.progression.level, 1)
        XCTAssertEqual(g.progression.xp, 0)
        XCTAssertEqual(g.streak.count, 24)
        XCTAssertEqual(g.streak.multiplier, 5.0, accuracy: 1e-9)
        XCTAssertEqual(g.streak.breaksToday, 3)
    }

    func testTheCycleAfterAnAbandonNeverHasAShinyDraw() throws {
        try requireSprites()
        var g = game(xp: 300_000, line: "charmander")
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        XCTAssertTrue(g.progression.current.afterAbandon)
        var drew = false
        g.chooseNextPokemon(lineId: "squirtle", random: { drew = true; return 0.0 })
        XCTAssertFalse(g.pokemon.shiny, "even a winning draw gives nothing after an abandon")
        XCTAssertFalse(drew, "the draw is not even made")
    }

    func testTheCycleAfterThatOneDrawsAgain() throws {
        try requireSprites()
        var g = game(xp: 300_000, line: "charmander")
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        g.chooseNextPokemon(lineId: "squirtle", random: { 0.0 })
        g.progression.xp = 999_999
        _ = g.apply(.breakCompleted, now: TestCalendar.thursday, calendar: TestCalendar.calendar, random: { 0.0 })
        XCTAssertFalse(g.progression.current.afterAbandon, "the next cycle is a normal one")
        XCTAssertTrue(g.progression.current.shiny, "and it draws")
        g.chooseNextPokemon(lineId: "bulbasaur", random: { 0.0 })
        XCTAssertTrue(g.pokemon.shiny)
    }

    func testAbandoningTwiceStillNeverDraws() throws {
        try requireSprites()
        var g = game(xp: 1_000)
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        g.chooseNextPokemon(lineId: "bulbasaur", random: { 0.0 })
        g.abandonCurrentCycle(now: TestCalendar.thursday)
        g.chooseNextPokemon(lineId: "bulbasaur", random: { 0.0 })
        XCTAssertFalse(g.pokemon.shiny)
        XCTAssertEqual(g.progression.completedCycles, 0)
    }

    func testTheAfterAbandonFlagIsPersisted() throws {
        var g = game(xp: 10)
        g.abandonCurrentCycle(now: TestCalendar.wednesday)
        let decoded = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(g))
        XCTAssertTrue(decoded.progression.current.afterAbandon)
    }

    // MARK: Eevee's stone

    func testEeveeNeedsAChoiceAtLevel50() {
        var g = game(xp: 249_999, line: "eevee")
        XCTAssertFalse(g.needsBranchChoice)
        g.progression.xp = 250_000
        XCTAssertTrue(g.needsBranchChoice)
        XCTAssertEqual(g.species.slug, "eevee", "no evolution before the stone")
        XCTAssertFalse(game(xp: 500_000).needsBranchChoice, "other lines never do")
    }

    func testChoosingAStoneEvolvesEeveeAndCountsInThePokedex() {
        var g = game(xp: 250_000, line: "eevee")
        let events = g.chooseBranch(dex: 136)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(g.species.slug, "flareon")
        XCTAssertFalse(g.needsBranchChoice)
        XCTAssertEqual(Pokedex.obtainedDexes(g.progression.cycles), [133, 136])
    }

    func testTheStoneIsFinalForTheCycleAndNeedsTheLevel() {
        var g = game(xp: 249_999, line: "eevee")
        XCTAssertTrue(g.chooseBranch(dex: 135).isEmpty, "before level 50 nothing happens")
        g.progression.xp = 250_000
        _ = g.chooseBranch(dex: 134)
        XCTAssertTrue(g.chooseBranch(dex: 135).isEmpty, "already chosen")
        XCTAssertEqual(g.species.slug, "vaporeon")
        XCTAssertTrue(game(xp: 500_000).line.branch == nil)
        var other = game(xp: 500_000)
        XCTAssertTrue(other.chooseBranch(dex: 134).isEmpty)
    }

    func testThreeEeveeCyclesGiveTheThreeEvolutions() {
        var cycles: [Cycle] = []
        for dex in [134, 135, 136] {
            var g = game(xp: 250_000, line: "eevee")
            g.chooseBranch(dex: dex)
            var c = g.progression.current
            c.endedAt = TestCalendar.monday
            cycles.append(c)
        }
        XCTAssertEqual(Pokedex.obtainedDexes(cycles), [133, 134, 135, 136])
    }

    func testPostponingKeepsEarningXPWithoutEvolving() {
        var g = game(xp: 250_000, line: "eevee")
        g.streak = Streak(count: 0, breaksToday: 0, currentDay: TestCalendar.calendar.startOfDay(for: TestCalendar.tuesday))
        let events = g.apply(.breakCompleted, now: TestCalendar.tuesday, calendar: TestCalendar.calendar)
        XCTAssertGreaterThan(g.progression.xp, 250_000)
        XCTAssertEqual(g.species.slug, "eevee")
        XCTAssertFalse(events.contains { if case .speciesReached = $0 { true } else { false } })
        XCTAssertTrue(g.needsBranchChoice)
    }

    // MARK: Pokédex helpers

    func testShinySpeciesAreTheOnesReachedInAShinyCycle() {
        let cycles = [Cycle(lineId: "charmander", shiny: true, reachedDexes: [4, 5]), Cycle(lineId: "pikachu", reachedDexes: [25])]
        XCTAssertEqual(Pokedex.shinyDexes(cycles), [4, 5])
        XCTAssertEqual(Pokedex.obtainedDexes(cycles), [4, 5, 25])
    }

    func testCompletedCountsPerLineIgnoreTheCurrentCycle() {
        let cycles = [Cycle(lineId: "pikachu"), Cycle(lineId: "pikachu"), Cycle(lineId: "charmander"), Cycle(lineId: "pikachu")]
        XCTAssertEqual(Pokedex.completedCounts(cycles), ["pikachu": 2, "charmander": 1])
    }
}

@MainActor
final class CycleFlowTests: XCTestCase {
    private func makeApp(_ configure: (inout GameState) -> Void) -> AppModel {
        let app = AppModel(store: StateStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-flow-\(UUID().uuidString)")))
        app.modifyStateForTests { $0.onboardingCompleted = true; configure(&$0) }
        return app
    }

    func testFinishingACycleOpensTheChoiceInsteadOfLevelUp() {
        let app = makeApp { $0.progression = Progression(xp: 999_999, cycles: [Cycle(lineId: "pikachu", startedAt: TestCalendar.monday)]) }
        app.completeBreak(forTests: ())
        XCTAssertNotNil(app.cycleChoice)
        XCTAssertEqual(app.cycleChoice?.kind, .finished)
        XCTAssertEqual(app.cycleChoice?.finishedSpecies?.slug, "raichu")
        XCTAssertNil(app.levelUp, "B1 replaces Level up")
    }

    func testHatchingStartsTheChosenLine() {
        let app = makeApp { $0.progression = Progression(xp: 999_999, cycles: [Cycle(lineId: "pikachu", startedAt: TestCalendar.monday)]) }
        app.completeBreak(forTests: ())
        app.chooseNextPokemon(lineId: "squirtle")
        XCTAssertNil(app.cycleChoice)
        XCTAssertEqual(app.game.pokemon.lineId, "squirtle")
        XCTAssertEqual(app.game.progression.level, 1)
        XCTAssertEqual(app.game.progression.completedCycles, 1)
    }

    func testAbandoningOpensTheChoiceAndKeepsTheStreak() {
        let app = makeApp {
            $0.progression = Progression(xp: 300_000, cycles: [Cycle(lineId: "pikachu", startedAt: TestCalendar.monday)])
            $0.streak = Streak(count: 12, breaksToday: 2, currentDay: nil)
        }
        app.abandonCycle()
        XCTAssertEqual(app.cycleChoice?.kind, .abandoned)
        XCTAssertEqual(app.game.progression.level, 1)
        XCTAssertEqual(app.game.streak.count, 12)
        XCTAssertEqual(app.game.progression.completedCycles, 0)
    }

    func testEeveeReachingLevel50OpensTheStoneScreen() {
        let app = makeApp { $0.progression = Progression(xp: 249_999, cycles: [Cycle(lineId: "eevee")]) }
        app.completeBreak(forTests: ())
        XCTAssertTrue(app.branchChoiceOpen)
        XCTAssertNil(app.levelUp, "B2 replaces Level up")
    }

    func testLaterClosesTheStoneScreenAndTheMenuOffersToChooseAgain() {
        let app = makeApp { $0.progression = Progression(xp: 249_999, cycles: [Cycle(lineId: "eevee")]) }
        app.completeBreak(forTests: ())
        app.postponeBranchChoice()
        XCTAssertFalse(app.branchChoiceOpen)
        XCTAssertTrue(app.game.needsBranchChoice, "the menu row \"Choose the stone\" shows")
        app.showBranchChoice()
        XCTAssertTrue(app.branchChoiceOpen)
    }

    func testChoosingTheStoneEvolvesAndShowsTheEvolution() {
        let app = makeApp { $0.progression = Progression(xp: 250_000, cycles: [Cycle(lineId: "eevee")]) }
        app.chooseBranch(dex: 135)
        XCTAssertFalse(app.branchChoiceOpen)
        XCTAssertEqual(app.species.slug, "jolteon")
        XCTAssertEqual(app.levelUp?.species.slug, "jolteon")
        XCTAssertEqual(app.levelUp?.newSpecies, true)
    }

    func testAnOrdinaryLevelUpStillShowsLevelUp() {
        let app = makeApp { $0.progression = Progression(xp: 4_400, cycles: [Cycle(lineId: "pikachu")]) }
        app.completeBreak(forTests: ())
        XCTAssertNotNil(app.levelUp)
        XCTAssertNil(app.cycleChoice)
        XCTAssertFalse(app.branchChoiceOpen)
    }
}

extension AppModel {
    /// Test helper: a completed break, which gives 2,500 XP × the multiplier.
    func completeBreak(forTests _: Void) {
        handle([.breakCompleted])
    }
}
