import AppKit
import XCTest
@testable import Stretchu

final class HallOfFameTests: XCTestCase {
    private func progression() -> Progression {
        Progression(xp: 221_000, cycles: [
            Cycle(lineId: "pikachu", startedAt: TestCalendar.date(2026, 8, 18), endedAt: TestCalendar.date(2026, 8, 29), reachedDexes: [25, 26]),
            Cycle(lineId: "bulbasaur", startedAt: TestCalendar.date(2026, 9, 1), endedAt: TestCalendar.date(2026, 9, 12), reachedDexes: [1, 2, 3]),
            Cycle(lineId: "charmander", startedAt: TestCalendar.date(2026, 9, 15), endedAt: TestCalendar.date(2026, 9, 26), shiny: true, reachedDexes: [4, 5, 6]),
            Cycle(lineId: "pikachu", startedAt: TestCalendar.date(2026, 10, 13)),
        ])
    }

    func testTheCurrentCycleIsFirstThenTheMostRecentToTheOldest() {
        let rows = HallOfFame.rows(progression())
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows[0].isCurrent)
        XCTAssertEqual(rows.dropFirst().map(\.cycle.lineId), ["charmander", "bulbasaur", "pikachu"])
        XCTAssertEqual(rows.dropFirst().map(\.isCurrent), [false, false, false])
    }

    func testARowIsNamedAfterTheLastStageReached() {
        let rows = HallOfFame.rows(progression())
        XCTAssertEqual(rows[1].title?.slug, "charizard")
        XCTAssertEqual(rows[2].title?.slug, "venusaur")
        XCTAssertEqual(rows[3].title?.slug, "raichu")
        XCTAssertEqual(rows[1].species.map(\.dex), [4, 5, 6], "the stages reached, 1 to 3")
        XCTAssertEqual(rows[3].species.map(\.dex), [25, 26])
        XCTAssertTrue(rows[1].cycle.shiny)
    }

    func testTheSummaryCountsLinesCyclesAndThePokedex() {
        let summary = HallOfFame.summary(progression(), lines: [.pikachu, .charmander, .ditto])
        XCTAssertEqual(summary.linesCompleted, 2, "pikachu and charmander (bulbasaur isn't among these lines)")
        XCTAssertEqual(summary.linesTotal, 3)
        XCTAssertEqual(summary.cycles, 3)
        XCTAssertEqual(summary.pokedex, Pokedex.Completion(obtained: 5, total: 6))
    }

    func testTheSummaryOfTheRealCatalog() throws {
        try requireSprites()
        let summary = HallOfFame.summary(progression())
        XCTAssertEqual(summary.linesCompleted, 3)
        XCTAssertEqual(summary.cycles, 3)
        XCTAssertEqual(summary.pokedex.total, LineCatalog.available.flatMap(\.allSpecies).count)
        XCTAssertEqual(summary.pokedex.obtained, 8, "pikachu line 2 + bulbasaur line 3 + charmander line 3, current cycle adds nothing new")
    }

    func testTheChoiceGridPutsFinishedLinesFirstThenByPokedexNumber() {
        let lines: [PokemonLine] = [.eevee, .charmander, .pikachu, .ditto]
        let ordered = HallOfFame.choiceOrder(lines, completedCounts: ["pikachu": 2, "ditto": 1])
        XCTAssertEqual(ordered.map(\.id), ["pikachu", "ditto", "charmander", "eevee"])
    }

    // MARK: dates

    func testDateRangesAreCompactedInTheSameMonth() {
        let cal = TestCalendar.calendar
        let fr = Locale(identifier: "fr")
        XCTAssertEqual(HallOfFameFormat.dateRange(start: TestCalendar.date(2026, 9, 15), end: TestCalendar.date(2026, 9, 26), calendar: cal, locale: fr), "15 → 26 sept.")
        XCTAssertEqual(HallOfFameFormat.dateRange(start: TestCalendar.date(2026, 9, 29), end: TestCalendar.date(2026, 10, 9), calendar: cal, locale: fr), "29 sept. → 9 oct.")
        XCTAssertEqual(HallOfFameFormat.dateRange(start: nil, end: TestCalendar.date(2026, 7, 1), calendar: cal, locale: fr), "→ 1 juil.", "a migrated cycle has no start")
    }

    func testDaysAreCalendarDaysAndHiddenWithoutAStart() {
        let cal = TestCalendar.calendar
        let c = Cycle(lineId: "pikachu", startedAt: TestCalendar.date(2026, 9, 29, 23, 0), endedAt: TestCalendar.date(2026, 10, 9, 1, 0))
        XCTAssertEqual(c.days(calendar: cal, now: TestCalendar.monday), 10)
        XCTAssertNil(Cycle(lineId: "pikachu", endedAt: TestCalendar.monday).days(calendar: cal, now: TestCalendar.monday))
    }

    func testMigratedCyclesShowAnEndDateWithoutAStart() throws {
        let game = try StateStore.decoder.decode(GameState.self, from: Data("""
        {"schemaVersion":1,"progression":{"xp":0,"cyclesTermines":1,"hallOfFame":[{"date":"2026-07-01T08:00:00Z","cycle":1}]}}
        """.utf8))
        let row = HallOfFame.rows(game.progression)[1]
        XCTAssertNil(row.cycle.startedAt)
        XCTAssertNotNil(row.cycle.endedAt)
        XCTAssertEqual(row.title?.slug, "raichu")
    }

    func testTheHallOfFameFixtureShowsFourCyclesAndTheCurrentOne() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/hall-of-fame-4-cycles.json")
        let game = try StateStore.decoder.decode(GameState.self, from: Data(contentsOf: url))
        XCTAssertEqual(game.progression.completedCycles, 4)
        XCTAssertEqual(game.progression.level, 47)
        XCTAssertEqual(game.species.slug, "pikachu")
        XCTAssertEqual(HallOfFame.rows(game.progression).count, 5)
        XCTAssertTrue(game.onboardingCompleted)
    }
}

final class SetupResourcesTests: XCTestCase {
    func testEveryEquipmentIconIsAPDFAndItsSourceIsKept() throws {
        for equipment in Equipment.ownable {
            let name = Equipment.iconName(equipment)
            let pdf = try XCTUnwrap(AppResources.url("Icons/\(name).pdf"), "\(name).pdf")
            XCTAssertNotNil(NSImage(contentsOf: pdf), name)
            XCTAssertNotNil(AppResources.url("Icons/\(name).svg"), "\(name).svg is the source")
        }
        XCTAssertNotNil(AppResources.url("Icons/LICENSE-tabler-icons.txt"))
    }

    func testTheIconsAreTheTablerOnesOfTheDesign() {
        XCTAssertEqual(Equipment.ownable.map(Equipment.iconName), ["wave-sine", "cylinder", "ball-volleyball", "ball-basketball", "weight", "barbell"])
    }

    func testHoveringSpeciesWithoutAnIdleSheetUseWalk() throws {
        try requireSprites()
        for dex in [15, 148] {
            XCTAssertNil(SpriteLibrary.sheet(SpriteRef(dex: dex, shiny: false), animation: "Idle", requireExactFile: true), "\(dex) has no Idle")
            XCTAssertEqual(SpriteLibrary.sheet(SpriteRef(dex: dex, shiny: false), animation: "Idle")?.name, "Walk")
            XCTAssertNotNil(SpriteLibrary.idleFrame(SpriteRef(dex: dex, shiny: false)))
        }
        XCTAssertTrue(LineCatalog.available.contains { $0.id == "weedle" }, "Aspicot's line is there")
        XCTAssertTrue(LineCatalog.available.contains { $0.id == "dratini" }, "Minidraco's line is there")
        XCTAssertEqual(LineCatalog.available.count, LineCatalog.all.count, "every Gen 1 line is available")
    }

    func testEverySpeciesOfTheCatalogHasAStillPicture() throws {
        try requireSprites()
        for species in LineCatalog.available.flatMap(\.allSpecies) {
            XCTAssertNotNil(SpriteLibrary.idleFrame(SpriteRef(dex: species.dex, shiny: false)), species.slug)
        }
    }

    func testLocalizationKeysAreUnique() throws {
        for language in ["en", "fr"] {
            let url = try XCTUnwrap(L10n.bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language))
            // The compiled file is a dictionary: duplicates are checked in the source file.
            _ = url
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/Stretchu/Localization/\(language).lproj/Localizable.strings")
            let text = try String(contentsOf: source, encoding: .utf8)
            let keys = try NSRegularExpression(pattern: #"(?m)^"([^"]+)" ="#).matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { String(text[Range($0.range(at: 1), in: text)!]) }
            XCTAssertEqual(Set(keys).count, keys.count, "\(language): duplicate keys \(Dictionary(grouping: keys, by: { $0 }).filter { $1.count > 1 }.keys.sorted())")
        }
    }
}
