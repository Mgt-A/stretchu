import AppKit
import SwiftUI

/// Dark translucent panel background: NSVisualEffectView `.hudWindow`, radius 20.
@MainActor
func makeGlassBackground(cornerRadius: CGFloat = 20) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    view.appearance = NSAppearance(named: .darkAqua)
    view.wantsLayer = true
    view.layer?.cornerRadius = cornerRadius
    view.layer?.masksToBounds = true
    return view
}
