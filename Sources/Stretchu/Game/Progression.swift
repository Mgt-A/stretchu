import Foundation

/// What happened during a game action, for the interface.
enum GameEvent: Equatable {
    case xpGained(Int, multiplier: Double)
    case leveledUp(from: Int, to: Int)
    case speciesReached(Species)
    case cycleCompleted(cycle: Int)
    case streakBroken
    case candyEarned
}

/// XP and cycles. The XP counts within the current cycle (the last one of `cycles`); see `XPRules`.
struct Progression: Codable, Equatable {
    static let maxLevel = XPRules.maxLevel

    var xp: Int = 0
    /// The current cycle is the last one, the others are completed. Never empty.
    var cycles: [Cycle] = [Cycle()]

    init(xp: Int = 0, cycles: [Cycle] = [Cycle()]) {
        self.xp = xp
        self.cycles = cycles.isEmpty ? [Cycle()] : cycles
        syncReached()
    }

    /// `completedCycles` finished cycles (Pikachu line, no dates) followed by a current one.
    init(xp: Int, completedCycles: Int) {
        self.init(xp: xp, cycles: Array(repeating: Cycle(reachedDexes: PokemonLine.pikachu.species.map(\.dex)), count: max(0, completedCycles)) + [Cycle()])
    }

    private enum CodingKeys: String, CodingKey { case xp, cycles }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        let decoded = try c.decodeIfPresent([Cycle].self, forKey: .cycles) ?? []
        cycles = decoded.isEmpty ? [Cycle()] : decoded
        syncReached()
    }

    static func totalXP(forLevel n: Int) -> Int { XPRules.totalXP(forLevel: n) }
    static func level(forXP xp: Int) -> Int { XPRules.level(forXP: xp) }

    var level: Int { Self.level(forXP: xp) }

    var current: Cycle {
        get { cycles[cycles.count - 1] }
        set { cycles[cycles.count - 1] = newValue }
    }

    /// Cycles before the current one: the Hall of Fame.
    var completedCycleList: [Cycle] { Array(cycles.dropLast()) }
    var completedCycles: Int { cycles.count - 1 }

    /// Species shown for this level in a line (the branch choice decides the last one).
    func species(in line: PokemonLine, branchDex: Int? = nil) -> Species {
        line.species(atLevel: level, branchDex: branchDex)
    }

    /// XP of the next level, nil at level 100.
    var nextLevelXP: Int? {
        level >= Self.maxLevel ? nil : Self.totalXP(forLevel: level + 1)
    }

    /// 0...1 between the current level and the next.
    var fractionToNextLevel: Double {
        guard let next = nextLevelXP else { return 1 }
        let start = Self.totalXP(forLevel: level)
        return Double(xp - start) / Double(next - start)
    }

    /// Marks as reached every species of the current cycle's line up to the current level
    /// (a level jump, a Debug setting, still passes through the stages below).
    mutating func syncReached(line: PokemonLine? = nil) {
        let line = line ?? LineCatalog.line(for: current.pokemon)
        let reached = line.chain(branchDex: current.branchDex).filter { $0.level <= level }.map(\.dex)
        for dex in reached where !current.reachedDexes.contains(dex) { current.reachedDexes.append(dex) }
    }

    /// Adds XP. At 1,000,000 XP (level 100) the cycle ends: it enters the Hall of Fame, a new cycle
    /// of the same line starts at level 1 (XP back to 0, shiny and branch decided afresh).
    mutating func gain(_ amount: Int, now: Date, line: PokemonLine? = nil) -> [GameEvent] {
        let line = line ?? LineCatalog.line(for: current.pokemon)
        let branchDex = current.branchDex
        let levelBefore = level
        let speciesBefore = species(in: line, branchDex: branchDex)
        xp += amount

        if xp >= XPRules.maxXP {
            xp = XPRules.maxXP
            syncReached(line: line)
            current.endedAt = now
            xp = 0
            cycles.append(Cycle(lineId: line.id, startedAt: now, stats: CycleStats()))
            syncReached(line: line)
            return [.cycleCompleted(cycle: completedCycles)]
        }

        var events: [GameEvent] = []
        if level > levelBefore { events.append(.leveledUp(from: levelBefore, to: level)) }
        let speciesAfter = species(in: line, branchDex: branchDex)
        if speciesAfter != speciesBefore { events.append(.speciesReached(speciesAfter)) }
        syncReached(line: line)
        return events
    }

    /// Direct setting (Debug): puts the XP at the level's threshold.
    mutating func setLevel(_ n: Int) {
        xp = Self.totalXP(forLevel: min(max(n, 1), Self.maxLevel))
        syncReached()
    }

    /// Direct setting (Debug): makes the Hall of Fame hold `count` completed cycles.
    mutating func setCompletedCycles(_ count: Int) {
        let target = max(0, count)
        while completedCycles < target {
            cycles.insert(Cycle(reachedDexes: PokemonLine.pikachu.species.map(\.dex)), at: 0)
        }
        while completedCycles > target { cycles.removeFirst() }
    }
}
