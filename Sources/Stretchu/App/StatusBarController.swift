import AppKit
import SwiftUI

/// Status bar icon: sprite and timer in a SwiftUI view placed on the button.
/// A click opens the menu in a panel anchored under the icon, like all the other panels
/// (⌥ click: Debug page). The click is read from `NSApp.currentEvent`, so ⌥ is reliable.
@MainActor
final class StatusBarController: NSObject {
    private let item: NSStatusItem
    private let model: AppModel
    private let hosting: NSHostingView<StatusPillView>

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hosting = ClickThroughHostingView(rootView: StatusPillView(model: model))
        super.init()
        guard let button = item.button else { return }
        button.addSubview(hosting)
        button.target = self
        button.action = #selector(click(_:))
        button.sendAction(on: [.leftMouseDown])
        model.onUpdate = { [weak self] in self?.adjust() }
        model.onMenuClose = { [weak self] in self?.item.button?.highlight(false) }
        model.onMenuOpen = { [weak self] in self?.item.button?.highlight(true) }
        adjust()
    }

    @objc private func click(_ sender: Any?) {
        updateAnchor()
        let option = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        model.toggleMenu(option: option)
    }

    /// Panels open under the icon: remember its center (screen coordinates).
    private func updateAnchor() {
        guard let window = item.button?.window, window.frame.width > 1 else { return }
        StatusBarAnchor.shared.centerX = window.frame.midX
        StatusBarAnchor.shared.screen = window.screen
    }

    /// Fits the item's width to its content. Digit cells being fixed, it only changes when
    /// the state changes (timer, break), never from one second to the next.
    private func adjust() {
        guard let button = item.button else { return }
        let size = hosting.fittingSize
        let margin: CGFloat = 4
        let width = ceil(size.width) + margin * 2
        if abs(item.length - width) > 0.5 { item.length = width }
        updateAnchor()
        hosting.frame = NSRect(x: margin, y: ((button.bounds.height - size.height) / 2).rounded(),
                               width: ceil(size.width), height: ceil(size.height))
    }
}

/// Hosting view that lets clicks through to the status bar button.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Icon content: species sprite and text (timer, "Break", "···").
struct StatusPillView: View {
    let model: AppModel

    var body: some View {
        #if STRETCHU_DEBUG
        MenuBarLabel(sprite: model.sprite, state: model.pillState, debug: model.debugMode)
        #else
        MenuBarLabel(sprite: model.sprite, state: model.pillState)
        #endif
    }
}
