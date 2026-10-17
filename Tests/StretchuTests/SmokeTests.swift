import XCTest
@testable import Stretchu

final class SmokeTests: XCTestCase {
    func testSpritesAreFound() throws {
        try requireSprites()
        XCTAssertTrue(SpriteFiles.exists(dex: 25, shiny: false, file: "Idle-Anim.png"))
    }

    func testStatusIconIsTwentyPointsTall() throws {
        try requireSprites()
        let icon = try XCTUnwrap(StatusIcon.image(for: SpriteRef(dex: 25, shiny: false)))
        XCTAssertEqual(icon.size.height, 20)
    }
}
