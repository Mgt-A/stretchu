import Foundation

/// Mood of the Pokémon in the menu and the companion, shown through its animation:
/// asleep outside the active hours, hurt after a skip until the next completed break, hopping once
/// the streak has reached the top multiplier (×5), at rest otherwise. The status bar icon stays still.
enum Mood: String, Equatable {
    case sleep, hurt, idle, hop

    static func forStreak(_ count: Int, asleep: Bool, skipped: Bool = false) -> Mood {
        if asleep { return .sleep }
        if skipped { return .hurt }
        return Streak.multiplier(forStreak: count) >= XPRules.maxMultiplier ? .hop : .idle
    }

    var animationName: String {
        switch self {
        case .sleep: "Sleep"
        case .hurt: "Hurt"
        case .idle: "Idle"
        case .hop: "Hop"
        }
    }
}
