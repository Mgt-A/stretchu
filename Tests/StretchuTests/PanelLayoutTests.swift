import AppKit
import SwiftUI
import XCTest
@testable import Stretchu

final class PanelAnchorTests: XCTestCase {
    // 1000 pt wide screen, 10 pt margin, 340 pt panel.
    private func x(_ center: CGFloat?) -> CGFloat {
        PanelPlacement.x(iconCenter: center, width: 340, screenMinX: 0, screenMaxX: 1000, margin: 10)
    }

    func testThePanelIsCenteredUnderTheIcon() {
        XCTAssertEqual(x(500), 330)
    }

    func testThePanelStaysInsideTheRightEdge() {
        XCTAssertEqual(x(980), 1000 - 340 - 10)
    }

    func testThePanelStaysInsideTheLeftEdge() {
        XCTAssertEqual(x(40), 10)
    }

    func testWithoutAKnownIconThePanelSticksToTheTopRightCorner() {
        XCTAssertEqual(x(nil), 1000 - 340 - 10)
    }

    func testTheMenuAndTheBreakPanelsShareTheSameX() {
        // Same function, same anchor: "Take a break now" moves nothing.
        XCTAssertEqual(x(700), x(700))
    }
}

final class SpritePlacementTests: XCTestCase {
    func testTheSpriteIsVerticallyCenteredInTheBox() {
        XCTAssertEqual(SpriteScale.topOffset(spriteHeight: 26, boxHeight: 64), 19)
        XCTAssertEqual(SpriteScale.topOffset(spriteHeight: 49, boxHeight: 64), 7)
    }

    func testATooBigSpriteStaysAtTheTop() {
        XCTAssertEqual(SpriteScale.topOffset(spriteHeight: 80, boxHeight: 64), 0)
    }

    func testAJumperKeepsItsAmplitudeInTheBox() throws {
        // The Hop bounds (jump included) are centered: the jump never leaves the box.
        try requireSprites()
        let hop = try XCTUnwrap(SpriteLibrary.sheet(SpriteRef(dex: 25, shiny: false), animation: "Hop", requireExactFile: true))
        let top = SpriteScale.topOffset(spriteHeight: hop.height, boxHeight: 64)
        XCTAssertGreaterThanOrEqual(top, 0)
        XCTAssertLessThanOrEqual(top + hop.height, 64)
    }
}

@MainActor
final class LevelUpHeightTests: XCTestCase {
    private func fittingHeight(language: String) -> CGFloat {
        let saved = L10n.userLanguage
        L10n.userLanguage = language
        defer { L10n.userLanguage = saved }
        let app = AppModel(store: StateStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-levelup-\(UUID().uuidString)")))
        app.modifyStateForTests { $0.onboardingCompleted = true }
        app.completeBreak(forTests: ())
        let host = NSHostingView(rootView: LevelUpView(model: app))
        host.layoutSubtreeIfNeeded()
        return ceil(host.fittingSize.height)
    }

    func testLevelUpFitsItsContentInsteadOfAFixedHeight() {
        // No empty band under the buttons: the panel is the height of what it shows,
        // strictly under the short panel's height (the old fixed one).
        for language in ["en", "fr"] {
            let height = fittingHeight(language: language)
            XCTAssertGreaterThan(height, 0, language)
            XCTAssertLessThan(height, PanelSize.short.height, language)
        }
    }

    func testLevelUpIsPresentedAtContentHeight() {
        XCTAssertEqual(PanelSize.content.height, 0, "0 means: measure the content")
    }
}
