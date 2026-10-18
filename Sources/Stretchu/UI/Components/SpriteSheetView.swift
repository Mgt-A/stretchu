import AppKit
import SwiftUI

/// Plays a species' PMD animation: row 0, AnimData.xml durations, integer scale,
/// no smoothing. Without a sheet for the requested animation, falls back to Idle.
/// The sprite is centered in the box on the bounds of the whole animation: a jump keeps
/// its margin above and below, a still sprite is neither too high nor too low.
struct SpriteSheetView: View {
    let sprite: SpriteRef
    let animation: String
    var boxWidth = 56
    var boxHeight = 64
    /// ×1 in the small boxes, ×2 for the companion.
    var scale = 1
    var margin = 4
    /// 1 is the animation's own speed.
    var speed = 1.0

    var body: some View {
        if let sheet = SpriteLibrary.sheet(sprite, animation: animation) {
            let place = SpriteLayout.place(spriteWidth: sheet.width, spriteHeight: sheet.height,
                                           boxWidth: boxWidth, boxHeight: boxHeight, requested: scale, margin: margin)
            Color.clear
                .frame(width: CGFloat(boxWidth), height: CGFloat(boxHeight))
                .overlay(alignment: .topLeading) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        let index = sheet.info.frameIndex(at: context.date.timeIntervalSinceReferenceDate * speed)
                        Image(decorative: sheet.images[min(index, sheet.images.count - 1)], scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: CGFloat(place.width), height: CGFloat(place.height))
                    }
                    .fixedSize()
                    .padding(.leading, CGFloat(place.x))
                    .padding(.top, CGFloat(place.y))
                }
        }
    }
}

/// Sprite box (56 × 64 pt, radius 12, 8 % white fill), sprite centered.
/// The companion uses 100 × 120, radius 14, at ×2 scale.
struct SpriteBox: View {
    let sprite: SpriteRef
    let moment: Moment
    var width = 56
    var height = 64
    var radius: CGFloat = Radius.card
    var scale = 1
    /// 1 is the animation's own speed.
    var speed = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(Color.white.opacity(0.08))
            SpriteSheetView(sprite: sprite, animation: moment.animation, boxWidth: width, boxHeight: height, scale: scale, speed: speed)
        }
        .frame(width: CGFloat(width), height: CGFloat(height))
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
