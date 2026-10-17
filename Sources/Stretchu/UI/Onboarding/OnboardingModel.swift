import Foundation
import Observation

/// The state of the setup window: six steps, a draft of the choices, applied at the end.
@MainActor
@Observable
final class OnboardingModel {
    enum Mode { case firstLaunch, relaunch }

    enum Step: Int, CaseIterable {
        case welcome, pokemon, equipment, program, access, ready
    }

    @ObservationIgnored let app: AppModel
    @ObservationIgnored let mode: Mode
    /// The injectable source of the shiny draw (20 %).
    @ObservationIgnored var random: () -> Double = { Double.random(in: 0..<1) }
    /// Called when the window should close; `true` when the choices were applied.
    @ObservationIgnored var onDone: ((Bool) -> Void)?

    private(set) var step: Step = .welcome
    /// The language the interface shows right now (the Mac's unless the player picked one).
    var language: String
    var lineId: String
    var homeEquipment: Set<String>
    var officeEquipment: Set<String>
    var equipmentPlace: PlaceMode = .home
    var programId: String
    var workMinutes: Int
    var step2Seconds: Int
    var schedule: ActiveSchedule
    var launchAtLogin: Bool
    var programMessage: String?
    /// The random draw being played, if any: the window shows it instead of the steps.
    var randomDraw: RandomPick.Draw?
    /// One shiny draw per line chosen, made when the player presses Continue on the Pokémon step.
    private(set) var shinyByLine: [String: Bool] = [:]
    /// The original language, to put back if the player cancels a replay of the setup.
    @ObservationIgnored private let originalLanguage: String?
    private var importedId: String?

    /// While a cycle is running the Pokémon can't change: the setup shows it read-only.
    let pokemonLocked: Bool

    init(app: AppModel, mode: Mode) {
        self.app = app
        self.mode = mode
        let game = app.game
        originalLanguage = game.language
        language = L10n.languageCode
        lineId = game.pokemon.lineId
        homeEquipment = Set(game.settings.homeEquipment)
        officeEquipment = Set(game.settings.officeEquipment)
        programId = game.programId
        workMinutes = game.settings.workMinutes
        step2Seconds = game.settings.step2Seconds
        schedule = game.settings.schedule
        launchAtLogin = LaunchAtLogin.status == .enabled || LaunchAtLogin.status == .requiresApproval
        // Replaying the setup never changes the Pokémon: the cycle in progress goes on.
        pokemonLocked = mode == .relaunch
        if mode == .firstLaunch { lineId = LineCatalog.defaultLineId }
        #if STRETCHU_DEBUG
        // Development: start on a given step (STRETCHU_SETUP_STEP=0...5), to look at each screen.
        if let raw = ProcessInfo.processInfo.environment["STRETCHU_SETUP_STEP"], let n = Int(raw), let start = Step(rawValue: n) {
            step = start
        }
        #endif
    }

    // MARK: navigation

    var isFirst: Bool { step == .welcome }
    var isLast: Bool { step == .ready }
    var stepIndex: Int { step.rawValue }

    func next() {
        if step == .pokemon, !pokemonLocked, shinyByLine[lineId] == nil {
            let line = LineCatalog.line(id: lineId) ?? .pikachu
            shinyByLine[lineId] = LineCatalog.rollShiny(for: line, random: random)
        }
        if let following = Step(rawValue: step.rawValue + 1) { step = following }
    }

    /// "Random": the draw is final, "Let's go" takes its result and goes on.
    func startRandomDraw() {
        randomDraw = RandomPick.draw(lines: LineCatalog.available, obtained: Pokedex.obtainedDexes(app.game.progression.cycles),
                                     afterAbandon: false, random: random)
    }

    func acceptRandomDraw() {
        guard let draw = randomDraw else { return }
        lineId = draw.lineId
        shinyByLine[draw.lineId] = draw.shiny
        randomDraw = nil
        next()
    }

    func back() {
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    func go(to target: Step) { step = target }

    // MARK: choices

    var shiny: Bool { shinyByLine[lineId] ?? false }

    var systemLanguage: String { L10n.systemLanguageCode }

    func setLanguage(_ code: String) {
        language = code
        L10n.userLanguage = code
        app.refreshLanguage()
    }

    var allEquipment: Set<String> { homeEquipment.union(officeEquipment) }

    func setEquipment(_ new: Set<String>) {
        if equipmentPlace == .home { homeEquipment = new } else { officeEquipment = new }
    }

    var ownedAtCurrentPlace: Set<String> {
        equipmentPlace == .home ? homeEquipment : officeEquipment
    }

    var programs: [ProgramEntry] { app.availablePrograms }
    var generalProgram: ProgramEntry? { programs.first { $0.isBundled } }
    /// The player's program: the one chosen, else the one imported, else the first file found.
    var customProgram: ProgramEntry? {
        let own = programs.filter { !$0.isBundled }
        return own.first { $0.id == programId } ?? own.first { $0.id == importedId } ?? own.first
    }

    func selectProgram(_ id: String) {
        programId = id
        if let entry = programs.first(where: { $0.id == id }) {
            let applied = entry.program.applying(to: UserSettings(workMinutes: workMinutes, step1Seconds: 20, step2Seconds: step2Seconds))
            workMinutes = applied.workMinutes
            step2Seconds = applied.step2Seconds
        }
    }

    /// Imports a program file; its name replaces "Custom" in the list.
    func importProgram(from url: URL) {
        do {
            let entry = try app.programLibrary.importFile(at: url)
            importedId = entry.id
            programMessage = nil
            selectProgram(entry.id)
        } catch {
            programMessage = ProgramFilePicker.message(for: error)
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do { try LaunchAtLogin.set(on) } catch {}
        launchAtLogin = LaunchAtLogin.status == .enabled || LaunchAtLogin.status == .requiresApproval
    }

    // MARK: finishing

    /// The choices as the state will receive them.
    var choices: OnboardingChoices {
        OnboardingChoices(
            language: language == systemLanguage ? nil : language,
            lineId: pokemonLocked ? nil : lineId,
            shiny: pokemonLocked ? nil : shinyByLine[lineId],
            homeEquipment: Equipment.ownable.filter(homeEquipment.contains),
            officeEquipment: Equipment.ownable.filter(officeEquipment.contains),
            programId: programId, workMinutes: workMinutes, step2Seconds: step2Seconds, schedule: schedule)
    }

    /// "Start" (or "Done" when replaying): applies the draft.
    func finish() {
        app.completeOnboarding(choices)
        onDone?(true)
    }

    /// "Skip", or closing the window. The first time: every default (Pikachu, the general
    /// program). Replaying: nothing changes.
    func skip() {
        switch mode {
        case .firstLaunch:
            L10n.userLanguage = nil
            app.completeOnboarding(.defaults)
            onDone?(true)
        case .relaunch:
            cancel()
        }
    }

    func cancel() {
        L10n.userLanguage = originalLanguage
        app.refreshLanguage()
        onDone?(false)
    }
}
