import XCTest
@testable import Stretchu

final class ModeResolverTests: XCTestCase {
    func testWithoutAKnownNetworkTheModeIsHome() {
        XCTAssertEqual(ModeResolver().mode, .home)
    }

    func testTheLinkedSSIDGivesItsMode() {
        var r = ModeResolver(networks: ["Office-Corp": .office, "Home-5G": .home])
        r.networkChanged(ssid: "Office-Corp")
        XCTAssertEqual(r.mode, .office)
        r.networkChanged(ssid: "Home-5G")
        XCTAssertEqual(r.mode, .home)
    }

    func testAnUnknownNetworkFallsBackToHomeAndIsFlagged() {
        var r = ModeResolver(networks: ["Office-Corp": .office])
        r.networkChanged(ssid: "Cafe")
        XCTAssertEqual(r.mode, .home)
        XCTAssertTrue(r.networkUnlinked)
    }

    func testTheManualToggleWins() {
        var r = ModeResolver(networks: ["Home-5G": .home])
        r.networkChanged(ssid: "Home-5G")
        r.toggle(to: .office)
        XCTAssertEqual(r.mode, .office)
    }

    func testTheManualToggleLastsUntilTheNextNetworkChange() {
        var r = ModeResolver(networks: ["Home-5G": .home, "Office-Corp": .office])
        r.networkChanged(ssid: "Home-5G")
        r.toggle(to: .office)
        r.networkChanged(ssid: "Home-5G")   // same network: the choice stays
        XCTAssertEqual(r.mode, .office)
        r.networkChanged(ssid: "Office-Corp") // another network: deduction takes over again
        XCTAssertEqual(r.mode, .office)
        r.networkChanged(ssid: "Home-5G")
        XCTAssertEqual(r.mode, .home)
    }

    func testWithoutAnSSIDTheManualToggleIsTheOnlyMaster() {
        var r = ModeResolver(networks: ["Office-Corp": .office])
        r.networkChanged(ssid: nil)
        XCTAssertEqual(r.mode, .home)
        r.toggle(to: .office)
        r.networkChanged(ssid: nil)
        XCTAssertEqual(r.mode, .office)
    }
}

final class DefaultModeTests: XCTestCase {
    func testWithoutANetworkTheDefaultModeDecides() {
        XCTAssertEqual(ModeResolver(defaultMode: .office).mode, .office)
        XCTAssertEqual(ModeResolver(defaultMode: .home).mode, .home)
    }

    func testAnUnknownNetworkTakesTheDefaultMode() {
        var r = ModeResolver(networks: ["Home-5G": .home], defaultMode: .office)
        r.networkChanged(ssid: "Cafe")
        XCTAssertEqual(r.mode, .office)
        XCTAssertTrue(r.networkUnlinked)
    }

    func testAKnownNetworkBeatsTheDefaultMode() {
        var r = ModeResolver(networks: ["Home-5G": .home], defaultMode: .office)
        r.networkChanged(ssid: "Home-5G")
        XCTAssertEqual(r.mode, .home)
    }

    func testTheManualToggleBeatsEverything() {
        var r = ModeResolver(networks: ["Home-5G": .home], defaultMode: .office)
        r.networkChanged(ssid: "Home-5G")
        r.toggle(to: .office)
        XCTAssertEqual(r.mode, .office)
        r.toggle(to: .home)
        XCTAssertEqual(r.mode, .home)
    }

    func testChangingTheDefaultModeShowsRightAway() {
        var r = ModeResolver(defaultMode: .home)
        r.defaultMode = .office
        XCTAssertEqual(r.mode, .office)
    }

    func testTheDefaultModeIsPersistedAndIsHomeOtherwise() throws {
        XCTAssertEqual(UserSettings().defaultMode, .home)
        var game = GameState()
        game.settings.defaultMode = .office
        let decoded = try StateStore.decoder.decode(GameState.self, from: StateStore.encoder.encode(game))
        XCTAssertEqual(decoded.settings.defaultMode, .office)
        let old = try StateStore.decoder.decode(UserSettings.self, from: Data(#"{"travailMinutes":30}"#.utf8))
        XCTAssertEqual(old.defaultMode, .home)
        XCTAssertEqual(old.workMinutes, 30)
    }
}
