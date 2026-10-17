import Foundation

/// The progression as it may be on disk: the current format, or one of the older ones.
private struct StoredProgression: Decodable {
    var xp = 0
    var cycles: [Cycle]?
    /// Old formats: a number of completed cycles and a Hall of Fame list.
    var completedCycles: Int?
    var hallOfFame: [LegacyHallOfFameEntry] = []

    struct LegacyHallOfFameEntry: Decodable {
        var date: Date
        var cycle: Int
    }

    private enum CodingKeys: String, CodingKey { case xp, cycles, completedCycles, hallOfFame }
    private enum LegacyKeys: String, CodingKey { case completedCycles = "cyclesTermines" }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        cycles = try c.decodeIfPresent([Cycle].self, forKey: .cycles)
        completedCycles = try c.decodeIfPresent(Int.self, forKey: .completedCycles)
            ?? old.decodeIfPresent(Int.self, forKey: .completedCycles)
        hallOfFame = try c.decodeIfPresent([LegacyHallOfFameEntry].self, forKey: .hallOfFame) ?? []
    }

    /// Builds the current format. `version` is the schema the file was written with: before 4 the
    /// XP followed the n³ curve and is recomputed, keeping the level and the fraction of level.
    /// The old Hall of Fame entries become Pikachu-line cycles without a start date.
    func build(version: Int, pokemon: CurrentPokemon?) -> Progression {
        if let cycles, !cycles.isEmpty { return Progression(xp: xp, cycles: cycles) }
        let migratedXP = version < 4 ? XPRules.migratedXP(fromLegacy: xp) : xp
        let pikachuDexes = PokemonLine.pikachu.species.map(\.dex)
        var past = hallOfFame.sorted { $0.cycle < $1.cycle }.map {
            Cycle(lineId: "pikachu", startedAt: nil, endedAt: $0.date, reachedDexes: pikachuDexes)
        }
        // A count higher than the list (set by hand): the missing cycles have no date at all.
        let missing = max(0, (completedCycles ?? 0) - past.count)
        past.insert(contentsOf: Array(repeating: Cycle(lineId: "pikachu", reachedDexes: pikachuDexes), count: missing), at: 0)
        let current = Cycle(lineId: pokemon?.lineId ?? LineCatalog.defaultLineId, startedAt: nil, endedAt: nil,
                            shiny: pokemon?.shiny ?? false, branchDex: pokemon?.branchDex)
        return Progression(xp: migratedXP, cycles: past + [current])
    }
}

/// Everything that is persisted: progression, streak, hidden exercises.
struct GameState: Codable, Equatable {
    /// 1: French-named keys (`serie`, `reglages`…). 2: English keys; the old ones are still read.
    /// 3: the current Pokémon (`pokemon`); a state without it was a Pichu and becomes a Pikachu.
    /// 6: `onboardingCompleted` and `language`.
    /// 5: the program (`programId`) and the equipment of the home and the office.
    /// 4: XP on the 100 × n² curve, and the Hall of Fame is the list of `progression.cycles`
    /// (the current Pokémon lives in the last cycle). Older files are migrated when read.
    static let currentSchemaVersion = 6

    var schemaVersion: Int = GameState.currentSchemaVersion
    var progression = Progression()
    var streak = Streak()
    var excludedExercises: [String] = []
    var dailyPicks = DailyPicks()
    /// SSID → mode, entered in the menu and in Settings.
    var networks: [String: PlaceMode] = [:]
    var settings = UserSettings()
    /// "general", or the name (without extension) of a file of the user's programs folder.
    var programId = ProgramLibrary.generalId
    /// False until the setup window was finished (or skipped). A state file that exists without
    /// the key comes from before the setup existed: it is done.
    var onboardingCompleted = false
    /// Interface language chosen by the player, nil to follow the Mac's.
    var language: String?

    init() {}

    /// Line, shiny and branch of the current companion: they live in the current cycle.
    var pokemon: CurrentPokemon {
        get { progression.current.pokemon }
        set {
            // The species reached belong to the line: another line starts from its own first species.
            if progression.current.lineId != newValue.lineId { progression.current.reachedDexes = [] }
            progression.current.lineId = newValue.lineId
            progression.current.shiny = newValue.shiny
            progression.current.branchDex = newValue.branchDex
            progression.syncReached()
        }
    }

    var line: PokemonLine { LineCatalog.line(for: pokemon) }
    var species: Species { progression.species(in: line, branchDex: pokemon.branchDex) }
    var sprite: SpriteRef { SpriteRef(dex: species.dex, shiny: pokemon.shiny) }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, progression, streak, excludedExercises, dailyPicks, networks, settings, programId
        case onboardingCompleted, language
        /// Written by schema 3 only, read to migrate.
        case pokemon
    }

    /// Keys written by the French-named builds, read as a fallback.
    private enum LegacyKeys: String, CodingKey {
        case excludedExercises = "exercicesExclus", dailyPicks = "exercicesDuJour"
        case networks = "reseaux", settings = "reglages"
    }

    // Older states (and fixtures) don't have every key: defaults apply. Whatever was read is
    // now in the current format, so the version is the current one.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)
        let storedVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let legacyPokemon = try c.decodeIfPresent(CurrentPokemon.self, forKey: .pokemon)
        progression = (try c.decodeIfPresent(StoredProgression.self, forKey: .progression) ?? StoredProgression())
            .build(version: storedVersion, pokemon: legacyPokemon)
        progression.syncReached()
        streak = try c.decodeIfPresent(Streak.self, forKey: .streak) ?? Streak()
        excludedExercises = try c.decodeIfPresent([String].self, forKey: .excludedExercises)
            ?? old.decodeIfPresent([String].self, forKey: .excludedExercises) ?? []
        dailyPicks = try c.decodeIfPresent(DailyPicks.self, forKey: .dailyPicks)
            ?? old.decodeIfPresent(DailyPicks.self, forKey: .dailyPicks) ?? DailyPicks()
        networks = try c.decodeIfPresent([String: PlaceMode].self, forKey: .networks)
            ?? old.decodeIfPresent([String: PlaceMode].self, forKey: .networks) ?? [:]
        settings = try c.decodeIfPresent(UserSettings.self, forKey: .settings)
            ?? old.decodeIfPresent(UserSettings.self, forKey: .settings) ?? UserSettings()
        programId = try c.decodeIfPresent(String.self, forKey: .programId) ?? ProgramLibrary.generalId
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? true
        language = try c.decodeIfPresent(String.self, forKey: .language)
        schemaVersion = Self.currentSchemaVersion
    }

    /// `pokemon` is not written: it lives in the current cycle.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(progression, forKey: .progression)
        try c.encode(streak, forKey: .streak)
        try c.encode(excludedExercises, forKey: .excludedExercises)
        try c.encode(dailyPicks, forKey: .dailyPicks)
        try c.encode(networks, forKey: .networks)
        try c.encode(settings, forKey: .settings)
        try c.encode(programId, forKey: .programId)
        try c.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try c.encodeIfPresent(language, forKey: .language)
    }

    /// Applies a scheduler event. Only `.breakCompleted` and `.skipped` touch the progression:
    /// snoozing, wake-up and meetings have no effect. A break the player asked for outside the
    /// active hours (`outsideHours`) gives its XP with the multiplier of the streak, but the streak
    /// does not move: no +1, not counted in the day's breaks, and skipping it breaks nothing.
    mutating func apply(_ event: SchedulerEvent, now: Date, calendar: Calendar = .current, outsideHours: Bool = false,
                        random: () -> Double = { Double.random(in: 0..<1) }) -> [GameEvent] {
        syncStreak(now: now, calendar: calendar)
        switch event {
        case .breakCompleted:
            let multiplier = streak.multiplier // the one from before the increment
            let xp = Streak.earnedXP(base: XPRules.breakXP, streak: streak.count)
            if !outsideHours { streak.completeBreak() }
            let events = progression.gain(xp, now: now, line: line)
            startNewCycleIfNeeded(after: events, random: random)
            return [.xpGained(xp, multiplier: multiplier)] + events
        case .skipped:
            guard !outsideHours else { return [] }
            let hadStreak = streak.count > 0
            streak.skip()
            return hadStreak ? [.streakBroken] : []
        case .wakeUp, .wakeUpDeferred, .snoozed, .step2Started:
            return []
        }
    }

    /// Brings the streak to today, with the days the player chose.
    mutating func syncStreak(now: Date, calendar: Calendar = .current) {
        streak.sync(now: now, calendar: calendar, days: settings.schedule.days)
    }

    /// When a cycle just ended, the next one starts with the same line (the choice screen comes
    /// later): the shiny is drawn afresh, 20 %, with an injectable source.
    private mutating func startNewCycleIfNeeded(after events: [GameEvent], random: () -> Double) {
        guard events.contains(where: { if case .cycleCompleted = $0 { true } else { false } }) else { return }
        progression.current.shiny = LineCatalog.rollShiny(for: line, random: random)
    }

    // MARK: choosing a Pokémon

    /// Chooses the Pokémon of the cycle that just started: a new line, a fresh shiny draw (20 %,
    /// injectable) unless the cycle follows an abandon. The XP and the streak are not touched.
    /// `shiny` is the result of the random draw, already made; nil draws it here (20 %).
    mutating func chooseNextPokemon(lineId: String, shiny: Bool? = nil, random: () -> Double = { Double.random(in: 0..<1) }) {
        let line = LineCatalog.line(id: lineId) ?? .pikachu
        var cycle = progression.current
        cycle.lineId = line.id
        cycle.branchDex = nil
        cycle.reachedDexes = []
        cycle.shiny = cycle.afterAbandon ? false : (shiny ?? LineCatalog.rollShiny(for: line, random: random))
        progression.current = cycle
        progression.syncReached(line: line)
    }

    /// Gives up the current cycle: it disappears (neither in the Hall of Fame nor in the Pokédex),
    /// the Pokémon goes back to level 1 and the streak and multiplier are kept. The cycle that
    /// replaces it never has a shiny draw, so abandoning can't be used to fish for one.
    mutating func abandonCurrentCycle(now: Date) {
        let lineId = progression.current.lineId
        progression.cycles.removeLast()
        progression.cycles.append(Cycle(lineId: lineId, startedAt: now, afterAbandon: true))
        progression.xp = 0
        progression.syncReached()
    }

    /// Picks the evolution stone of a branching line (Eevee). Only once the branch level is reached.
    @discardableResult
    mutating func chooseBranch(dex: Int) -> [GameEvent] {
        guard let branch = line.branch, progression.level >= branch.level,
              branch.options.contains(where: { $0.dex == dex }), pokemon.branchDex == nil else { return [] }
        pokemon.branchDex = dex
        return [.speciesReached(species)]
    }

    /// The branch level was reached and no stone chosen yet.
    var needsBranchChoice: Bool {
        line.needsBranchChoice(atLevel: progression.level, branchDex: pokemon.branchDex)
    }
}
