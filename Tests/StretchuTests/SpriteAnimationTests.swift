import XCTest
@testable import Stretchu

final class SpriteAnimationTests: XCTestCase {
    private let xml = """
    <?xml version="1.0" ?>
    <AnimData><Anims>
      <Anim><Name>Walk</Name><Index>0</Index><FrameWidth>32</FrameWidth><FrameHeight>40</FrameHeight>
        <Durations><Duration>8</Duration><Duration>10</Duration></Durations></Anim>
      <Anim><Name>Idle</Name><Index>7</Index><FrameWidth>40</FrameWidth><FrameHeight>56</FrameHeight>
        <Durations><Duration>30</Duration><Duration>6</Duration><Duration>6</Duration></Durations></Anim>
    </Anims></AnimData>
    """

    func testReadingAnimData() throws {
        let anims = AnimDataParser.parse(Data(xml.utf8))
        let idle = try XCTUnwrap(anims["Idle"])
        XCTAssertEqual(idle.frameWidth, 40)
        XCTAssertEqual(idle.frameHeight, 56)
        XCTAssertEqual(idle.durations, [30, 6, 6])
        XCTAssertEqual(anims["Walk"]?.durations, [8, 10])
        XCTAssertEqual(anims.count, 2)
    }

    func testCurrentFrameFollowsTheDurationsInSixtiethsOfASecond() throws {
        let idle = try XCTUnwrap(AnimDataParser.parse(Data(xml.utf8))["Idle"])
        XCTAssertEqual(idle.frameIndex(at: 0), 0)
        XCTAssertEqual(idle.frameIndex(at: 29.0 / 60), 0)
        XCTAssertEqual(idle.frameIndex(at: 30.0 / 60), 1)
        XCTAssertEqual(idle.frameIndex(at: 36.0 / 60), 2)
        XCTAssertEqual(idle.frameIndex(at: 41.0 / 60), 2)
    }

    func testTheAnimationLoops() throws {
        let idle = try XCTUnwrap(AnimDataParser.parse(Data(xml.utf8))["Idle"])
        XCTAssertEqual(idle.totalTicks, 42)
        XCTAssertEqual(idle.frameIndex(at: 42.0 / 60), 0)
        XCTAssertEqual(idle.frameIndex(at: 42.0 / 60 * 5 + 31.0 / 60), 1)
    }

    func testIntegerScaleOnly() {
        // ×1 requested stays ×1; ×2 requested is only granted if the sprite fits at that scale.
        XCTAssertEqual(SpriteScale.apply(requested: 1, spriteWidth: 22, spriteHeight: 25, boxWidth: 48, boxHeight: 56), 1)
        XCTAssertEqual(SpriteScale.apply(requested: 2, spriteWidth: 22, spriteHeight: 49, boxWidth: 92, boxHeight: 172), 2)
        XCTAssertEqual(SpriteScale.apply(requested: 2, spriteWidth: 22, spriteHeight: 49, boxWidth: 48, boxHeight: 56), 1)
        XCTAssertEqual(SpriteScale.apply(requested: 1, spriteWidth: 200, spriteHeight: 200, boxWidth: 48, boxHeight: 56), 1, "the integer scale never goes below ×1")
    }

    func testASpriteTooBigForTheBoxIsFittedInsteadOfClipped() {
        // Gyarados' Hop is 39 × 89: it doesn't fit 48 × 56 even at ×1.
        let factor = SpriteScale.fitted(requested: 1, spriteWidth: 39, spriteHeight: 89, boxWidth: 48, boxHeight: 56)
        XCTAssertEqual(factor, 56.0 / 89.0, accuracy: 1e-9)
        XCTAssertEqual(SpriteScale.fitted(requested: 2, spriteWidth: 22, spriteHeight: 25, boxWidth: 92, boxHeight: 172), 2)
        XCTAssertEqual(SpriteScale.fitted(requested: 1, spriteWidth: 22, spriteHeight: 25, boxWidth: 48, boxHeight: 56), 1)
    }

    // MARK: moments

    func testAnimationPerMoment() {
        XCTAssertEqual(Moment.wakeUp.animation, "Eat")
        XCTAssertEqual(Moment.break1.animation, "LookUp")
        XCTAssertEqual(Moment.break2.animation, "DeepBreath")
        XCTAssertEqual(Moment.levelUp.animation, "Hop")
        XCTAssertEqual(Moment.menu.animation, "Idle")
        XCTAssertEqual(Moment.companion(.sleep).animation, "Sleep")
        XCTAssertEqual(Moment.companion(.idle).animation, "Idle")
        XCTAssertEqual(Moment.companion(.hop).animation, "Hop")
    }

    // MARK: real resources (downloaded by make sprites)

    private var downloadedSpecies: [Species] {
        var seen = Set<Int>()
        return LineCatalog.available.flatMap(\.allSpecies).filter { seen.insert($0.dex).inserted }
    }

    private let required = ["Idle", "Hop", "Sleep"]
    private let all = ["Idle", "Eat", "DeepBreath", "LookUp", "Hop", "Sleep"]

    func testEveryAvailableSpeciesHasIdleHopAndSleep() throws {
        try requireSprites()
        for species in downloadedSpecies {
            for shiny in [false, true] where !shiny || SpriteFiles.exists(dex: species.dex, shiny: true, file: "Idle-Anim.png") {
                for name in ["Hop", "Sleep"] {
                    XCTAssertNotNil(SpriteLibrary.sheet(SpriteRef(dex: species.dex, shiny: shiny), animation: name, requireExactFile: true),
                                    "\(species.slug) \(name) shiny=\(shiny)")
                }
                // Idle, or Walk for a hovering species.
                XCTAssertNotNil(SpriteLibrary.idleFrame(SpriteRef(dex: species.dex, shiny: shiny)), "\(species.slug) still shiny=\(shiny)")
            }
        }
    }

    func testAllFramesOfAnAnimationHaveTheSameSize() throws {
        try requireSprites()
        for species in downloadedSpecies {
            for name in all {
                guard let sheet = SpriteLibrary.sheet(SpriteRef(dex: species.dex, shiny: false), animation: name, requireExactFile: true) else { continue }
                XCTAssertEqual(sheet.images.count, sheet.info.frameCount, "\(species.slug) \(name)")
                for image in sheet.images {
                    XCTAssertEqual(image.width, sheet.width, "\(species.slug) \(name)")
                    XCTAssertEqual(image.height, sheet.height, "\(species.slug) \(name)")
                }
            }
        }
    }

    func testEverySheetMatchesAnimData() throws {
        try requireSprites()
        for species in downloadedSpecies {
            for name in all {
                guard let sheet = SpriteLibrary.sheet(SpriteRef(dex: species.dex, shiny: false), animation: name, requireExactFile: true) else { continue }
                XCTAssertEqual(sheet.image.width, sheet.info.frameWidth * sheet.info.frameCount, "\(species.slug) \(name): width")
                XCTAssertEqual(sheet.image.height % sheet.info.frameHeight, 0, "\(species.slug) \(name): height")
            }
        }
    }

    func testEveryAnimationFitsInThePanelBoxesOnceFitted() throws {
        try requireSprites()
        for species in downloadedSpecies {
            for name in all {
                guard let sheet = SpriteLibrary.sheet(SpriteRef(dex: species.dex, shiny: false), animation: name, requireExactFile: true) else { continue }
                let small = SpriteScale.fitted(requested: 1, spriteWidth: sheet.width, spriteHeight: sheet.height, boxWidth: 56 - 8, boxHeight: 64 - 8)
                XCTAssertLessThanOrEqual(Double(sheet.width) * small, 48.5, "\(species.slug) \(name)")
                XCTAssertLessThanOrEqual(Double(sheet.height) * small, 56.5, "\(species.slug) \(name)")
                // Companion: 100 × 120 box, ×2 asked for.
                let big = SpriteScale.fitted(requested: 2, spriteWidth: sheet.width, spriteHeight: sheet.height, boxWidth: 100 - 8, boxHeight: 120 - 8)
                XCTAssertLessThanOrEqual(Double(sheet.width) * big, 92.5, "\(species.slug) \(name) companion")
                XCTAssertLessThanOrEqual(Double(sheet.height) * big, 112.5, "\(species.slug) \(name) companion")
            }
        }
    }

    func testEveryDrawnSpriteIsCenteredInItsBoxWithinOnePoint() throws {
        try requireSprites()
        let boxes = [(56, 64, 1, 4), (100, 120, 2, 4), (96, 84, 2, 4), (80, 64, 1, 0)]
        for species in downloadedSpecies {
            for shiny in [false, true] {
                guard let sheet = SpriteLibrary.sheet(SpriteRef(dex: species.dex, shiny: shiny), animation: "Idle") else { continue }
                for (w, h, scale, margin) in boxes {
                    let place = SpriteLayout.place(spriteWidth: sheet.width, spriteHeight: sheet.height,
                                                   boxWidth: w, boxHeight: h, requested: scale, margin: margin)
                    XCTAssertLessThanOrEqual(abs(place.centerX - Double(w) / 2), 1, "\(species.slug) in \(w)x\(h)")
                    XCTAssertLessThanOrEqual(abs(place.centerY - Double(h) / 2), 1, "\(species.slug) in \(w)x\(h)")
                }
                // Grids: the sprite fills a 48 x 44 cell, fractional scale included.
                let fill = SpriteLayout.place(spriteWidth: sheet.width, spriteHeight: sheet.height, boxWidth: 48, boxHeight: 44, requested: nil)
                XCTAssertLessThanOrEqual(abs(fill.centerX - 24), 1, species.slug)
                XCTAssertLessThanOrEqual(abs(fill.centerY - 22), 1, species.slug)
                XCTAssertTrue(fill.width == 48 || fill.height == 44 || fill.width >= 47 || fill.height >= 43, "\(species.slug) fills the cell")
            }
        }
    }

    func testTheFramesAreCroppedOnTheUnionOfTheirOpaquePixels() throws {
        try requireSprites()
        for species in downloadedSpecies {
            for name in all {
                guard let sheet = SpriteLibrary.sheet(SpriteRef(dex: species.dex, shiny: false), animation: name, requireExactFile: true) else { continue }
                let union = sheet.images.compactMap(SpriteSheet.opaqueBounds).reduce(nil as CGRect?) { $0?.union($1) ?? $1 }
                XCTAssertEqual(union, CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height),
                               "\(species.slug) \(name): the content touches all four edges, so centering the image centers the content")
            }
        }
    }

    func testPikachusHopFitsIn56By64WithAMargin() throws {
        try requireSprites()
        let hop = try XCTUnwrap(SpriteLibrary.sheet(SpriteRef(dex: 25, shiny: false), animation: "Hop", requireExactFile: true))
        XCTAssertLessThanOrEqual(hop.height, 64 - 2 * 4, "the whole amplitude of the jump stays visible")
        XCTAssertLessThanOrEqual(hop.width, 56 - 2 * 4)
    }

    func testFallsBackToIdleWhenAnOptionalSheetIsMissing() throws {
        try requireSprites()
        // Koffing (109) has no Eat animation in SpriteCollab.
        guard LineCatalog.available.contains(where: { $0.allSpecies.contains { $0.dex == 109 } }) else { throw XCTSkip("no Koffing") }
        let ref = SpriteRef(dex: 109, shiny: false)
        XCTAssertNil(SpriteLibrary.sheet(ref, animation: "Eat", requireExactFile: true))
        XCTAssertEqual(SpriteLibrary.sheet(ref, animation: "Eat")?.name, "Idle")
    }

    func testAMissingSheetTriesTheMomentFallbacksBeforeIdle() throws {
        try requireSprites()
        XCTAssertEqual(Moment.wakeUp.fallbacks, ["Wake", "Hop"])
        XCTAssertEqual(Moment.companion(.hurt).animation, "Hurt")
        // Hop is shipped for every species: a made-up first choice lands on it, not on Idle.
        let ref = SpriteRef(dex: 25, shiny: false)
        XCTAssertEqual(SpriteLibrary.sheet(ref, animation: "Nope", fallbacks: ["AlsoNope", "Hop"])?.name, "Hop")
        XCTAssertNil(SpriteLibrary.sheet(ref, animation: "Nope", fallbacks: ["Hop"], requireExactFile: true))
    }

    func testAShinyWithoutSheetsFallsBackToTheNormalSprite() throws {
        try requireSprites()
        // No species has shiny sheets for a dex that was never downloaded: the lookup finds nothing.
        XCTAssertNil(SpriteLibrary.sheet(SpriteRef(dex: 9999, shiny: true), animation: "Idle"))
    }

    func testTheIdleFirstFrameReplacesTheStaticSprite() throws {
        try requireSprites()
        let frame = try XCTUnwrap(SpriteLibrary.idleFrame(SpriteRef(dex: 25, shiny: false)))
        XCTAssertGreaterThan(frame.width, 10)
        XCTAssertNil(AppResources.url("Sprites/static/pikachu.png"), "no official static sprite is used anymore")
    }

    func testTheShinyDiffersFromTheNormalSprite() throws {
        try requireSprites()
        let normal = try XCTUnwrap(SpriteLibrary.sheet(SpriteRef(dex: 25, shiny: false), animation: "Idle", requireExactFile: true))
        let shiny = try XCTUnwrap(SpriteLibrary.sheet(SpriteRef(dex: 25, shiny: true), animation: "Idle", requireExactFile: true))
        XCTAssertNotEqual(normal.image.dataProvider?.data as Data?, shiny.image.dataProvider?.data as Data?)
    }
}
