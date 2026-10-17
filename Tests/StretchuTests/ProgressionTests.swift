import XCTest
@testable import Stretchu

final class ProgressionTests: XCTestCase {
    let now = TestCalendar.monday

    // MARK: 100 × n² curve

    func testXPForLevelIs100TimesTheSquare() {
        XCTAssertEqual(Progression.totalXP(forLevel: 2), 400)
        XCTAssertEqual(Progression.totalXP(forLevel: 10), 10_000)
        XCTAssertEqual(Progression.totalXP(forLevel: 33), 108_900)
        XCTAssertEqual(Progression.totalXP(forLevel: 50), 250_000)
        XCTAssertEqual(Progression.totalXP(forLevel: 66), 435_600)
        XCTAssertEqual(Progression.totalXP(forLevel: 100), 1_000_000)
    }

    func testLevelOneIsZeroXP() {
        XCTAssertEqual(Progression.totalXP(forLevel: 1), 0)
        XCTAssertEqual(Progression(xp: 0).level, 1)
        XCTAssertEqual(Progression(xp: 399).level, 1)
        XCTAssertEqual(Progression(xp: 400).level, 2)
    }

    func testTheRulesLiveInOnePlace() {
        XCTAssertEqual(XPRules.breakXP, 2_500)
        XCTAssertEqual(XPRules.maxLevel, 100)
        XCTAssertEqual(XPRules.maxXP, 1_000_000)
        XCTAssertEqual(Progression.maxLevel, XPRules.maxLevel)
        XCTAssertEqual(Streak.breaksPerDayToKeep, XPRules.breaksPerDayToKeepStreak)
    }

    // MARK: evolution thresholds (levels come from the line)

    func testThreshold32To33() {
        let line = PokemonLine.charmander
        let just = Progression(xp: 108_899)
        XCTAssertEqual(just.level, 32)
        XCTAssertEqual(just.species(in: line).slug, "charmander")
        let crossed = Progression(xp: 108_900)
        XCTAssertEqual(crossed.level, 33)
        XCTAssertEqual(crossed.species(in: line).slug, "charmeleon")
    }

    func testThreshold65To66() {
        let line = PokemonLine.charmander
        let just = Progression(xp: 435_599)
        XCTAssertEqual(just.level, 65)
        XCTAssertEqual(just.species(in: line).slug, "charmeleon")
        let crossed = Progression(xp: 435_600)
        XCTAssertEqual(crossed.level, 66)
        XCTAssertEqual(crossed.species(in: line).slug, "charizard")
    }

    func testAOneEvolutionLineEvolvesAtLevel50() {
        let line = PokemonLine.pikachu
        XCTAssertEqual(Progression(xp: 249_999).level, 49)
        XCTAssertEqual(Progression(xp: 249_999).species(in: line).slug, "pikachu")
        XCTAssertEqual(Progression(xp: 250_000).level, 50)
        XCTAssertEqual(Progression(xp: 250_000).species(in: line).slug, "raichu")
    }

    func testALineWithoutEvolutionNeverChanges() {
        for xp in [0, 108_900, 435_600, 999_999] {
            XCTAssertEqual(Progression(xp: xp).species(in: .ditto).slug, "ditto")
        }
    }

    func testGainingXPCrossesTheThresholdAndReportsIt() {
        var p = Progression(xp: 108_899, cycles: [Cycle(lineId: "charmander")])
        let events = p.gain(1, now: now, line: .charmander)
        XCTAssertEqual(p.level, 33)
        XCTAssertTrue(events.contains(.leveledUp(from: 32, to: 33)))
        XCTAssertTrue(events.contains(.speciesReached(PokemonLine.charmander.species[1])))
    }

    func testGainingWithoutCrossingReportsNothing() {
        var p = Progression(xp: 1_000)
        let events = p.gain(10, now: now)
        XCTAssertEqual(p.xp, 1_010)
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: level 100, egg, cycles

    func testLevel99BeforeTheCycle() {
        XCTAssertEqual(Progression(xp: 999_999).level, 99)
    }

    func testReachingLevel100EndsTheCycleAndStartsANewOne() {
        var p = Progression(xp: 999_999, cycles: [Cycle(lineId: "charmander", startedAt: TestCalendar.sunday)])
        let events = p.gain(1, now: now, line: .charmander)
        XCTAssertEqual(p.xp, 0)
        XCTAssertEqual(p.level, 1)
        XCTAssertEqual(p.species(in: .charmander).slug, "charmander")
        XCTAssertEqual(p.completedCycles, 1)
        XCTAssertTrue(events.contains(.cycleCompleted(cycle: 1)))
        XCTAssertEqual(p.cycles.count, 2)
        XCTAssertEqual(p.cycles[0].endedAt, now)
        XCTAssertEqual(p.cycles[0].startedAt, TestCalendar.sunday)
        XCTAssertEqual(p.cycles[0].reachedDexes.sorted(), [4, 5, 6], "the whole line was reached")
        XCTAssertNil(p.current.endedAt, "the current cycle is the last one")
        XCTAssertEqual(p.current.startedAt, now)
        XCTAssertEqual(p.current.lineId, "charmander", "the next cycle defaults to the same line")
        XCTAssertEqual(p.current.reachedDexes, [4])
    }

    func testTheCompletedCycleKeepsItsShinyAndItsBranch() {
        var p = Progression(xp: 999_999, cycles: [Cycle(lineId: "eevee", shiny: true, branchDex: 136)])
        _ = p.gain(5, now: now, line: .eevee)
        XCTAssertTrue(p.cycles[0].shiny)
        XCTAssertEqual(p.cycles[0].branchDex, 136)
        XCTAssertEqual(p.cycles[0].reachedDexes.sorted(), [133, 136])
        XCTAssertNil(p.current.branchDex, "the branch is chosen afresh in the next cycle")
        XCTAssertFalse(p.current.shiny)
    }

    func testTheHallOfFameIsTheListOfCompletedCycles() {
        var p = Progression(xp: 999_999, completedCycles: 2)
        _ = p.gain(1, now: now, line: .pikachu)
        XCTAssertEqual(p.completedCycles, 3)
        XCTAssertEqual(p.completedCycleList.count, 3)
        XCTAssertEqual(p.completedCycleList.last?.endedAt, now)
    }

    func testTheStreakIsKeptAtLevel100AndTheNextCycleMayBeShiny() {
        var game = GameState()
        game.progression = Progression(xp: 999_500)
        game.streak = Streak(count: 39, breaksToday: 3, currentDay: TestCalendar.calendar.startOfDay(for: now))
        _ = game.apply(.breakCompleted, now: now, calendar: TestCalendar.calendar, random: { 0.5 })
        XCTAssertEqual(game.progression.completedCycles, 1)
        XCTAssertEqual(game.progression.level, 1)
        XCTAssertEqual(game.streak.count, 40, "the streak is untouched by the new cycle")
        XCTAssertFalse(game.pokemon.shiny)
    }

    func testTheNextCycleDrawsItsShinyWithTheInjectedSource() throws {
        try requireSprites()
        var game = GameState()
        game.progression = Progression(xp: 999_500)
        game.streak = Streak(count: 0, breaksToday: 0, currentDay: TestCalendar.calendar.startOfDay(for: now))
        _ = game.apply(.breakCompleted, now: now, calendar: TestCalendar.calendar, random: { 0.05 })
        XCTAssertTrue(game.pokemon.shiny, "0.05 < 20 %")
        XCTAssertEqual(game.progression.cycles[0].shiny, false, "the ended cycle was not shiny")
    }

    func testCycleLengthInCalendarDays() {
        let cal = TestCalendar.calendar
        let c = Cycle(lineId: "pikachu", startedAt: TestCalendar.monday, endedAt: TestCalendar.friday)
        XCTAssertEqual(c.days(calendar: cal, now: TestCalendar.sunday), 4)
        XCTAssertEqual(Cycle(lineId: "pikachu", startedAt: TestCalendar.monday).days(calendar: cal, now: TestCalendar.wednesday), 2)
        XCTAssertNil(Cycle(lineId: "pikachu").days(calendar: cal, now: TestCalendar.wednesday))
    }

    func testDebugCompletedCyclesSetter() {
        var p = Progression(xp: 10)
        p.setCompletedCycles(4)
        XCTAssertEqual(p.completedCycles, 4)
        XCTAssertEqual(p.xp, 10)
        p.setCompletedCycles(1)
        XCTAssertEqual(p.completedCycles, 1)
        p.setCompletedCycles(0)
        XCTAssertEqual(p.cycles.count, 1)
    }
}

// MARK: Pokédex completion

final class PokedexTests: XCTestCase {
    private let lines: [PokemonLine] = [.pikachu, .charmander, .ditto, .eevee]
    // Pikachu 25, 26; Charmander 4, 5, 6; Ditto 132; Eevee 133, 134, 135, 136: 10 species.

    func testTheTotalIsTheSpeciesOfTheAvailableLines() {
        XCTAssertEqual(Pokedex.completion(cycles: [], lines: lines).total, 10)
        XCTAssertEqual(Pokedex.completion(cycles: [], lines: [.ditto]).total, 1)
    }

    func testEachStageReachedCounts() {
        let cycle = Cycle(lineId: "charmander", reachedDexes: [4, 5])
        XCTAssertEqual(Pokedex.completion(cycles: [cycle], lines: lines).obtained, 2)
        let full = Cycle(lineId: "charmander", reachedDexes: [4, 5, 6])
        XCTAssertEqual(Pokedex.completion(cycles: [full], lines: lines).obtained, 3, "a full Charmander cycle = 3 species")
    }

    func testTheSameSpeciesTwiceCountsOnce() {
        let a = Cycle(lineId: "pikachu", reachedDexes: [25, 26]), b = Cycle(lineId: "pikachu", reachedDexes: [25])
        XCTAssertEqual(Pokedex.completion(cycles: [a, b], lines: lines).obtained, 2)
    }

    func testThreeEeveeCyclesGiveTheThreeEvolutions() {
        let cycles = [134, 135, 136].map { Cycle(lineId: "eevee", branchDex: $0, reachedDexes: [133, $0]) }
        XCTAssertEqual(Pokedex.completion(cycles: cycles, lines: lines).obtained, 4)
    }

    func testSpeciesOfLinesThatAreNotAvailableDoNotCount() {
        let cycle = Cycle(lineId: "charmander", reachedDexes: [4, 5, 6])
        let result = Pokedex.completion(cycles: [cycle], lines: [.pikachu])
        XCTAssertEqual(result, Pokedex.Completion(obtained: 0, total: 2))
    }

    func testReachedSpeciesFollowTheLevelOfTheCurrentCycle() {
        var game = GameState()
        game.pokemon = CurrentPokemon(lineId: "charmander")
        XCTAssertEqual(game.progression.current.reachedDexes, [4])
        game.progression.setLevel(40)
        XCTAssertEqual(game.progression.current.reachedDexes, [4, 5], "Charmeleon was passed through")
        game.progression.setLevel(70)
        XCTAssertEqual(game.progression.current.reachedDexes, [4, 5, 6])
    }

    func testEeveesBranchAddsItsSpeciesOnceChosen() {
        var game = GameState()
        game.pokemon = CurrentPokemon(lineId: "eevee")
        game.progression.setLevel(60)
        XCTAssertEqual(game.progression.current.reachedDexes, [133], "no evolution before the choice")
        game.pokemon.branchDex = 135
        XCTAssertEqual(game.progression.current.reachedDexes, [133, 135])
    }
}
