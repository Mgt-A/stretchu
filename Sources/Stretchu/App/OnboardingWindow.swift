import AppKit
import SwiftUI

/// A window that can take the keyboard even though the app has no Dock icon.
private final class SetupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The setup window: centered on the screen, 340 × 620, keyboard focus (Tab, Return, Esc = Back).
/// Closing it counts as "Skip" the first time, and cancels when the setup is replayed.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let app: AppModel
    private var window: NSWindow?
    private var model: OnboardingModel?
    /// Called once the first setup is finished or skipped: the icon can appear.
    var onFirstSetupDone: (() -> Void)?

    init(app: AppModel) {
        self.app = app
        super.init()
    }

    var isOpen: Bool { window?.isVisible ?? false }

    func show(mode: OnboardingModel.Mode) {
        if let window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let model = OnboardingModel(app: app, mode: mode)
        model.onDone = { [weak self] applied in self?.close(applied: applied, mode: mode) }
        self.model = model

        let window = SetupWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.delegate = self

        let glass = makeGlassBackground(cornerRadius: 0)
        let hosting = NSHostingView(rootView: OnboardingView(model: model).environment(\.colorScheme, .dark).preferredColorScheme(.dark))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: glass.leadingAnchor), hosting.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: glass.topAnchor), hosting.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        window.contentView = glass
        window.center()
        self.window = window
        #if STRETCHU_DEBUG
        // Development: pick a language a moment after the window shows, to check the live redraw.
        if let pick = ProcessInfo.processInfo.environment["STRETCHU_SETUP_PICK_LANGUAGE"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak model] in model?.setLanguage(pick) }
        }
        #endif
        bringToFront(window)
        // An app without a Dock icon is not always activated at once at launch: ask again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak window] in
            guard let window, self?.window === window else { return }
            self?.bringToFront(window)
        }
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // The close button is "Skip" the first time, a cancel when replaying.
        model?.skip()
        return false
    }

    private func close(applied: Bool, mode: OnboardingModel.Mode) {
        window?.orderOut(nil)
        window = nil
        model = nil
        if applied && mode == .firstLaunch { onFirstSetupDone?() }
    }
}
