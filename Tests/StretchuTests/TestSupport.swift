import Foundation
import XCTest
@testable import Stretchu

/// Test clock: only moves when told to.
final class FakeClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = TestCalendar.date(2026, 10, 19, 9, 0)) { current = start }

    var now: Date { lock.withLock { current } }

    func advance(_ seconds: TimeInterval) { lock.withLock { current = current.addingTimeInterval(seconds) } }
    func set(_ date: Date) { lock.withLock { current = date } }
}

enum TestCalendar {
    /// Gregorian, UTC, so tests don't depend on the machine.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // Reference week: Monday, October 19, 2026.
    static let monday = date(2026, 10, 19)
    static let tuesday = date(2026, 10, 20)
    static let wednesday = date(2026, 10, 21)
    static let thursday = date(2026, 10, 22)
    static let friday = date(2026, 10, 23)
    static let saturday = date(2026, 10, 24)
    static let sunday = date(2026, 10, 25)
    static let nextMonday = date(2026, 10, 26)
}

/// Pure lines for the tests that don't need the downloaded sprites.
extension PokemonLine {
    static let charmander = PokemonLine(
        id: "charmander",
        species: [
            Species(dex: 4, slug: "charmander", names: ["en": "Charmander", "fr": "Salamèche"], level: 1),
            Species(dex: 5, slug: "charmeleon", names: ["en": "Charmeleon", "fr": "Reptincel"], level: 33),
            Species(dex: 6, slug: "charizard", names: ["en": "Charizard", "fr": "Dracaufeu"], level: 66),
        ],
        branch: nil)
    static let ditto = PokemonLine(
        id: "ditto", species: [Species(dex: 132, slug: "ditto", names: ["en": "Ditto", "fr": "Métamorph"], level: 1)], branch: nil)
    static let eevee = PokemonLine(
        id: "eevee",
        species: [Species(dex: 133, slug: "eevee", names: ["en": "Eevee", "fr": "Évoli"], level: 1)],
        branch: Branch(level: 50, options: [
            BranchOption(stone: "water-stone", stoneNames: ["en": "Water Stone", "fr": "Pierre Eau"], dex: 134, slug: "vaporeon", names: ["en": "Vaporeon", "fr": "Aquali"]),
            BranchOption(stone: "thunder-stone", stoneNames: ["en": "Thunder Stone", "fr": "Pierre Foudre"], dex: 135, slug: "jolteon", names: ["en": "Jolteon", "fr": "Voltali"]),
            BranchOption(stone: "fire-stone", stoneNames: ["en": "Fire Stone", "fr": "Pierre Feu"], dex: 136, slug: "flareon", names: ["en": "Flareon", "fr": "Pyroli"]),
        ]))
}

/// Sprites are downloaded by `make sprites`; the tests that read them are skipped without.
func requireSprites() throws {
    try XCTSkipIf(LineCatalog.available.count < 10, "sprites not downloaded: run make sprites")
}
