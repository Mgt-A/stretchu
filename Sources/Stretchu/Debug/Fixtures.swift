#if STRETCHU_DEBUG
import Foundation

/// Prepared states. The same values live in Tests/Fixtures/*.json
/// for `make demo STATE=<name>`; FixturesTests checks they stay identical.
/// No `currentDay`: the state adopts the current day on load, otherwise the streak
/// would fall on the very first tick.
struct Fixture {
    let name: String
    let description: String
    let state: GameState
}

enum Fixtures {
    private static func state(xp: Int, streak: Int, breaks: Int, pokemon: CurrentPokemon = CurrentPokemon()) -> GameState {
        var g = GameState()
        g.onboardingCompleted = true
        g.progression = Progression(xp: xp)
        g.pokemon = pokemon
        g.streak = Streak(count: streak, breaksToday: breaks, currentDay: nil)
        return g
    }

    private static func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    /// Four completed cycles (one shiny) and a Pikachu at level 47: the Hall of Fame has something to show.
    private static func hallOfFame() -> GameState {
        var g = state(xp: 221_000, streak: 20, breaks: 3)
        g.progression.cycles = [
            Cycle(lineId: "pikachu", startedAt: date("2026-08-18T08:00:00Z"), endedAt: date("2026-08-29T08:00:00Z"), reachedDexes: [25, 26]),
            Cycle(lineId: "bulbasaur", startedAt: date("2026-09-01T08:00:00Z"), endedAt: date("2026-09-12T08:00:00Z"), reachedDexes: [1, 2, 3]),
            Cycle(lineId: "charmander", startedAt: date("2026-09-15T08:00:00Z"), endedAt: date("2026-09-26T08:00:00Z"), shiny: true, reachedDexes: [4, 5, 6]),
            Cycle(lineId: "pikachu", startedAt: date("2026-09-29T08:00:00Z"), endedAt: date("2026-10-09T08:00:00Z"), reachedDexes: [25, 26]),
            Cycle(lineId: "pikachu", startedAt: date("2026-10-13T08:00:00Z")),
        ]
        g.progression.syncReached()
        return g
    }

    static let all: [Fixture] = [
        // Old-format files (n³ curve, no lines): they load as the Pikachu line, XP migrated
        // (level and fraction of level kept). The values below are what the migration gives.
        Fixture(name: "lv1", description: tr("fixture.lv1"), state: state(xp: 0, streak: 0, breaks: 0)),
        Fixture(name: "lv32-almost", description: tr("fixture.lv32"), state: state(xp: 108_898, streak: 5, breaks: 2)),
        Fixture(name: "lv33-x2", description: tr("fixture.lv33"), state: state(xp: 108_900, streak: 1, breaks: 1)),
        Fixture(name: "lv65-x5", description: tr("fixture.lv65"), state: state(xp: 422_500, streak: 40, breaks: 5)),
        Fixture(name: "lv99-streak39", description: tr("fixture.lv99"), state: state(xp: 999_665, streak: 39, breaks: 4)),
        // Current format, with a line.
        Fixture(name: "pikachu-lv49-almost", description: tr("fixture.pikachuLv49"),
                state: state(xp: 249_999, streak: 5, breaks: 2, pokemon: CurrentPokemon(lineId: "pikachu"))),
        Fixture(name: "charmander-lv32-almost", description: tr("fixture.charmanderLv32"),
                state: state(xp: 108_899, streak: 5, breaks: 2, pokemon: CurrentPokemon(lineId: "charmander"))),
        Fixture(name: "eevee-lv49-almost", description: tr("fixture.eeveeLv49"),
                state: state(xp: 249_999, streak: 5, breaks: 2, pokemon: CurrentPokemon(lineId: "eevee"))),
        Fixture(name: "eevee-flareon-shiny-lv60", description: tr("fixture.flareonShiny"),
                state: state(xp: 360_000, streak: 10, breaks: 3,
                             pokemon: CurrentPokemon(lineId: "eevee", shiny: true, branchDex: 136))),
        Fixture(name: "hall-of-fame-4-cycles", description: tr("fixture.hof4"), state: hallOfFame()),
    ]

    static func state(_ name: String) -> GameState? {
        all.first { $0.name == name }?.state
    }
}
#endif
