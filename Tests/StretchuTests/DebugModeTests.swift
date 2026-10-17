import XCTest
@testable import Stretchu

#if STRETCHU_DEBUG
@MainActor
final class DebugModeTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-debug-\(UUID().uuidString)")
        var real = GameState()
        real.progression = Progression(xp: 1_000)
        real.streak = Streak(count: 3, breaksToday: 2, currentDay: nil)
        try StateStore(directory: dir).save(real)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func file(_ name: String) -> URL { dir.appendingPathComponent(name) }

    func testDebugStartsFromTheRealStateButWritesElsewhere() {
        let model = AppModel(store: StateStore(directory: dir), startInDebug: false)
        XCTAssertFalse(model.debugMode)
        model.enterDebug()
        XCTAssertTrue(model.debugMode)
        XCTAssertEqual(model.game.progression.xp, 1_000, "Debug starts from the real state")
        model.execute(.level(50))
        XCTAssertEqual(model.game.progression.level, 50)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file("state.debug.json").path))
        XCTAssertEqual(StateStore(directory: dir).load().progression.xp, 1_000, "state.json didn't move")
    }

    func testLeavingDebugBringsTheRealStateBack() {
        let model = AppModel(store: StateStore(directory: dir), startInDebug: false)
        model.enterDebug()
        model.execute(.level(90))
        model.execute(.streak(40))
        model.quitDebug()
        XCTAssertFalse(model.debugMode)
        XCTAssertEqual(model.game.progression.xp, 1_000)
        XCTAssertEqual(model.game.streak.count, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file("state.debug.json").path))
    }

    func testQuittingTheAppInDebugLosesNothing() {
        do {
            let model = AppModel(store: StateStore(directory: dir), startInDebug: false)
            model.enterDebug()
            model.execute(.level(100))
            model.execute(.reset)
        }
        let next = AppModel(store: StateStore(directory: dir), startInDebug: false)
        XCTAssertFalse(next.debugMode, "a restart doesn't stay in Debug")
        XCTAssertEqual(next.game.progression.xp, 1_000)
    }

    func testSimulatedTimeAndFakeMeetingsDisappearOnLeaving() {
        let model = AppModel(store: StateStore(directory: dir), startInDebug: false)
        model.enterDebug()
        model.execute(.advance25Minutes)
        model.execute(.meetingStart)
        XCTAssertTrue(model.clock.isSimulated)
        model.quitDebug()
        XCTAssertFalse(model.clock.isSimulated)
        XCTAssertFalse(model.fakeMeeting)
        XCTAssertEqual(model.phase, .work)
    }

    func testADebugActionEntersDebugAutomatically() {
        let model = AppModel(store: StateStore(directory: dir), startInDebug: false)
        model.execute(.level(20))
        XCTAssertTrue(model.debugMode, "never write to the real state without going through Debug")
        XCTAssertEqual(StateStore(directory: dir).load().progression.xp, 1_000)
    }

    func testStartingInDebugPicksUpThePreparedFile() throws {
        // `make demo` drops the scenario in state.debug.json before launching the app.
        var demo = GameState()
        demo.progression = Progression(xp: 999_500)
        try StateStore(directory: dir, fileName: "state.debug.json").save(demo)
        let model = AppModel(store: StateStore(directory: dir), startInDebug: true)
        XCTAssertTrue(model.debugMode)
        XCTAssertEqual(model.game.progression.xp, 999_500)
        model.quitDebug()
        XCTAssertEqual(model.game.progression.xp, 1_000)
    }

    func testStartingInDebugWithoutAFileStartsFromTheRealState() {
        let model = AppModel(store: StateStore(directory: dir), startInDebug: true)
        XCTAssertTrue(model.debugMode)
        XCTAssertEqual(model.game.progression.xp, 1_000)
    }

    func testDebugCommandsParse() {
        XCTAssertEqual(DebugAction(command: "level:33"), .level(33))
        XCTAssertEqual(DebugAction(command: "wakeup"), .wakeUp)
        XCTAssertEqual(DebugAction(command: "fixture:lv1"), .fixture("lv1"))
        XCTAssertEqual(DebugAction(command: "iconclick:option"), .iconClick(option: true))
        XCTAssertNil(DebugAction(command: "level:abc"))
        XCTAssertNil(DebugAction(command: "niveau:33"), "the French command names are gone")
    }
}
#endif
