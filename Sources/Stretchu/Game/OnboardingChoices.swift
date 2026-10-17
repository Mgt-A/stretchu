import Foundation

/// What the setup window decides. Skipping it applies `defaults`.
struct OnboardingChoices: Equatable {
    /// nil follows the Mac's language.
    var language: String?
    /// nil keeps the current Pokémon (the step is locked while a cycle is running).
    var lineId: String?
    /// The shiny drawn when the player pressed Continue on the Pokémon step; nil draws now.
    var shiny: Bool?
    var homeEquipment: [String]
    var officeEquipment: [String]
    var programId: String
    var workMinutes: Int
    var step2Seconds: Int
    var schedule = ActiveSchedule()

    /// Pikachu, the general program, no equipment, the standard rhythm.
    static let defaults = OnboardingChoices(
        language: nil, lineId: LineCatalog.defaultLineId, shiny: nil, homeEquipment: [], officeEquipment: [],
        programId: ProgramLibrary.generalId, workMinutes: 25, step2Seconds: 30)

    /// The current values, to replay the setup without losing anything.
    static func current(of game: GameState) -> OnboardingChoices {
        OnboardingChoices(
            language: game.language, lineId: nil, shiny: nil,
            homeEquipment: game.settings.homeEquipment, officeEquipment: game.settings.officeEquipment,
            programId: game.programId, workMinutes: game.settings.workMinutes, step2Seconds: game.settings.step2Seconds,
            schedule: game.settings.schedule)
    }

    /// Writes the choices in the state and marks the setup as done. The XP, the streak and the
    /// cycles are never touched; the Pokémon only changes when `lineId` is given.
    func apply(to game: inout GameState, calendar: Calendar = .current, now: Date = Date(),
               random: () -> Double = { Double.random(in: 0..<1) }) {
        game.language = language
        if let lineId {
            let line = LineCatalog.line(id: lineId) ?? .pikachu
            var cycle = game.progression.current
            let changed = cycle.lineId != line.id
            cycle.lineId = line.id
            if changed { cycle.branchDex = nil; cycle.reachedDexes = [] }
            cycle.shiny = cycle.afterAbandon ? false : (shiny ?? LineCatalog.rollShiny(for: line, random: random))
            game.progression.current = cycle
            game.progression.syncReached(line: line)
        }
        game.settings.homeEquipment = Equipment.ownable.filter(Set(homeEquipment).contains)
        game.settings.officeEquipment = Equipment.ownable.filter(Set(officeEquipment).contains)
        game.programId = programId
        game.settings.workMinutes = workMinutes
        game.settings.step2Seconds = step2Seconds
        game.settings.schedule = schedule
        game.settings = game.settings.clamped()
        game.onboardingCompleted = true
    }
}
