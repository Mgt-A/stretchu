import Foundation

/// What the Level up panel shows, derived from the events of a game action.
struct LevelUp: Equatable {
    var level: Int
    /// Species after the action.
    var species: Species
    var newSpecies: Bool
    var xpGained: Int
    var cycleCompleted: Bool
    /// A Rare Candy came with this break.
    var candyEarned = false
    /// The species that enters the Hall of Fame when a cycle completes.
    var finalSpecies: Species?

    static func from(_ events: [GameEvent], current: Species, currentLevel: Int = 1, finalSpecies: Species? = nil) -> LevelUp? {
        var level: Int?
        var newSpecies = false
        var xp = 0
        var cycle = false
        var candy = false
        for event in events {
            switch event {
            case let .leveledUp(_, to): level = to
            case .speciesReached: newSpecies = true
            case let .xpGained(value, _): xp = value
            case .cycleCompleted: cycle = true
            case .streakBroken: break
            case .candyEarned: candy = true
            }
        }
        if cycle {
            return LevelUp(level: Progression.maxLevel, species: current, newSpecies: false, xpGained: xp,
                           cycleCompleted: true, candyEarned: candy, finalSpecies: finalSpecies ?? current)
        }
        // A candy alone still shows the panel, at the current level.
        guard let level = level ?? (candy ? currentLevel : nil) else { return nil }
        return LevelUp(level: level, species: current, newSpecies: newSpecies, xpGained: xp,
                       cycleCompleted: false, candyEarned: candy, finalSpecies: nil)
    }
}
