import XCTest
@testable import Stretchu

@MainActor
final class MenuPanelTests: XCTestCase {
    private func makeModel() -> AppModel {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-menu-\(UUID().uuidString)")
        return AppModel(store: StateStore(directory: dir))
    }

    func testClickingTheIconOpensAndClosesTheMenu() {
        let model = makeModel()
        XCTAssertFalse(model.menuOpen)
        model.toggleMenu(option: false)
        XCTAssertTrue(model.menuOpen)
        XCTAssertEqual(model.page, .menu)
        model.toggleMenu(option: false)
        XCTAssertFalse(model.menuOpen)
    }

    #if STRETCHU_DEBUG
    func testOptionClickOpensTheDebugPageInTheSamePanel() {
        let model = makeModel()
        model.toggleMenu(option: true)
        XCTAssertTrue(model.menuOpen)
        XCTAssertEqual(model.page, .debug)
        XCTAssertFalse(model.debugMode, "opening the page doesn't start Debug: the toggle does")
    }
    #endif

    func testTheMenuAlwaysReopensOnTheMainPage() {
        let model = makeModel()
        model.toggleMenu(option: false)
        model.go(.settings)
        model.closeMenu()
        model.toggleMenu(option: false)
        XCTAssertEqual(model.page, .menu)
    }

    func testBreakNowClosesTheMenuAndOpensTheWakeUp() {
        let model = makeModel()
        model.toggleMenu(option: false)
        model.closeMenu()
        model.breakNow()
        XCTAssertEqual(model.phase, .wakeUp)
        XCTAssertFalse(model.menuOpen)
    }

    #if STRETCHU_DEBUG
    func testTheDebugPageIsANavigationNotANewPanel() {
        let model = makeModel()
        model.toggleMenu(option: false)
        model.go(.debug)
        XCTAssertEqual(model.page, .debug)
        XCTAssertTrue(model.menuOpen)
        model.back()
        XCTAssertEqual(model.page, .menu)
    }
    #endif

    #if STRETCHU_DEBUG
    func testTheToggleTurnsDebugOnAndOff() {
        let model = makeModel()
        model.setDebugMode(true)
        XCTAssertTrue(model.debugMode)
        model.setDebugMode(false)
        XCTAssertFalse(model.debugMode)
    }
    #endif

    #if STRETCHU_DEBUG
    func testThePanelCommandOpensTheDebugPage() {
        let model = makeModel()
        model.execute(.openPanel)
        XCTAssertTrue(model.menuOpen)
        XCTAssertEqual(model.page, .debug)
        XCTAssertFalse(model.debugMode)
    }
    #endif
}

@MainActor
final class MenuPagesTests: XCTestCase {
    func testNavigationAndBack() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-pages-\(UUID().uuidString)")
        let model = AppModel(store: StateStore(directory: dir))
        XCTAssertEqual(model.page, .menu)
        model.go(.companion)
        XCTAssertEqual(model.page, .companion)
        model.back()
        XCTAssertEqual(model.page, .menu)
        model.go(.settings)
        XCTAssertEqual(model.page, .settings)
        model.back()
        XCTAssertEqual(model.page, .menu)
        model.back()
        XCTAssertEqual(model.page, .menu, "back from the menu does nothing")
    }

    #if STRETCHU_DEBUG
    func testSeeingTheCompanionFromLevelUpOpensThePageInThePanel() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-pages-\(UUID().uuidString)")
        let model = AppModel(store: StateStore(directory: dir), startInDebug: false)
        model.execute(.levelUp)
        XCTAssertNotNil(model.levelUp)
        model.showCompanion()
        XCTAssertNil(model.levelUp)
        XCTAssertTrue(model.companionOpen)
        model.closeCompanion()
        XCTAssertFalse(model.companionOpen)
    }
    #endif
}
