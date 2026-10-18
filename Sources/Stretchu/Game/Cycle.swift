import Foundation

/// One run of a Pokémon from level 1 to level 100. The current cycle is the last one of the list;
/// the others are completed (the Hall of Fame).
struct Cycle: Codable, Equatable {
    var lineId: String
    /// nil for the cycles that existed before dates were recorded.
    var startedAt: Date?
    /// nil while the cycle is the current one.
    var endedAt: Date?
    var shiny: Bool
    /// Pokédex number of the chosen branch option (Eevee), nil until chosen.
    var branchDex: Int?
    /// Species of the line whose stage was reached at least once during this cycle.
    var reachedDexes: [Int]
    /// The cycle started after an abandon: no shiny draw, so abandoning can't be used to fish for one.
    var afterAbandon: Bool
    /// Health counters of the cycle. nil for the cycles that existed before they were counted.
    var stats: CycleStats?

    init(lineId: String = LineCatalog.defaultLineId, startedAt: Date? = nil, endedAt: Date? = nil,
         shiny: Bool = false, branchDex: Int? = nil, reachedDexes: [Int] = [], afterAbandon: Bool = false,
         stats: CycleStats? = nil) {
        self.lineId = lineId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.shiny = shiny
        self.branchDex = branchDex
        self.reachedDexes = reachedDexes
        self.afterAbandon = afterAbandon
        self.stats = stats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lineId = try c.decodeIfPresent(String.self, forKey: .lineId) ?? LineCatalog.defaultLineId
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        shiny = try c.decodeIfPresent(Bool.self, forKey: .shiny) ?? false
        branchDex = try c.decodeIfPresent(Int.self, forKey: .branchDex)
        reachedDexes = try c.decodeIfPresent([Int].self, forKey: .reachedDexes) ?? []
        afterAbandon = try c.decodeIfPresent(Bool.self, forKey: .afterAbandon) ?? false
        stats = try c.decodeIfPresent(CycleStats.self, forKey: .stats)
    }

    var pokemon: CurrentPokemon { CurrentPokemon(lineId: lineId, shiny: shiny, branchDex: branchDex) }

    /// Length in calendar days, nil when a date is unknown.
    func days(calendar: Calendar = .current, now: Date) -> Int? {
        guard let startedAt else { return nil }
        let start = calendar.startOfDay(for: startedAt)
        let end = calendar.startOfDay(for: endedAt ?? now)
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

/// What the player did during a cycle, counted as it goes. Breaks outside the active hours count
/// as done (and make their day active); a skip of such a break is not counted.
struct CycleStats: Codable, Equatable {
    var breaks = 0
    var skips = 0
    /// The longest streak reached during the cycle.
    var bestStreak = 0
    /// Days with at least one break.
    var activeDays = 0
    /// Most breaks done in one day.
    var bestDay = 0
    private var lastDay: Date?
    private var lastDayBreaks = 0

    init() {}

    mutating func recordBreak(streak: Int, now: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: now)
        if lastDay != day {
            lastDay = day
            lastDayBreaks = 0
            activeDays += 1
        }
        breaks += 1
        lastDayBreaks += 1
        bestDay = max(bestDay, lastDayBreaks)
        bestStreak = max(bestStreak, streak)
    }

    mutating func recordSkip() { skips += 1 }

    /// Share of the breaks that were skipped, 0...1; nil before the first one.
    var skipRate: Double? {
        let total = breaks + skips
        return total == 0 ? nil : Double(skips) / Double(total)
    }

    /// Breaks per active day; nil before the first one.
    var breaksPerActiveDay: Double? { activeDays == 0 ? nil : Double(breaks) / Double(activeDays) }
}

/// Pokédex completion: species whose stage was reached at least once, over the species of the
/// lines that were downloaded.
enum Pokedex {
    struct Completion: Equatable {
        let obtained: Int
        let total: Int
    }

    static func completion(cycles: [Cycle], lines: [PokemonLine] = LineCatalog.available) -> Completion {
        let available = Set(lines.flatMap(\.allSpecies).map(\.dex))
        let reached = Set(cycles.flatMap(\.reachedDexes))
        return Completion(obtained: reached.intersection(available).count, total: available.count)
    }
}

extension Pokedex {
    /// Every species reached at least once, by any cycle (the current one included).
    static func obtainedDexes(_ cycles: [Cycle]) -> Set<Int> {
        Set(cycles.flatMap(\.reachedDexes))
    }

    /// Species reached during a shiny cycle.
    static func shinyDexes(_ cycles: [Cycle]) -> Set<Int> {
        Set(cycles.filter(\.shiny).flatMap(\.reachedDexes))
    }

    /// How many times each line was completed (the cycles before the current one).
    static func completedCounts(_ cycles: [Cycle]) -> [String: Int] {
        cycles.dropLast().reduce(into: [:]) { $0[$1.lineId, default: 0] += 1 }
    }
}

/// One line of the Hall of Fame page.
struct HallOfFameRow: Identifiable, Equatable {
    let id: Int
    let cycle: Cycle
    let isCurrent: Bool
    /// Species reached during the cycle, in evolution order.
    let species: [Species]

    /// The name of a cycle is the last stage reached.
    var title: Species? { species.last }
}

enum HallOfFame {
    /// The current cycle first, then the completed ones from the most recent to the oldest.
    static func rows(_ progression: Progression) -> [HallOfFameRow] {
        let cycles = progression.cycles
        return cycles.indices.reversed().map { index in
            let cycle = cycles[index]
            let line = LineCatalog.line(for: cycle.pokemon)
            let reached = line.allSpecies.filter { cycle.reachedDexes.contains($0.dex) }
            return HallOfFameRow(id: index, cycle: cycle, isCurrent: index == cycles.count - 1,
                                 species: reached.isEmpty ? [line.base] : reached)
        }
    }

    struct Summary: Equatable {
        let pokedex: Pokedex.Completion
        let linesCompleted: Int
        let linesTotal: Int
        let cycles: Int
    }

    static func summary(_ progression: Progression, lines: [PokemonLine] = LineCatalog.available) -> Summary {
        let availableIds = Set(lines.map(\.id))
        let completed = Set(progression.completedCycleList.map(\.lineId)).intersection(availableIds)
        return Summary(pokedex: Pokedex.completion(cycles: progression.cycles, lines: lines),
                       linesCompleted: completed.count, linesTotal: lines.count, cycles: progression.completedCycles)
    }

    /// Lines for the choice grid: finished ones first, then by Pokédex number of the base form.
    static func choiceOrder(_ lines: [PokemonLine], completedCounts: [String: Int]) -> [PokemonLine] {
        lines.sorted {
            let a = completedCounts[$0.id, default: 0] > 0, b = completedCounts[$1.id, default: 0] > 0
            return a != b ? a : $0.base.dex < $1.base.dex
        }
    }
}
