import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var model: AppModel?
    private var statusBar: StatusBarController?
    private var onboarding: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Safety net: launched outside a bundle (swift run), no Dock icon either.
        NSApp.setActivationPolicy(.accessory)
        #if STRETCHU_DEBUG
        // `make debug` and `make demo` start in Debug mode (STRETCHU_DEBUG=1).
        let appModel = AppModel(startInDebug: AppModel.startsInDebug)
        #else
        let appModel = AppModel()
        #endif
        model = appModel

        let setup = OnboardingWindowController(app: appModel)
        onboarding = setup
        appModel.onShowOnboarding = { [weak setup] in setup?.show(mode: .relaunch) }
        // The first setup comes before any icon: the icon appears when it is finished.
        setup.onFirstSetupDone = { [weak self] in self?.showStatusBar(openMenu: true) }

        if appModel.onboardingCompleted {
            showStatusBar(openMenu: false)
        } else {
            setup.show(mode: .firstLaunch)
        }
    }

    /// Creates the icon. After the first setup the menu opens once under it, to show where
    /// Stretchu lives.
    private func showStatusBar(openMenu: Bool) {
        guard let model, statusBar == nil else { return }
        statusBar = StatusBarController(model: model)
        if openMenu {
            DispatchQueue.main.async { model.openMenu() }
        }
    }
}
