import XCTest
@testable import Stretchu

/// Resources/lines.json and the line model (no downloaded sprite needed unless said).
final class LinesFileTests: XCTestCase {
    private func file() throws -> LineCatalog.File {
        let url = try XCTUnwrap(AppResources.url("lines.json"), "lines.json not found")
        return try JSONDecoder().decode(LineCatalog.File.self, from: Data(contentsOf: url))
    }

    func testTheFilePinsBothSpriteSources() throws {
        let f = try file()
        XCTAssertEqual(f.spriteCollabCommit.count, 40)
        XCTAssertEqual(f.pokeApiSpritesCommit.count, 40)
    }

    func testEveryGen1SpeciesIsInExactlyOneLine() throws {
        let dexes = try file().lines.flatMap(\.allSpecies).map(\.dex).sorted()
        XCTAssertEqual(dexes, Array(1...151), "151 species, each once, none beyond Gen 1")
    }

    func testAboutSeventyEightLines() throws {
        let count = try file().lines.count
        XCTAssertTrue((75...82).contains(count), "\(count) lines")
    }

    func testPikachuStartsAtPikachuWithoutPichu() throws {
        let line = try XCTUnwrap(file().lines.first { $0.id == "pikachu" })
        XCTAssertEqual(line.species.map(\.slug), ["pikachu", "raichu"])
    }

    func testEvolutionLevelsFollowTheNumberOfEvolutions() throws {
        for line in try file().lines {
            let levels = line.species.map(\.level)
            switch (line.species.count, line.branch) {
            case (3, nil): XCTAssertEqual(levels, [1, 33, 66], line.id)
            case (2, nil): XCTAssertEqual(levels, [1, 50], line.id)
            case (1, nil): XCTAssertEqual(levels, [1], line.id)
            case (1, .some(let branch)): XCTAssertEqual(branch.level, 50, line.id)
            default: XCTFail("unexpected shape for \(line.id)")
            }
        }
    }

    func testEeveeIsTheOnlyBranchingLine() throws {
        let branching = try file().lines.filter { $0.branch != nil }
        XCTAssertEqual(branching.map(\.id), ["eevee"])
        let options = try XCTUnwrap(branching.first?.branch?.options)
        XCTAssertEqual(options.map(\.stone), ["water-stone", "thunder-stone", "fire-stone"])
        XCTAssertEqual(options.map(\.slug), ["vaporeon", "jolteon", "flareon"])
        XCTAssertEqual(options.map { $0.stoneNames["fr"] }, ["Pierre Eau", "Pierre Foudre", "Pierre Feu"])
        XCTAssertEqual(options.map { $0.names["fr"] }, ["Aquali", "Voltali", "Pyroli"])
    }

    func testEverySpeciesHasEnglishAndFrenchNames() throws {
        for line in try file().lines {
            for s in line.allSpecies {
                XCTAssertFalse(s.names["en"]?.isEmpty ?? true, s.slug)
                XCTAssertFalse(s.names["fr"]?.isEmpty ?? true, s.slug)
            }
        }
    }

    func testLineIdsAreUnique() throws {
        let ids = try file().lines.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}

final class PokemonLineModelTests: XCTestCase {
    func testSpeciesAtLevel() {
        let line = PokemonLine.charmander
        XCTAssertEqual(line.species(atLevel: 1, branchDex: nil).slug, "charmander")
        XCTAssertEqual(line.species(atLevel: 32, branchDex: nil).slug, "charmander")
        XCTAssertEqual(line.species(atLevel: 33, branchDex: nil).slug, "charmeleon")
        XCTAssertEqual(line.species(atLevel: 66, branchDex: nil).slug, "charizard")
        XCTAssertEqual(line.species(atLevel: 100, branchDex: nil).slug, "charizard")
    }

    func testEeveeStaysEeveeUntilAStoneIsChosen() {
        let line = PokemonLine.eevee
        XCTAssertEqual(line.species(atLevel: 49, branchDex: nil).slug, "eevee")
        XCTAssertEqual(line.species(atLevel: 80, branchDex: nil).slug, "eevee")
        XCTAssertFalse(line.needsBranchChoice(atLevel: 49, branchDex: nil))
        XCTAssertTrue(line.needsBranchChoice(atLevel: 50, branchDex: nil))
    }

    func testEeveeEvolvesIntoTheChosenStonesSpeciesAtLevel50() {
        let line = PokemonLine.eevee
        XCTAssertEqual(line.species(atLevel: 49, branchDex: 134).slug, "eevee")
        XCTAssertEqual(line.species(atLevel: 50, branchDex: 134).slug, "vaporeon")
        XCTAssertEqual(line.species(atLevel: 50, branchDex: 135).slug, "jolteon")
        XCTAssertEqual(line.species(atLevel: 99, branchDex: 136).slug, "flareon")
        XCTAssertFalse(line.needsBranchChoice(atLevel: 50, branchDex: 136))
        XCTAssertEqual(line.chain(branchDex: 136).map(\.slug), ["eevee", "flareon"])
        XCTAssertEqual(line.allSpecies.map(\.dex), [133, 134, 135, 136])
    }

    func testAnUnknownBranchChoiceIsIgnored() {
        XCTAssertEqual(PokemonLine.eevee.chain(branchDex: 999).map(\.slug), ["eevee"])
        XCTAssertTrue(PokemonLine.eevee.needsBranchChoice(atLevel: 60, branchDex: 999))
    }

    func testNamesFollowTheLanguageWithAnEnglishFallback() {
        let s = PokemonLine.charmander.base
        XCTAssertEqual(s.name(language: "fr"), "Salamèche")
        XCTAssertEqual(s.name(language: "en"), "Charmander")
        XCTAssertEqual(s.name(language: "de"), "Charmander")
    }

    func testTheEvolutionEventFollowsTheLine() {
        var p = Progression(xp: 249_999)
        let events = p.gain(1, now: TestCalendar.monday, line: .pikachu)
        XCTAssertTrue(events.contains(.speciesReached(PokemonLine.pikachu.species[1])))
        var eevee = Progression(xp: 249_999, cycles: [Cycle(lineId: "eevee")])
        XCTAssertFalse(eevee.gain(1, now: TestCalendar.monday, line: .eevee).contains { if case .speciesReached = $0 { true } else { false } },
                       "no evolution until a stone is chosen")
        var chosen = Progression(xp: 249_999, cycles: [Cycle(lineId: "eevee", branchDex: 136)])
        XCTAssertTrue(chosen.gain(1, now: TestCalendar.monday, line: .eevee)
            .contains { if case .speciesReached = $0 { true } else { false } })
    }

    func testAStateWithoutAPokemonIsAPikachu() throws {
        let json = #"{"progression":{"xp":500,"cyclesTermines":0,"hallOfFame":[]}}"#
        let game = try StateStore.decoder.decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(game.pokemon, CurrentPokemon(lineId: "pikachu", shiny: false, branchDex: nil))
        XCTAssertEqual(game.line.id, "pikachu")
    }

    func testThePokemonIsPersisted() throws {
        var game = GameState()
        game.pokemon = CurrentPokemon(lineId: "eevee", shiny: true, branchDex: 135)
        let decoded = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(decoded.pokemon, game.pokemon)
    }

    func testTheGameStateXPFollowsTheLine() {
        var game = GameState()
        game.pokemon = CurrentPokemon(lineId: "pikachu")
        game.progression = Progression(xp: 249_999)
        XCTAssertEqual(game.species.slug, "pikachu")
        game.progression = Progression(xp: 250_000)
        XCTAssertEqual(game.species.slug, "raichu")
    }
}

final class ShinyTests: XCTestCase {
    private let hasShiny: (Int) -> Bool = { _ in true }
    private let noShiny: (Int) -> Bool = { $0 != 134 }   // Vaporeon has none

    func testTheChanceIsTwentyPercent() {
        XCTAssertEqual(LineCatalog.shinyChance, 0.20)
    }

    func testTheInjectedDrawDecides() {
        XCTAssertTrue(LineCatalog.rollShiny(for: .charmander, random: { 0.0 }, shinyExists: hasShiny))
        XCTAssertTrue(LineCatalog.rollShiny(for: .charmander, random: { 0.1999 }, shinyExists: hasShiny))
        XCTAssertFalse(LineCatalog.rollShiny(for: .charmander, random: { 0.20 }, shinyExists: hasShiny))
        XCTAssertFalse(LineCatalog.rollShiny(for: .charmander, random: { 0.99 }, shinyExists: hasShiny))
    }

    func testAboutOneInFiveWithARealGenerator() {
        var generator = SystemRandomNumberGenerator()
        let shinies = (0..<10_000).filter { _ in
            LineCatalog.rollShiny(for: .charmander, random: { Double.random(in: 0..<1, using: &generator) }, shinyExists: hasShiny)
        }.count
        XCTAssertTrue((1_700...2_300).contains(shinies), "\(shinies) shinies in 10,000")
    }

    func testALineWhoseSpeciesLacksAShinyNeverGetsOne() {
        // One species of the line has no shiny: the line has none, and the draw is not even made.
        var drawn = false
        XCTAssertFalse(LineCatalog.hasShiny(.eevee, shinyExists: noShiny))
        XCTAssertFalse(LineCatalog.rollShiny(for: .eevee, random: { drawn = true; return 0 }, shinyExists: noShiny))
        XCTAssertFalse(drawn)
    }

    func testChoosingAPokemonStartsAFreshCurrentPokemon() throws {
        try requireSprites()
        let shiny = LineCatalog.choose(lineId: "charmander", random: { 0 })
        XCTAssertEqual(shiny, CurrentPokemon(lineId: "charmander", shiny: true, branchDex: nil))
        let normal = LineCatalog.choose(lineId: "charmander", random: { 0.5 })
        XCTAssertEqual(normal, CurrentPokemon(lineId: "charmander", shiny: false, branchDex: nil))
    }
}

final class LineAvailabilityTests: XCTestCase {
    func testALineIsAvailableOnlyWhenEverySpeciesHasSprites() {
        let lines: [PokemonLine] = [.charmander, .ditto, .pikachu]
        let usable = LineCatalog.available(in: lines, spriteExists: { $0 != 5 }, stoneExists: { _ in true })
        XCTAssertEqual(usable.map(\.id), ["ditto", "pikachu"], "Charmeleon (5) is missing: the whole line is out")
    }

    func testEeveeNeedsItsThreeStones() {
        XCTAssertEqual(LineCatalog.available(in: [.eevee], spriteExists: { _ in true }, stoneExists: { _ in true }).count, 1)
        XCTAssertTrue(LineCatalog.available(in: [.eevee], spriteExists: { _ in true }, stoneExists: { $0 != "fire-stone" }).isEmpty)
        XCTAssertTrue(LineCatalog.available(in: [.eevee], spriteExists: { $0 != 136 }, stoneExists: { _ in true }).isEmpty)
    }

    func testTheSpritePathsAreThePmdFolders() {
        XCTAssertEqual(SpriteFiles.relativePath(dex: 25, shiny: false, file: "Idle-Anim.png"), "Sprites/pmd/0025/Idle-Anim.png")
        XCTAssertEqual(SpriteFiles.relativePath(dex: 133, shiny: true, file: "Hop-Anim.png"), "Sprites/pmd/0133/shiny/Hop-Anim.png")
    }

    func testTheDownloadedCatalogIsConsistent() throws {
        try requireSprites()
        XCTAssertGreaterThan(LineCatalog.available.count, 70)
        XCTAssertNotNil(LineCatalog.line(id: "pikachu"))
        XCTAssertTrue(LineCatalog.available.contains { $0.id == "eevee" })
        for stone in ["water-stone", "thunder-stone", "fire-stone"] {
            XCTAssertNotNil(SpriteLibrary.stoneImage(stone), stone)
        }
    }

    func testEveryDownloadedSpeciesHasAShinyOrNone() throws {
        try requireSprites()
        for line in LineCatalog.available where LineCatalog.hasShiny(line) {
            for s in line.allSpecies {
                XCTAssertNotNil(SpriteLibrary.idleFrame(SpriteRef(dex: s.dex, shiny: true)), s.slug)
            }
        }
    }
}

final class SpriteCreditsTests: XCTestCase {
    func testTheCreditsFileListsTheArtistsOfTheDownloadedSpecies() throws {
        try requireSprites()
        let credits = try XCTUnwrap(SpriteCredits.load())
        XCTAssertEqual(credits.license, "CC BY-NC 4.0")
        XCTAssertGreaterThan(credits.artists.count, 5)
        XCTAssertTrue(credits.artists.map(\.name).contains("CHUNSOFT"))
        let downloaded = Set(LineCatalog.available.flatMap(\.allSpecies).map { String(format: "%04d", $0.dex) })
        XCTAssertEqual(Set(credits.bySpecies.keys), downloaded, "credits cover exactly the downloaded species")
        let named = Set(credits.artists.map(\.name))
        for (species, authors) in credits.bySpecies {
            XCTAssertFalse(authors.isEmpty, species)
            for a in authors { XCTAssertTrue(named.contains(a), "\(species): \(a)") }
        }
    }

    func testNoPokemonSpriteIsTracked() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let gitignore = try String(contentsOf: root.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(gitignore.split(separator: "\n").contains("Resources/Sprites/"))
    }
}
