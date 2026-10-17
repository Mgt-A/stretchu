import AppKit

/// No SwiftUI scene: the app has no window or menu bar, only the status bar icon
/// and its panels, all created by `AppDelegate` (SwiftUI is used for the views).
@main
@MainActor
enum StretchuMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
