import AppKit
import SwiftUI

/// Still sprite for the status bar: the first frame of the Idle animation (no static sprite is
/// shipped), scaled to `height` pt (20 by default, rendered at 2x for Retina) without smoothing.
enum StatusIcon {
    /// `asleep`: the first frame of the Sleep animation (Idle if the species has none).
    static func image(for sprite: SpriteRef, asleep: Bool = false, height: CGFloat = 20) -> NSImage? {
        guard let frame = asleep ? SpriteLibrary.sheet(sprite, animation: "Sleep")?.images.first : SpriteLibrary.idleFrame(sprite)
        else { return nil }
        return image(from: frame, height: height)
    }

    static func image(from cropped: CGImage, height: CGFloat = 20) -> NSImage? {
        let scale: CGFloat = 2
        let pixelH = Int(height * scale)
        let pixelW = max(1, Int((CGFloat(cropped.width) / CGFloat(cropped.height) * CGFloat(pixelH)).rounded()))
        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
        guard let scaled = ctx.makeImage() else { return nil }
        let image = NSImage(cgImage: scaled, size: NSSize(width: CGFloat(pixelW) / scale, height: height))
        image.isTemplate = false
        return image
    }
}

/// What the pill shows next to the sprite.
enum StatusPillState: Equatable {
    /// "25:00", "9:59". `suspended`: timer paused (idle, locked, suspended), shown dimmed.
    case timer(text: String, suspended: Bool)
    case pause
    case waiting
    /// Outside the active hours: no counter, the Pokémon sleeps.
    case asleep

    var slot: TimerWidth.Slot {
        switch self {
        case let .timer(text, _): .timer(minuteDigits: text.count >= 5 ? 2 : 1)
        case .pause: .pause
        case .waiting, .asleep: .waiting
        }
    }

    var text: String {
        switch self {
        case let .timer(text, _): text
        case .pause: tr("pill.pause")
        case .waiting: "···"
        case .asleep: tr("pill.asleep")
        }
    }
}

struct MenuBarLabel: View {
    let sprite: SpriteRef
    let state: StatusPillState
    #if STRETCHU_DEBUG
    var debug = false
    #endif

    var body: some View {
        HStack(spacing: 3) {
            if let icon = StatusIcon.image(for: sprite, asleep: state == .asleep) {
                Image(nsImage: icon)
            }
            Group {
                if state == .asleep {
                    SleepZs()
                } else {
                    FixedText(text: state.text)
                        .opacity({ if case .timer(_, true) = state { return 0.5 } else { return 1 } }())
                }
            }
            .frame(width: TimerWidth.slot(state.slot), alignment: .center)
            #if STRETCHU_DEBUG
            if debug { Circle().fill(Color.orange).frame(width: 6, height: 6) }
            #endif
        }
        .fixedSize()
    }
}

/// "z Z Z" climbing in a diagonal, growing as it goes up, like the sleep emoji.
struct SleepZs: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            z(8).offset(y: 1)
            z(10).offset(y: -2)
            z(12).offset(y: -5)
        }
        .frame(height: 20)
    }

    private func z(_ size: CGFloat) -> some View {
        Text("z").font(.system(size: size, weight: .bold, design: .rounded))
    }
}

/// Each character in its own cell: a narrow digit never shifts the others.
struct FixedText: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(Font(TimerWidth.font))
                    .frame(width: TimerWidth.cellWidth(character))
            }
        }
        .fixedSize()
    }
}
