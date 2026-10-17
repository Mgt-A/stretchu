import XCTest
@testable import Stretchu

/// The setup window's choices, and what finishing, skipping and replaying do to the state.
@MainActor
final class SetupTests: XCTestCase {
    private func makeApp() -> AppModel {
        AppModel(store: StateStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-setup-\(UUID().uuidString)")))
    }

    override func tearDown() { L10n.userLanguage = nil }

    // MARK: first launch only

    func testAFreshStateStartsTheSetupAndAnExistingFileDoesNot() throws {
        XCTAssertFalse(GameState().onboardingCompleted)
        XCTAssertFalse(makeApp().onboardingCompleted)
        let old = try StateStore.decoder.decode(GameState.self, from: Data(#"{"schemaVersion":1,"progression":{"xp":5}}"#.utf8))
        XCTAssertTrue(old.onboardingCompleted, "a state file that exists from before the setup is done")
        let current = try StateStore.decoder.decode(GameState.self, from: Data(#"{"schemaVersion":6,"onboardingCompleted":false}"#.utf8))
        XCTAssertFalse(current.onboardingCompleted)
    }

    func testTheSetupDoesNotRunTheTimerBeforeItIsFinished() {
        let app = makeApp()
        XCTAssertFalse(app.onboardingCompleted)
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        model.finish()
        XCTAssertTrue(app.onboardingCompleted)
    }

    func testQuittingBeforeTheEndLeavesTheFlagOffOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-setup-\(UUID().uuidString)")
        let app = AppModel(store: StateStore(directory: dir))
        app.save()   // whatever is saved on the way, the setup is not done
        XCTAssertFalse(StateStore(directory: dir).load().onboardingCompleted)
    }

    // MARK: defaults and choices

    func testSkippingAppliesEveryDefault() {
        let app = makeApp()
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        model.lineId = "charmander"
        model.homeEquipment = ["bands"]
        var finished: Bool?
        model.onDone = { finished = $0 }
        model.skip()
        XCTAssertEqual(finished, true)
        XCTAssertTrue(app.onboardingCompleted)
        XCTAssertEqual(app.game.pokemon.lineId, "pikachu", "Skip ignores what was picked")
        XCTAssertEqual(app.game.programId, "general")
        XCTAssertEqual(app.game.settings.homeEquipment, [])
        XCTAssertNil(app.game.language)
    }

    func testFinishingAppliesTheDraft() {
        let app = makeApp()
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        model.random = { 0.5 }
        model.go(to: .pokemon)
        model.lineId = "charmander"
        model.next()
        model.homeEquipment = ["bands", "foam roll"]
        model.officeEquipment = ["exercise ball"]
        model.workMinutes = 30
        model.step2Seconds = 45
        model.finish()
        XCTAssertEqual(app.game.pokemon.lineId, "charmander")
        XCTAssertFalse(app.game.pokemon.shiny)
        XCTAssertEqual(app.game.settings.homeEquipment, ["bands", "foam roll"])
        XCTAssertEqual(app.game.settings.officeEquipment, ["exercise ball"])
        XCTAssertEqual(app.game.settings.workMinutes, 30)
        XCTAssertEqual(app.game.settings.step2Seconds, 45)
        XCTAssertTrue(app.onboardingCompleted)
    }

    func testTheShinyIsDrawnOnceWhenContinuingFromThePokemonStep() throws {
        try requireSprites() // a line can only be shiny when its shiny sprites are downloaded
        let app = makeApp()
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        var draws = 0
        model.random = { draws += 1; return 0.01 }
        model.go(to: .pokemon)
        model.lineId = "charmander"
        model.next()
        XCTAssertTrue(model.shiny)
        XCTAssertEqual(draws, 1)
        model.back()
        model.next()
        XCTAssertEqual(draws, 1, "going back and forward again doesn't draw again")
        model.back()
        model.lineId = "squirtle"
        model.next()
        XCTAssertEqual(draws, 2, "another line, another draw")
        model.finish()
        XCTAssertEqual(app.game.pokemon.lineId, "squirtle")
        XCTAssertTrue(app.game.pokemon.shiny)
    }

    func testTheFiveStepsComeInOrderAndBackWorks() {
        let model = OnboardingModel(app: makeApp(), mode: .firstLaunch)
        XCTAssertEqual(OnboardingModel.Step.allCases, [.welcome, .pokemon, .equipment, .program, .access, .ready])
        var seen: [OnboardingModel.Step] = [model.step]
        for _ in 0..<5 { model.next(); seen.append(model.step) }
        XCTAssertEqual(seen, OnboardingModel.Step.allCases)
        model.next()
        XCTAssertEqual(model.step, .ready, "no step after the last")
        model.back()
        XCTAssertEqual(model.step, .access)
        model.go(to: .welcome)
        model.back()
        XCTAssertEqual(model.step, .welcome)
    }

    // MARK: language

    func testPickingALanguageSwitchesTheWholeInterfaceAtOnce() {
        let model = OnboardingModel(app: makeApp(), mode: .firstLaunch)
        model.setLanguage("en")
        XCTAssertEqual(L10n.languageCode, "en")
        XCTAssertEqual(tr("setup.continue"), "Continue")
        XCTAssertEqual(tr("setup.equipment.title"), "Your equipment")
        XCTAssertEqual(PlaceMode.home.name, "Home")
        XCTAssertEqual(Equipment.gridLabel("bands"), "Resistance band")
        XCTAssertEqual(PokemonLine.charmander.base.name, "Charmander")
        XCTAssertEqual(Format.xp(1_234), "1,234")
        model.setLanguage("fr")
        XCTAssertEqual(tr("setup.continue"), "Continuer")
        XCTAssertEqual(PlaceMode.home.name, "Maison")
        XCTAssertEqual(PokemonLine.charmander.base.name, "Salamèche")
        XCTAssertEqual(ExerciseCatalog.catalog.first { $0.id == "Chin_Tucks" }?.name, "Menton rentré")
        model.setLanguage("en")
        XCTAssertEqual(ExerciseCatalog.catalog.first { $0.id == "Chin_Tucks" }?.name, "Chin Tucks", "the exercises follow the language too")
    }

    func testTheChosenLanguageIsSavedAndUsedAfterTheSetup() {
        let app = makeApp()
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        let other = L10n.systemLanguageCode == "en" ? "fr" : "en"
        model.setLanguage(other)
        model.finish()
        XCTAssertEqual(app.game.language, other)
        XCTAssertEqual(L10n.languageCode, other)
        XCTAssertEqual(app.exercise.name, ExerciseCatalog.catalog(language: other).first { $0.id == app.exercise.id }?.name)
    }

    func testKeepingTheMacsLanguageStoresNothing() {
        let app = makeApp()
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        model.setLanguage(L10n.systemLanguageCode)
        XCTAssertNil(model.choices.language)
    }

    func testTheSystemLanguageIsOneOfTheTranslations() {
        XCTAssertTrue(L10n.availableLanguages.contains(L10n.systemLanguageCode))
    }

    // MARK: replaying

    func testReplayingTheSetupLocksThePokemon() {
        let app = makeApp()
        OnboardingModel(app: app, mode: .firstLaunch).finish()
        app.modifyStateForTests { $0.progression.xp = 50_000; $0.pokemon = CurrentPokemon(lineId: "charmander") }
        let model = OnboardingModel(app: app, mode: .relaunch)
        XCTAssertTrue(model.pokemonLocked)
        XCTAssertNil(model.choices.lineId)
        model.lineId = "squirtle"
        model.homeEquipment = ["bands"]
        model.finish()
        XCTAssertEqual(app.game.pokemon.lineId, "charmander")
        XCTAssertEqual(app.game.progression.xp, 50_000, "the progression is never touched")
        XCTAssertEqual(app.game.settings.homeEquipment, ["bands"], "the other choices are applied")
    }

    func testReplayingEvenAtLevelOneLocksThePokemon() {
        let app = makeApp()
        OnboardingModel(app: app, mode: .firstLaunch).finish()
        XCTAssertTrue(OnboardingModel(app: app, mode: .relaunch).pokemonLocked)
        XCTAssertFalse(OnboardingModel(app: makeApp(), mode: .firstLaunch).pokemonLocked)
    }

    func testReplayingStartsFromTheCurrentValues() {
        let app = makeApp()
        app.modifyStateForTests { $0.settings.homeEquipment = ["foam roll"]; $0.settings.workMinutes = 40; $0.programId = "general" }
        let model = OnboardingModel(app: app, mode: .relaunch)
        XCTAssertEqual(model.homeEquipment, ["foam roll"])
        XCTAssertEqual(model.workMinutes, 40)
        XCTAssertEqual(model.programId, "general")
    }

    func testClosingAReplayChangesNothing() {
        let app = makeApp()
        OnboardingModel(app: app, mode: .firstLaunch).finish()
        let before = app.game
        let model = OnboardingModel(app: app, mode: .relaunch)
        model.homeEquipment = ["bands"]
        model.workMinutes = 77
        model.setLanguage(L10n.systemLanguageCode == "en" ? "fr" : "en")
        var finished: Bool?
        model.onDone = { finished = $0 }
        model.skip()
        XCTAssertEqual(finished, false)
        XCTAssertEqual(app.game, before)
        XCTAssertEqual(L10n.userLanguage, before.language, "the language goes back too")
    }

    func testTheChoicesLeaveTheXPStreakAndCyclesAlone() {
        var game = GameState()
        game.progression = Progression(xp: 123_456, completedCycles: 2)
        game.streak = Streak(count: 9, breaksToday: 3, currentDay: nil)
        let before = game
        OnboardingChoices.current(of: game).apply(to: &game)
        XCTAssertEqual(game.progression, before.progression)
        XCTAssertEqual(game.streak, before.streak)
        XCTAssertTrue(game.onboardingCompleted)
    }

    func testSettingsKeepTheProgramsRhythmWithinBounds() {
        var game = GameState()
        var choices = OnboardingChoices.defaults
        choices.workMinutes = 999
        choices.step2Seconds = 1
        choices.apply(to: &game)
        XCTAssertEqual(game.settings.workMinutes, UserSettings.workRange.upperBound)
        XCTAssertEqual(game.settings.step2Seconds, UserSettings.step2Range.lowerBound)
    }

    func testTheShinyOfTheSetupGoesIntoTheCycle() {
        var game = GameState()
        var choices = OnboardingChoices.defaults
        choices.lineId = "charmander"
        choices.shiny = true
        choices.apply(to: &game)
        XCTAssertTrue(game.pokemon.shiny)
        XCTAssertEqual(game.progression.current.reachedDexes, [4])
    }

    func testImportingAProgramInTheSetupNamesItAndKeepsTheFileForLater() throws {
        let app = makeApp()
        let model = OnboardingModel(app: app, mode: .firstLaunch)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("my-program-\(UUID().uuidString).json")
        try Data(#"{"schemaVersion":1,"name":"Neck","exercises":["Chin_Tucks","Nope"],"settings":{"workMinutes":30}}"#.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        model.importProgram(from: file)
        XCTAssertEqual(model.customProgram?.program.name, "Neck")
        XCTAssertEqual(model.customProgram?.importResult.unknownCount, 1)
        XCTAssertEqual(model.programId, model.customProgram?.id)
        XCTAssertEqual(model.workMinutes, 30)
        model.finish()
        XCTAssertEqual(app.game.programId, model.customProgram?.id)
        XCTAssertEqual(app.activeProgram?.exercises, ["Chin_Tucks"])
        try? FileManager.default.removeItem(at: app.programsDirectory.deletingLastPathComponent())
    }

    func testABrokenProgramFileGivesAMessageAndChangesNothing() throws {
        let model = OnboardingModel(app: makeApp(), mode: .firstLaunch)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("bad-\(UUID().uuidString).json")
        try Data("nope".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        model.importProgram(from: file)
        XCTAssertNotNil(model.programMessage)
        XCTAssertEqual(model.programId, "general")
    }
}

extension AppModel {
    /// Test helper: edits the state without going through Debug mode.
    func modifyStateForTests(_ change: (inout GameState) -> Void) {
        var copy = game
        change(&copy)
        replaceStateForTests(copy)
    }
}
