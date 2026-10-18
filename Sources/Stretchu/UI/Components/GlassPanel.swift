import AppKit
import SwiftUI

/// Dark translucent panel background: NSVisualEffectView `.hudWindow`, radius 20.
@MainActor
func makeGlassBackground(cornerRadius: CGFloat = Radius.panel) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    view.appearance = NSAppearance(named: .darkAqua)
    // A layer cornerRadius does not clip the behind-window blur (square corners show through
    // as light triangles); the material has to be masked with maskImage instead.
    if cornerRadius > 0 { view.maskImage = roundedMask(cornerRadius: cornerRadius) }
    return view
}

private func roundedMask(cornerRadius: CGFloat) -> NSImage {
    let edge = cornerRadius * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        return true
    }
    image.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
    image.resizingMode = .stretch
    return image
}
