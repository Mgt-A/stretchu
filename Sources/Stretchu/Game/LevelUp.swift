import Foundation

/// What the Level up panel shows, derived from the events of a game action.
struct LevelUp: Equatable {
    var level: Int
    /// Species after the action.
    var species: Species
    var newSpecies: Bool
    var xpGained: Int
    var cycleCompleted: Bool
    /// The species that enters the Hall of Fame when a cycle completes.
    var finalSpecies: Species?

    static func from(_ events: [GameEvent], current: Species, finalSpecies: Species? = nil) -> LevelUp? {
        var level: Int?
        var newSpecies = false
        var xp = 0
        var cycle = false
        for event in events {
            switch event {
            case let .leveledUp(_, to): level = to
            case .speciesReached: newSpecies = true
            case let .xpGained(value, _): xp = value
            case .cycleCompleted: cycle = true
            case .streakBroken: break
            }
        }
        if cycle {
            return LevelUp(level: Progression.maxLevel, species: current, newSpecies: false, xpGained: xp,
                           cycleCompleted: true, finalSpecies: finalSpecies ?? current)
        }
        guard let level else { return nil }
        return LevelUp(level: level, species: current, newSpecies: newSpecies, xpGained: xp,
                       cycleCompleted: false, finalSpecies: nil)
    }
}
