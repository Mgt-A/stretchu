import XCTest
@testable import Stretchu

// MARK: settings

final class UserSettingsTests: XCTestCase {
    func testDefaultSettings() {
        let r = UserSettings()
        XCTAssertEqual(r.workMinutes, 25)
        XCTAssertEqual(r.step1Seconds, 30)
        XCTAssertEqual(r.step2Seconds, 30)
        XCTAssertEqual(r.snoozeMinutes, 5)
    }

    func testTheSchedulerConfigFollowsTheSettings() {
        var r = UserSettings()
        r.workMinutes = 40
        r.step1Seconds = 30
        r.step2Seconds = 45
        r.snoozeMinutes = 10
        let c = r.config
        XCTAssertEqual(c.work, 40 * 60)
        XCTAssertEqual(c.step1, 30)
        XCTAssertEqual(c.step2, 45)
        XCTAssertEqual(c.snooze, 10 * 60)
    }

    func testBoundsAreRespected() {
        var r = UserSettings(workMinutes: 1, step1Seconds: 1, step2Seconds: 1, snoozeMinutes: 0)
        r = r.clamped()
        XCTAssertEqual(r.workMinutes, UserSettings.workRange.lowerBound)
        XCTAssertEqual(r.step1Seconds, UserSettings.step1Range.lowerBound)
        XCTAssertEqual(r.step2Seconds, UserSettings.step2Range.lowerBound)
        XCTAssertEqual(r.snoozeMinutes, UserSettings.snoozeRange.lowerBound)
        r = UserSettings(workMinutes: 999, step1Seconds: 999, step2Seconds: 999, snoozeMinutes: 999).clamped()
        XCTAssertEqual(r.workMinutes, UserSettings.workRange.upperBound)
        XCTAssertEqual(r.snoozeMinutes, UserSettings.snoozeRange.upperBound)
    }

    func testAnOldStateWithoutSettingsTakesTheDefaults() throws {
        let json = #"{"exercicesExclus":[],"progression":{"cyclesTermines":0,"hallOfFame":[],"xp":10},"schemaVersion":1,"streak":{"pausesDuJour":0,"serie":0}}"#
        let game = try StateStore.decoder.decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(game.settings, UserSettings())
    }

    func testSettingsArePersisted() throws {
        var game = GameState()
        game.settings = UserSettings(workMinutes: 35, step1Seconds: 25, step2Seconds: 40, snoozeMinutes: 7)
        let decoded = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(decoded.settings, game.settings)
    }
}

final class SchedulerSettingsTests: XCTestCase {
    var clock: FakeClock!
    var scheduler: PauseScheduler!

    override func setUp() {
        clock = FakeClock()
        scheduler = PauseScheduler(clock: clock, calendar: TestCalendar.calendar)
    }

    private func run(_ seconds: Int) {
        for _ in 0..<seconds { clock.advance(1); _ = scheduler.tick(.active) }
    }

    func testALongerBlockPostponesTheWakeUp() {
        run(10 * 60)
        var r = UserSettings(); r.workMinutes = 40
        scheduler.apply(r.config)
        XCTAssertEqual(scheduler.remaining, 30 * 60, accuracy: 1)
        run(25 * 60)
        XCTAssertEqual(scheduler.phase, .work)
    }

    func testAShorterBlockTriggersTheWakeUpOnTheNextTick() {
        run(10 * 60)
        var r = UserSettings(); r.workMinutes = 8
        scheduler.apply(r.config)
        run(1)
        XCTAssertEqual(scheduler.phase, .wakeUp)
    }

    func testBreakDurationsAreTheSettingsOnes() {
        var r = UserSettings(); r.step1Seconds = 10; r.step2Seconds = 15
        scheduler.apply(r.config)
        run(25 * 60)
        scheduler.start()
        XCTAssertEqual(scheduler.remaining, 10, accuracy: 0.001)
        run(10)
        XCTAssertEqual(scheduler.phase, .step2)
        XCTAssertEqual(scheduler.remaining, 15, accuracy: 0.001)
    }

    func testTheSnoozeFollowsTheSetting() {
        var r = UserSettings(); r.snoozeMinutes = 8
        scheduler.apply(r.config)
        run(25 * 60)
        XCTAssertTrue(scheduler.snooze())
        XCTAssertEqual(scheduler.remaining, 8 * 60, accuracy: 0.001)
    }

    func testTheNumberOfSnoozesStaysTwo() {
        XCTAssertEqual(UserSettings().config.maxSnoozes, 2)
    }
}
