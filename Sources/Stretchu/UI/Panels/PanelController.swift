import AppKit
import SwiftUI

/// Horizontal position of a panel: centered under the status bar icon, bounded to the screen.
enum PanelPlacement {
    static func x(iconCenter: CGFloat?, width: CGFloat, screenMinX: CGFloat, screenMaxX: CGFloat, margin: CGFloat) -> CGFloat {
        let maxX = screenMaxX - width - margin
        guard let iconCenter else { return maxX }
        return min(max(iconCenter - width / 2, screenMinX + margin), maxX)
    }
}

/// Where the status bar icon is: every panel (menu, wake-up, breaks…) opens below it,
/// at the same place. Without a known icon (tests), falls back to the top right corner.
@MainActor
final class StatusBarAnchor {
    static let shared = StatusBarAnchor()
    var centerX: CGFloat?
    var screen: NSScreen?
}

enum PanelSize: Equatable {
    case short, tall
    /// Height of the content (companion opened from Level up), width always 340.
    case content

    static let width: CGFloat = 340
    var height: CGFloat {
        switch self {
        case .short: 228
        case .tall: 620
        case .content: 0
        }
    }
}

/// NSPanel that never takes keyboard focus (except the menu, which needs shortcuts)
/// and never activates the app.
final class StretchuPanel: NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

/// A floating panel anchored under the status bar icon, 10 pt below the menu bar and 10 pt from the edge.
@MainActor
final class PanelController {
    private var panel: StretchuPanel?
    private var hosting: NSHostingView<AnyView>?
    private let acceptsKeyboard: Bool

    /// `acceptsKeyboard`: the menu must receive ⌘P, ⌘L, Esc… (the break panels never do).
    init(acceptsKeyboard: Bool = false) {
        self.acceptsKeyboard = acceptsKeyboard
    }

    var window: NSPanel? { panel }

    var isVisible: Bool { panel?.isVisible ?? false }
    var windowNumber: Int? { panel?.windowNumber }

    func present<Content: View>(size: PanelSize, @ViewBuilder content: () -> Content) {
        let root = AnyView(content().environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        let panel = self.panel ?? makePanel()
        self.panel = panel

        if let hosting {
            hosting.rootView = root
        } else if let effect = panel.contentView {
            let host = NSHostingView(rootView: root)
            host.sceneBridgingOptions = []
            host.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                host.topAnchor.constraint(equalTo: effect.topAnchor),
                host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            ])
            hosting = host
        }

        var contentHeight: CGFloat?
        if size == .content, let hosting {
            hosting.layoutSubtreeIfNeeded()
            contentHeight = ceil(hosting.fittingSize.height)
        }
        let frame = frame(for: size, height: contentHeight)
        let alreadySized = panel.frame == frame
        if panel.isVisible, !alreadySized {
            panel.setFrame(frame, display: true, animate: true)
        } else if !panel.isVisible {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless() // never makeKeyAndOrderFront: the app doesn't activate
            if acceptsKeyboard { panel.makeKey() }
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        }
    }

    /// Fits the height to the content (menu: the page changes, rows appear), without animation.
    func fitToContent() {
        guard let panel, panel.isVisible, let hosting else { return }
        hosting.layoutSubtreeIfNeeded()
        let target = frame(for: .content, height: ceil(hosting.fittingSize.height))
        if abs(panel.frame.height - target.height) > 0.5 || panel.frame.origin != target.origin {
            panel.setFrame(target, display: true)
        }
    }

    func dismiss() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func makePanel() -> StretchuPanel {
        let panel = StretchuPanel(
            contentRect: frame(for: .short),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.acceptsKeyboard = acceptsKeyboard
        panel.isFloatingPanel = true // first: this setting resets the level to .floating
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = makeGlassBackground()
        return panel
    }

    private func frame(for size: PanelSize, height: CGFloat? = nil) -> NSRect {
        let h = height ?? size.height
        let anchor = StatusBarAnchor.shared
        let screen = anchor.screen ?? NSScreen.screens.first ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 10
        let x = PanelPlacement.x(iconCenter: anchor.centerX, width: PanelSize.width,
                                 screenMinX: visible.minX, screenMaxX: visible.maxX, margin: margin)
        let y = visible.maxY - margin - h
        return NSRect(x: x, y: y, width: PanelSize.width, height: h)
    }
}
