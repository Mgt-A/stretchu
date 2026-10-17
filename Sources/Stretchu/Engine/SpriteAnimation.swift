import CoreGraphics
import Foundation
import ImageIO

/// One animation of AnimData.xml: frame size and durations in 1/60 s ticks.
struct AnimationInfo: Equatable {
    let name: String
    let frameWidth: Int
    let frameHeight: Int
    let durations: [Int]

    var frameCount: Int { durations.count }
    var totalTicks: Int { durations.reduce(0, +) }

    /// Frame to show after `elapsed` seconds; the animation loops.
    func frameIndex(at elapsed: TimeInterval) -> Int {
        guard totalTicks > 0 else { return 0 }
        let ticks = Int((elapsed * 60).rounded(.down))
        var remaining = ((ticks % totalTicks) + totalTicks) % totalTicks
        for (index, duration) in durations.enumerated() {
            if remaining < duration { return index }
            remaining -= duration
        }
        return 0
    }
}

enum AnimDataParser {
    static func parse(_ data: Data) -> [String: AnimationInfo] {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return Dictionary(delegate.animations.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var animations: [AnimationInfo] = []
        private var text = ""
        private var name = "", width = 0, height = 0, durations: [Int] = []
        private var insideAnim = false

        func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            text = ""
            if element == "Anim" { insideAnim = true; name = ""; width = 0; height = 0; durations = [] }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
            guard insideAnim else { return }
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch element {
            case "Name": name = value
            case "FrameWidth": width = Int(value) ?? 0
            case "FrameHeight": height = Int(value) ?? 0
            case "Duration": if let d = Int(value) { durations.append(d) }
            case "Anim":
                insideAnim = false
                if !name.isEmpty, width > 0, height > 0, !durations.isEmpty {
                    animations.append(AnimationInfo(name: name, frameWidth: width, frameHeight: height, durations: durations))
                }
            default: break
            }
        }
    }
}

/// App moments and their animation.
enum Moment: Equatable {
    case wakeUp, break1, break2, levelUp, menu
    case companion(Mood)

    var animation: String {
        switch self {
        case .wakeUp: "Eat"
        case .break1: "LookUp"
        case .break2: "DeepBreath"
        case .levelUp: "Hop"
        case .menu: "Idle"
        case let .companion(mood): mood.animationName
        }
    }
}

enum SpriteScale {
    /// Margin above a sprite vertically centered in a box (0 if it doesn't fit).
    static func topOffset(spriteHeight: Int, boxHeight: Int) -> Int {
        max(0, (boxHeight - spriteHeight) / 2)
    }

    /// Scale to draw a sprite with: the integer scale of `apply`, or, for a sprite that doesn't fit
    /// even at ×1 (Onix, Gyarados, Moltres…), the largest fraction that does fit the box.
    static func fitted(requested: Int, spriteWidth: Int, spriteHeight: Int, boxWidth: Int, boxHeight: Int) -> Double {
        let integer = apply(requested: requested, spriteWidth: spriteWidth, spriteHeight: spriteHeight,
                            boxWidth: boxWidth, boxHeight: boxHeight)
        if spriteWidth * integer <= boxWidth, spriteHeight * integer <= boxHeight { return Double(integer) }
        return min(Double(boxWidth) / Double(spriteWidth), Double(boxHeight) / Double(spriteHeight))
    }

    /// Integer scale asked for by the context (×1 in 56 × 64 boxes, ×2 for the companion),
    /// brought back to ×1 if the sprite doesn't fit in the box at that scale.
    static func apply(requested: Int, spriteWidth: Int, spriteHeight: Int, boxWidth: Int, boxHeight: Int) -> Int {
        var scale = max(1, requested)
        while scale > 1, spriteWidth * scale > boxWidth || spriteHeight * scale > boxHeight {
            scale -= 1
        }
        return scale
    }
}

/// Where a sprite is drawn in a box: every sprite of the app goes through here, so that all of them
/// are centered on their content (the frames are already cropped to the bounds of the whole
/// animation, see `SpriteSheet`).
enum SpriteLayout {
    struct Placement: Equatable {
        var x: Int
        var y: Int
        var width: Int
        var height: Int

        /// Center of the sprite in the box's coordinates.
        var centerX: Double { Double(x) + Double(width) / 2 }
        var centerY: Double { Double(y) + Double(height) / 2 }
    }

    /// `requested` is the integer scale the context asks for (brought back if it doesn't fit);
    /// `nil` fills the box with the largest scale that fits, fractional, so that grid cells look
    /// equally big. `margin` is kept free on every side.
    static func place(spriteWidth: Int, spriteHeight: Int, boxWidth: Int, boxHeight: Int,
                      requested: Int?, margin: Int = 0) -> Placement {
        let innerWidth = max(1, boxWidth - 2 * margin), innerHeight = max(1, boxHeight - 2 * margin)
        let factor = requested.map {
            SpriteScale.fitted(requested: $0, spriteWidth: spriteWidth, spriteHeight: spriteHeight,
                               boxWidth: innerWidth, boxHeight: innerHeight)
        } ?? min(Double(innerWidth) / Double(spriteWidth), Double(innerHeight) / Double(spriteHeight))
        let width = min(boxWidth, max(1, Int((Double(spriteWidth) * factor).rounded())))
        let height = min(boxHeight, max(1, Int((Double(spriteHeight) * factor).rounded())))
        return Placement(x: (boxWidth - width) / 2, y: (boxHeight - height) / 2, width: width, height: height)
    }
}

/// A sliced PMD animation sheet: the frames of row 0 (facing the camera).
/// PMD cells have a lot of margin and the sprite isn't set at the bottom (Hop: the
/// character takes the top of an 88 pt cell). Each frame is therefore cropped to the
/// bounds of the whole animation: same size for all, the jump keeps its amplitude.
struct SpriteSheet {
    let name: String
    let info: AnimationInfo
    /// The whole sheet, to check consistency with AnimData.xml.
    let image: CGImage
    /// Frames cropped to the common bounds.
    let images: [CGImage]
    /// Size of the bounds in pixels.
    let width: Int
    let height: Int

    init(name: String, info: AnimationInfo, image: CGImage) {
        self.name = name
        self.info = info
        self.image = image
        let cells = (0..<info.frameCount).compactMap { index in
            image.cropping(to: CGRect(x: index * info.frameWidth, y: 0, width: info.frameWidth, height: info.frameHeight))
        }
        let bounds = cells.compactMap(Self.opaqueBounds).reduce(nil as CGRect?) { $0?.union($1) ?? $1 }
            ?? CGRect(x: 0, y: 0, width: info.frameWidth, height: info.frameHeight)
        self.images = cells.compactMap { $0.cropping(to: bounds) }
        self.width = Int(bounds.width)
        self.height = Int(bounds.height)
    }

    /// Rectangle of the non-transparent pixels, origin at the top left.
    static func opaqueBounds(_ image: CGImage) -> CGRect? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where px[(y * w + x) * 4 + 3] > 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

enum SpriteLibrary {
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var infos: [String: [String: AnimationInfo]] = [:]
        var images: [String: CGImage] = [:]
        var sheets: [String: SpriteSheet] = [:]
    }
    private static let cache = Cache()

    private static func folder(_ ref: SpriteRef) -> String {
        "Sprites/pmd/\(String(format: "%04d", ref.dex))\(ref.shiny ? "/shiny" : "")"
    }

    private static func infos(_ ref: SpriteRef) -> [String: AnimationInfo] {
        cache.lock.lock(); defer { cache.lock.unlock() }
        let key = folder(ref)
        if let known = cache.infos[key] { return known }
        let read = AppResources.url("\(key)/AnimData.xml")
            .flatMap { try? Data(contentsOf: $0) }
            .map(AnimDataParser.parse) ?? [:]
        cache.infos[key] = read
        return read
    }

    private static func image(_ ref: SpriteRef, _ animation: String) -> CGImage? {
        cache.lock.lock(); defer { cache.lock.unlock() }
        let key = "\(folder(ref))/\(animation)"
        if let known = cache.images[key] { return known }
        guard let url = AppResources.url("\(folder(ref))/\(animation)-Anim.png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        cache.images[key] = image
        return image
    }

    /// The requested sheet; if the file is missing, Idle, unless `requireExactFile`.
    /// A shiny whose sheets are missing falls back to the normal sprite.
    static func sheet(_ ref: SpriteRef, animation: String, requireExactFile: Bool = false) -> SpriteSheet? {
        // Idle when the animation is missing; hovering Pokémon (Beedrill, Dragonair…) have no Idle sheet, their Walk is the same pose.
        let candidates = requireExactFile ? [animation] : [animation, "Idle", "Walk"]
        let name = candidates.first { infos(ref)[$0] != nil && image(ref, $0) != nil }
        guard let name, let info = infos(ref)[name], let image = image(ref, name) else {
            return ref.shiny && !requireExactFile ? sheet(SpriteRef(dex: ref.dex, shiny: false), animation: animation) : nil
        }
        let key = "\(folder(ref))/\(name)"
        cache.lock.lock(); defer { cache.lock.unlock() }
        if let known = cache.sheets[key] { return known }
        let sheet = SpriteSheet(name: name, info: info, image: image)
        cache.sheets[key] = sheet
        return sheet
    }

    /// First frame of the Idle animation (Walk for a species without an Idle sheet): the still picture used by the status bar icon and the
    /// evolution chain (no static sprite is shipped).
    static func idleFrame(_ ref: SpriteRef) -> CGImage? {
        sheet(ref, animation: "Idle")?.images.first
    }

    /// Picture of an evolution stone (Resources/Sprites/items).
    static func stoneImage(_ stone: String) -> CGImage? {
        guard let url = AppResources.url("Sprites/items/\(stone).png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
