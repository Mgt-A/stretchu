import AppKit
import Observation
import SwiftUI

/// Pages of the menu panel: the companion and settings open in place of the menu.
enum MenuPage: Equatable {
    case menu, companion, settings, credits, hallOfFame, abandon, cycleStats
    #if STRETCHU_DEBUG
    case debug
    #endif
}

@MainActor
@Observable
final class AppModel {
    #if STRETCHU_DEBUG
    /// `make debug` / `make demo` start the app directly in Debug mode.
    static let startsInDebug = ProcessInfo.processInfo.environment["STRETCHU_DEBUG"] == "1"
    #endif
    /// How long the Level up panel stays.
    static let levelUpDuration: TimeInterval = 8

    @ObservationIgnored let clock = SimulatedClock()
    @ObservationIgnored let calendar = Calendar.current
    /// Real state (`state.json`): never written during Debug mode.
    @ObservationIgnored private let store: StateStore
    #if STRETCHU_DEBUG
    /// Debug mode draft (`state.debug.json`), deleted when leaving it.
    @ObservationIgnored private let debugStore: StateStore
    #endif
    @ObservationIgnored private let idle = IdleMonitor()
    @ObservationIgnored private let wifi = WifiModeDetector()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let breakPanel = PanelController()
    @ObservationIgnored private var shownPanel: Panel = .none
    /// The menu is a panel like the others, anchored under the icon; it receives the keyboard (⌘P, Esc).
    @ObservationIgnored private let menuPanel = PanelController(acceptsKeyboard: true)
    @ObservationIgnored private var closeObserver: NSObjectProtocol?
    @ObservationIgnored private var lastAutoClose = Date.distantPast
    @ObservationIgnored var onUpdate: (() -> Void)?
    @ObservationIgnored var onMenuOpen: (() -> Void)?
    @ObservationIgnored var onMenuClose: (() -> Void)?
    #if STRETCHU_DEBUG
    @ObservationIgnored private var debug: DebugSupport?
    @ObservationIgnored var debugSSID: String?
    #endif
    @ObservationIgnored private var tracker: MeetingTracker
    @ObservationIgnored private var resolver: ModeResolver
    /// Last states read from the hardware, refreshed every 5 s.
    @ObservationIgnored private var hardwareInUse = false
    @ObservationIgnored private var lastPoll: Date?
    @ObservationIgnored private var levelUpEnd: Date?

    private(set) var game: GameState
    private(set) var scheduler: PauseScheduler
    private(set) var exercise: Exercise
    /// Mic or camera used by another app (or the Debug panel's fake meeting).
    private(set) var inMeeting = false
    #if STRETCHU_DEBUG
    /// Fake meeting from the Debug panel.
    private(set) var fakeMeeting = false
    #endif
    /// Home: all exercises. Office: no band, roller, floor or stick.
    private(set) var mode: PlaceMode = .home
    private(set) var ssid: String?
    private(set) var networkUnlinked = false
    private(set) var wifiAuthorization: WifiModeDetector.Authorization = .notRequested
    private(set) var levelUp: LevelUp?
    private(set) var companionOpen = false
    private(set) var suspendedUntil: Date?
    /// Page shown in the menu panel (companion and settings open there, with a back button).
    private(set) var page: MenuPage = .menu
    #if STRETCHU_DEBUG
    private(set) var debugMode = false
    #endif
    private(set) var menuOpen = false

    /// What opens the choice of the next Pokémon: a cycle that ended (the Hall of Fame header shows),
    /// or one the player gave up.
    struct CycleChoice: Equatable {
        enum Kind: Equatable { case finished, abandoned }
        let kind: Kind
        /// The species that entered the Hall of Fame, and how long the cycle took.
        let finishedSpecies: Species?
        let days: Int?
    }

    private(set) var cycleChoice: CycleChoice?
    /// Eevee reached its branch level and the stone screen is open.
    private(set) var branchChoiceOpen = false
    /// The setup window is not finished: no icon, no timer.
    var onboardingCompleted: Bool { game.onboardingCompleted }
    private(set) var language: String?
    @ObservationIgnored var onShowOnboarding: (() -> Void)?

    private enum Panel: Equatable { case none, wakeUp, step1, step2, levelUp, companion, cycleChoice, branchChoice }

    init(store: StateStore = StateStore()) {
        self.store = store
        #if STRETCHU_DEBUG
        self.debugStore = StateStore(directory: store.directory, fileName: "state.debug.json")
        #endif
        let loaded = store.load()
        self.game = loaded
        self.scheduler = PauseScheduler(config: loaded.settings.clamped().config, clock: clock, calendar: calendar)
        self.tracker = MeetingTracker(clock: clock)
        self.resolver = ModeResolver(networks: loaded.networks, defaultMode: loaded.settings.defaultMode)
        self.exercise = ExerciseCatalog.pick(
            program: ProgramLibrary(userDirectory: store.programsDirectory).entry(id: loaded.programId)?.program,
            equipment: loaded.settings.equipment(for: .home),
            excluded: Set(loaded.excludedExercises), alreadyPicked: [], different: nil)
        game.syncStreak(now: clock.now, calendar: calendar)
        wifiAuthorization = wifi.authorization
        wifi.onChange = { [weak self] in self?.wifiAuthorization = self?.wifi.authorization ?? .notRequested }
        language = loaded.language
        L10n.userLanguage = loaded.language
        L10n.setProcessLanguage(loaded.language)
        // The permission prompt belongs to the setup (step "Access"); a player who already did
        // the setup is not asked again.
        if loaded.onboardingCompleted { wifi.requestAuthorization(); startRunning() }

        #if STRETCHU_DEBUG
        if ProcessInfo.processInfo.environment["STRETCHU_DEBUG"] == "1" { debug = DebugSupport(model: self) }
        #endif
    }

    #if STRETCHU_DEBUG
    convenience init(store: StateStore = StateStore(), startInDebug: Bool) {
        self.init(store: store)
        if startInDebug { startDebug() }
    }
    #endif

    /// Starts the one-second timer: breaks, meetings, panels. Called once the setup is done.
    func startRunning() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: navigation

    func go(_ destination: MenuPage) { page = destination; fitMenuLater() }
    func back() { page = .menu; fitMenuLater() }

    /// Index in `progression.cycles` of the cycle shown by the `.cycleStats` page.
    private(set) var statsCycle = 0
    func openCycleStats(_ index: Int) { statsCycle = index; go(.cycleStats) }

    // MARK: menu (panel)

    /// Click on the icon: opens the menu, or closes it if open. ⌥ click: Debug page (development builds only).
    func toggleMenu(option: Bool) {
        if menuOpen { closeMenu(); return }
        // A click on the icon while the menu is open closes it first (focus loss):
        // it must not reopen it right away.
        if Date().timeIntervalSince(lastAutoClose) < 0.3 { return }
        #if STRETCHU_DEBUG
        openMenu(page: option ? .debug : .menu)
        #else
        openMenu(page: .menu)
        #endif
    }

    func openMenu(page destination: MenuPage = .menu) {
        page = destination
        menuOpen = true
        menuPanel.present(size: .content) { MenuRoot(model: self) }
        if closeObserver == nil, let window = menuPanel.window {
            // Like a menu: clicking elsewhere (another active app, the desktop) closes it.
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.menuOpen else { return }
                    self.lastAutoClose = Date()
                    self.closeMenu()
                }
            }
        }
        onMenuOpen?()
    }

    func closeMenu() {
        guard menuOpen else { return }
        menuOpen = false
        menuPanel.dismiss()
        onMenuClose?()
    }

    /// Pages differ in height: the panel follows the content.
    private func fitMenuLater() {
        guard menuOpen else { return }
        DispatchQueue.main.async { [weak self] in self?.menuPanel.fitToContent() }
    }

    #if STRETCHU_DEBUG
    /// Toggle of the Debug page.
    func setDebugMode(_ active: Bool) {
        if active { enterDebug() } else { quitDebug() }
        fitMenuLater()
    }
    #endif

    // MARK: reading for the views

    var species: Species { game.species }
    var sprite: SpriteRef { game.sprite }
    var phase: PausePhase { scheduler.phase }

    /// XP of a completed break at the current multiplier ("+680 XP · ×3.4").
    var expectedBreakXP: Int { Streak.earnedXP(base: XPRules.breakXP, streak: game.streak.count) }

    /// What the status bar pill shows.
    var pillState: StatusPillState {
        switch scheduler.phase {
        case .work:
            if scheduler.isOutsideHours { return .asleep }
            if scheduler.isWaiting { return .waiting }
            let suspended = suspendedUntil != nil || scheduler.isIdle
            return .timer(text: Format.barTimer(scheduler.remaining), suspended: suspended)
        case .wakeUp, .step1, .step2:
            return .pause
        }
    }

    /// How the Pokémon behaves in the menu and the companion.
    var mood: Mood { Mood.forStreak(game.streak.count, asleep: scheduler.isOutsideHours, skipped: game.streak.skippedSinceBreak) }

    /// "Resumes tomorrow at 8:30 AM" while Stretchu is asleep, otherwise nil.
    var resumeText: String? {
        guard scheduler.isOutsideHours,
              let opening = game.settings.schedule.nextStart(after: clock.now, calendar: calendar) else { return nil }
        return Format.resume(at: opening, from: clock.now, calendar: calendar)
    }

    /// Value of the menu's "Next break" card.
    var nextBreakValue: String {
        switch scheduler.phase {
        case .work:
            if scheduler.isOutsideHours { return tr("menu.nextBreak.asleep") }
            if scheduler.isWaiting { return tr("menu.nextBreak.waiting") }
            return Format.barTimer(scheduler.remaining)
        case .wakeUp: return tr("menu.nextBreak.now")
        case .step1, .step2: return tr("menu.nextBreak.inProgress")
        }
    }

    // MARK: time

    private func tick() {
        let now = clock.now
        var streak = game.streak
        streak.sync(now: now, calendar: calendar, days: game.settings.schedule.days)
        if streak != game.streak { game.streak = streak; save() }

        updateMeetingAndWifi()

        if let end = suspendedUntil {
            if now >= end {
                suspendedUntil = nil
                scheduler.resync()
            } else {
                // Suspended: the timer doesn't count, like a locked screen.
                handle(scheduler.tick(Activity(idleSeconds: 0, isLocked: true), inMeeting: inMeeting))
            }
        } else {
            handle(scheduler.tick(idle.activity, inMeeting: inMeeting))
        }

        if let end = levelUpEnd, Date() >= end { levelUp = nil; levelUpEnd = nil }
        updatePanels()
        if menuOpen { menuPanel.fitToContent() }
        onUpdate?()
    }

    /// Hardware and Wi-Fi polling every 5 s (real time), tracker sample on every tick.
    private func updateMeetingAndWifi() {
        let current = Date()
        if lastPoll.map({ current.timeIntervalSince($0) >= 5 }) ?? true {
            hardwareInUse = MeetingDetector.micOrCameraInUse()
            lastPoll = current
            wifiAuthorization = wifi.authorization
            #if STRETCHU_DEBUG
            readNetwork(debugSSID ?? wifi.ssid())
            #else
            readNetwork(wifi.ssid())
            #endif
        }
        #if STRETCHU_DEBUG
        tracker.sample(inUse: hardwareInUse || fakeMeeting)
        #else
        tracker.sample(inUse: hardwareInUse)
        #endif
        if tracker.inMeeting != inMeeting { inMeeting = tracker.inMeeting }
    }

    func readNetwork(_ read: String?) {
        resolver.networkChanged(ssid: read)
        syncMode()
    }

    private func syncMode() {
        if ssid != resolver.ssid { ssid = resolver.ssid }
        if mode != resolver.mode { mode = resolver.mode }
        if networkUnlinked != resolver.networkUnlinked { networkUnlinked = resolver.networkUnlinked }
    }

    func handle(_ events: [SchedulerEvent]) {
        for event in events {
            let results = game.apply(event, now: clock.now, calendar: calendar, outsideHours: scheduler.breakStartedOutsideHours)
            switch event {
            case .wakeUp:
                pickExercise(different: nil)
            case .breakCompleted:
                save()
                announce(results)
            case .skipped:
                save()
            default:
                break
            }
        }
    }

    /// Shows the right panel after an action: the choice of the next Pokémon when a cycle ended,
    /// the stone choice when Eevee reaches level 50, otherwise Level up (8 s).
    private func announce(_ results: [GameEvent]) {
        if results.contains(where: { if case .cycleCompleted = $0 { true } else { false } }) {
            let finished = game.progression.completedCycleList.last
            let line = LineCatalog.line(for: finished?.pokemon ?? game.pokemon)
            let species = line.allSpecies.filter { finished?.reachedDexes.contains($0.dex) ?? false }.last ?? line.base
            cycleChoice = CycleChoice(kind: .finished, finishedSpecies: species,
                                      days: finished.flatMap { $0.days(calendar: calendar, now: clock.now) })
            return
        }
        for case let .leveledUp(from, to) in results {
            if let branch = game.line.branch, from < branch.level, to >= branch.level, game.needsBranchChoice {
                branchChoiceOpen = true
                return
            }
        }
        let line = game.line
        let final = line.species(atLevel: Progression.maxLevel, branchDex: game.pokemon.branchDex)
        guard let gain = LevelUp.from(results, current: game.species, currentLevel: game.progression.level, finalSpecies: final) else { return }
        levelUp = gain
        levelUpEnd = Date().addingTimeInterval(Self.levelUpDuration)
    }

    // MARK: user actions

    func breakNow() {
        handle(scheduler.triggerWakeUp())
        updatePanels()
    }

    func start() {
        scheduler.start()
        updatePanels()
    }

    /// Chevron at step 1: straight to step 2. XP and streak only move on `.breakCompleted`.
    func skipStep1() {
        handle(scheduler.skipStep1())
        updatePanels()
    }

    func snooze() {
        scheduler.snooze()
        updatePanels()
    }

    func skip() {
        handle(scheduler.skip())
        updatePanels()
    }

    func finish() {
        handle(scheduler.finish())
        updatePanels()
    }

    /// "Hurts": the exercise is excluded from the picks (persisted), another one is offered.
    func exerciseHurts() {
        if !game.excludedExercises.contains(exercise.id) {
            game.excludedExercises.append(exercise.id)
            save()
        }
        pickExercise(different: exercise.id)
    }

    /// "Another one": a different exercise of the same mode, no penalty.
    func anotherExercise() {
        pickExercise(different: exercise.id)
    }

    /// Picks from the catalog: current mode, outside exclusions, no repeat within the day.
    private func pickExercise(different: String?) {
        let now = clock.now
        let picked = ExerciseCatalog.pick(
            program: activeProgram, equipment: game.settings.equipment(for: mode),
            excluded: Set(game.excludedExercises),
            alreadyPicked: game.dailyPicks.ids(for: now, calendar: calendar), different: different)
        game.dailyPicks.record(picked.id, now: now, calendar: calendar)
        exercise = picked
        save()
    }

    // MARK: cycles and choices

    /// "Hatch": starts the next cycle with the chosen line (a fresh shiny draw, unless the cycle
    /// follows an abandon). Closing the screen without choosing keeps the same line, level 1.
    func chooseNextPokemon(lineId: String, shiny: Bool? = nil) {
        game.chooseNextPokemon(lineId: lineId, shiny: shiny)
        cycleChoice = nil
        pickExerciseNow()
        save()
        updatePanels()
    }

    /// "Keep" or closing: nothing was lost, the cycle that started keeps its line.
    func dismissCycleChoice() {
        cycleChoice = nil
        updatePanels()
    }

    /// Gives up the current cycle and opens the choice of the next Pokémon.
    func abandonCycle() {
        game.abandonCurrentCycle(now: clock.now)
        cycleChoice = CycleChoice(kind: .abandoned, finishedSpecies: nil, days: nil)
        levelUp = nil
        levelUpEnd = nil
        branchChoiceOpen = false
        save()
        closeMenu()
        updatePanels()
    }

    /// Menu: eats a Rare Candy, +1 level, shown as a level up.
    func useCandy() {
        let events = game.useCandy(now: clock.now)
        guard !events.isEmpty else { return }
        save()
        closeMenu()
        announce(events)
        updatePanels()
    }

    /// Eevee: the stone is chosen, the evolution is shown as a level up.
    func chooseBranch(dex: Int) {
        let events = game.chooseBranch(dex: dex)
        branchChoiceOpen = false
        save()
        if !events.isEmpty {
            levelUp = LevelUp(level: game.progression.level, species: game.species, newSpecies: true,
                              xpGained: 0, cycleCompleted: false, finalSpecies: nil)
            levelUpEnd = Date().addingTimeInterval(Self.levelUpDuration)
        }
        updatePanels()
    }

    /// "Later": Eevee keeps earning XP without evolving; the menu offers "Choose the stone".
    func postponeBranchChoice() {
        branchChoiceOpen = false
        updatePanels()
    }

    /// Menu row "Choose the stone".
    func showBranchChoice() {
        guard game.needsBranchChoice else { return }
        closeMenu()
        branchChoiceOpen = true
        updatePanels()
    }

    private func pickExerciseNow() { pickExercise(different: nil) }

    // MARK: setup, language

    /// Opens the setup window again (menu "Run the setup again…"). The progression is not touched.
    func rerunSetup() {
        closeMenu()
        onShowOnboarding?()
    }

    /// Redraws the views after the language changed under them (the setup shows it live).
    func refreshLanguage() { language = L10n.userLanguage }

    func setLanguage(_ code: String?) {
        game.language = code
        language = code
        L10n.userLanguage = code
        L10n.setProcessLanguage(code)
        save()
    }

    /// Applies the setup's choices and finishes it.
    func completeOnboarding(_ choices: OnboardingChoices) {
        let wasDone = game.onboardingCompleted
        choices.apply(to: &game, calendar: calendar, now: clock.now)
        language = game.language
        L10n.userLanguage = game.language
        L10n.setProcessLanguage(game.language)
        resolver.defaultMode = game.settings.defaultMode
        scheduler.apply(game.settings.config)
        syncMode()
        pickExercise(different: nil)
        save()
        if !wasDone { startRunning() }
    }

    /// Replaces the whole state (tests, and the Debug panel's prepared states).
    func replaceStateForTests(_ state: GameState) {
        game = state
        save()
    }

    // MARK: programs

    var programsDirectory: URL { store.programsDirectory }
    var programLibrary: ProgramLibrary { ProgramLibrary(userDirectory: store.programsDirectory) }

    /// The program drawn from: the shipped one, or a file of the programs folder.
    var activeProgram: Program? {
        let library = ProgramLibrary(userDirectory: store.programsDirectory)
        return (library.entry(id: game.programId) ?? library.general())?.program
    }

    /// Programs the player can choose from, the shipped one first.
    var availablePrograms: [ProgramEntry] {
        ProgramLibrary(userDirectory: store.programsDirectory).entries()
    }

    /// Chooses a program. The durations it asks for replace the current ones (clamped).
    func selectProgram(id: String) {
        guard let entry = availablePrograms.first(where: { $0.id == id }) else { return }
        game.programId = id
        game.settings = entry.program.applying(to: game.settings)
        scheduler.apply(game.settings.config)
        save()
    }

    /// Imports a program file (copied into the programs folder) and chooses it.
    @discardableResult
    func importProgram(from url: URL) throws -> ProgramEntry {
        let entry = try ProgramLibrary(userDirectory: store.programsDirectory).importFile(at: url)
        selectProgram(id: entry.id)
        return entry
    }

    func setEquipment(_ equipment: [String], for mode: PlaceMode) {
        let ordered = Equipment.ownable.filter(Set(equipment).contains)
        if mode == .home { game.settings.homeEquipment = ordered } else { game.settings.officeEquipment = ordered }
        save()
    }

    // MARK: settings

    func updateSettings(_ change: (inout UserSettings) -> Void) {
        var s = game.settings
        change(&s)
        game.settings = s.clamped()
        scheduler.apply(game.settings.config)
        resolver.defaultMode = game.settings.defaultMode
        syncMode()
        save()
    }

    func restoreExercise(_ id: String) {
        game.excludedExercises.removeAll { $0 == id }
        save()
    }

    func setNetwork(_ ssid: String, _ mode: PlaceMode) {
        guard !ssid.isEmpty else { return }
        game.networks[ssid] = mode
        resolver.networks = game.networks
        save()
        syncMode()
    }

    func removeNetwork(_ ssid: String) {
        game.networks[ssid] = nil
        resolver.networks = game.networks
        save()
        syncMode()
    }

    // MARK: Home / Office mode

    /// Manual toggle: wins until the next network change.
    func toggleMode(_ new: PlaceMode) {
        resolver.toggle(to: new)
        syncMode()
    }

    /// Links the current network to a mode (entered at first launch).
    func linkNetwork(to new: PlaceMode) {
        resolver.linkCurrentNetwork(to: new)
        game.networks = resolver.networks
        save()
        syncMode()
    }

    func requestWifiAuthorization() {
        wifi.requestAuthorization()
    }

    // MARK: suspension, companion, level up

    func toggleSuspension() {
        if suspendedUntil != nil {
            suspendedUntil = nil
            scheduler.resync()
        } else if scheduler.phase == .work {
            suspendedUntil = clock.now.addingTimeInterval(3600)
        }
    }

    func showCompanion() {
        levelUp = nil
        levelUpEnd = nil
        companionOpen = true
        updatePanels()
    }

    func closeCompanion() {
        companionOpen = false
        updatePanels()
    }

    func closeLevelUp() {
        levelUp = nil
        levelUpEnd = nil
        updatePanels()
    }

    // MARK: panels

    func updatePanels() {
        let wanted: Panel = switch scheduler.phase {
        case .wakeUp: .wakeUp
        case .step1: .step1
        case .step2: .step2
        case .work:
            if cycleChoice != nil { .cycleChoice }
            else if branchChoiceOpen { .branchChoice }
            else if levelUp != nil { .levelUp }
            else if companionOpen { .companion }
            else { .none }
        }
        guard wanted != shownPanel else { return }
        shownPanel = wanted
        switch wanted {
        case .none: breakPanel.dismiss()
        case .wakeUp: breakPanel.present(size: .short) { WakeUpView(model: self) }
        case .step1: breakPanel.present(size: .content) { PauseStep1View(model: self) }
        case .step2: breakPanel.present(size: .tall) { ExerciseView(model: self) }
        case .levelUp: breakPanel.present(size: .content) { LevelUpView(model: self) }
        case .cycleChoice: breakPanel.present(size: .tall) { CycleChoiceView(model: self) }
        case .branchChoice: breakPanel.present(size: .tall) { BranchChoiceView(model: self) }
        case .companion: breakPanel.present(size: .content) { CompanionView(model: self, back: { [unowned self] in self.closeCompanion() }) }
        }
    }

    #if STRETCHU_DEBUG
    /// Enters Debug mode: the current state is copied to `state.debug.json`, everything else
    /// (state settings, simulated time, fake meetings) happens there. `state.json` is no longer written.
    func enterDebug() {
        guard !debugMode else { return }
        debugMode = true
        save()
    }

    /// `make demo` drops a scenario in state.debug.json before launching the app: pick it up.
    func startDebug() {
        if debugStore.exists {
            game = debugStore.load()
            game.syncStreak(now: clock.now, calendar: calendar)
            resolver.networks = game.networks
            resolver.defaultMode = game.settings.defaultMode
            syncMode()
        }
        enterDebug()
    }

    /// Leaves Debug mode: the draft is deleted, the real state is reloaded as it was.
    func quitDebug() {
        guard debugMode else { return }
        debugMode = false
        debugStore.remove()
        resetAfterDebug()
    }

    /// Resets everything after Debug mode: real time, real state reloaded, fresh timer.
    func resetAfterDebug() {
        game = store.load()
        game.syncStreak(now: Date(), calendar: calendar)
        clock.reset()
        fakeMeeting = false
        debugSSID = nil
        hardwareInUse = false
        tracker = MeetingTracker(clock: clock)
        inMeeting = false
        scheduler = PauseScheduler(config: game.settings.clamped().config, clock: clock, calendar: calendar)
        resolver = ModeResolver(networks: game.networks, defaultMode: game.settings.defaultMode)
        syncMode()
        levelUp = nil
        levelUpEnd = nil
        suspendedUntil = nil
        pickExerciseWithoutRecording()
        updatePanels()
    }

    private func pickExerciseWithoutRecording() {
        exercise = ExerciseCatalog.pick(
            program: activeProgram, equipment: game.settings.equipment(for: mode),
            excluded: Set(game.excludedExercises),
            alreadyPicked: game.dailyPicks.ids(for: clock.now, calendar: calendar), different: nil)
    }
    #endif

    // MARK: export and import

    /// Copies the state file to `url` (Settings, "Export my state…").
    func exportState(to url: URL) throws {
        save()
        try (debugActive ? StateStore(directory: store.directory) : store).export(to: url, fallback: game)
    }

    /// Replaces the whole state with an imported one and restarts everything that was built from
    /// the old one: language, timer, mode, exercise, open panels.
    func importState(_ imported: StateTransfer.Imported) {
        var state = imported.game
        if imported.predatesPrograms {
            ProgramLibrary(userDirectory: store.programsDirectory).migrate(&state)
        }
        // The setup belongs to a first launch: an imported state is a player that already did it.
        state.onboardingCompleted = true
        game = state
        game.syncStreak(now: clock.now, calendar: calendar)
        language = game.language
        L10n.userLanguage = game.language
        L10n.setProcessLanguage(game.language)
        scheduler = PauseScheduler(config: game.settings.clamped().config, clock: clock, calendar: calendar)
        resolver = ModeResolver(networks: game.networks, defaultMode: game.settings.defaultMode)
        syncMode()
        levelUp = nil
        levelUpEnd = nil
        cycleChoice = nil
        branchChoiceOpen = false
        suspendedUntil = nil
        pickExercise(different: nil)
        save()
        updatePanels()
    }

    private var debugActive: Bool {
        #if STRETCHU_DEBUG
        debugMode
        #else
        false
        #endif
    }

    // MARK: persistence

    func save() {
        #if STRETCHU_DEBUG
        let target = debugMode ? debugStore : store
        #else
        let target = store
        #endif
        do { try target.save(game) } catch {
            NSLog("Stretchu: could not save: \(error.localizedDescription)")
        }
    }

    #if STRETCHU_DEBUG
    // MARK: Debug access (see Debug/DebugActions.swift)

    func setFakeMeeting(_ active: Bool) {
        fakeMeeting = active
    }

    func modifyState(_ change: (inout GameState) -> Void) {
        change(&game)
        save()
    }

    func replaceState(_ state: GameState) {
        game = state
        game.syncStreak(now: clock.now, calendar: calendar)
        resolver.networks = game.networks
        syncMode()
        save()
    }

    func applyToScheduler(_ operation: (inout PauseScheduler) -> [SchedulerEvent]) {
        let events = operation(&scheduler)
        handle(events)
        updatePanels()
    }

    func resyncAfterClockJump() {
        scheduler.resync()
        var streak = game.streak
        streak.sync(now: clock.now, calendar: calendar, days: game.settings.schedule.days)
        game.streak = streak
        save()
    }

    /// Shows the choice of the next Pokémon, as if the current cycle had just ended.
    func showCycleChoiceDebug() {
        cycleChoice = CycleChoice(kind: .finished, finishedSpecies: game.species, days: 10)
        updatePanels()
    }

    /// Shows the stone choice.
    func showBranchChoiceDebug() {
        branchChoiceOpen = true
        updatePanels()
    }

    /// Shows the Level up panel for the current level.
    func triggerLevelUpDebug() {
        let p = game.progression
        levelUp = LevelUp(level: p.level, species: game.species, newSpecies: false,
                          xpGained: expectedBreakXP, cycleCompleted: false, finalSpecies: nil)
        levelUpEnd = Date().addingTimeInterval(Self.levelUpDuration)
        updatePanels()
    }
    #endif
}
