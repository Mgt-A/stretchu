#if STRETCHU_DEBUG
import AppKit
import Foundation

/// Everything the Debug panel (and the `ch.antoine.stretchu.debug` command) can do.
enum DebugAction: Equatable {
    // triggers
    case wakeUp, start, complete, skip, meetingStart, meetingEnd, levelUp
    case ssid(String?)
    // simulated time
    case advance25Minutes, nextWorkday, weekend, realTime
    // state
    case level(Int), xp(Int), streak(Int), breaksToday(Int), cycles(Int)
    case fixture(String), reset
    case line(String), shiny(Bool), branch(Int?)
    case mode(PlaceMode)
    case iconClick(option: Bool)
    // window
    case openPanel, closePanel, replaySetup
    case page(String), cycleChoice, branchChoice

    /// "level:33", "xp:35936", "fixture:pichu-lv1", "wakeup"…
    init?(command: String) {
        let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
        let value = parts.count > 1 ? parts[1] : ""
        let number = Int(value)
        switch parts.first {
        case "wakeup": self = .wakeUp
        case "start": self = .start
        case "complete": self = .complete
        case "skip": self = .skip
        case "levelup": self = .levelUp
        case "ssid": self = .ssid(value.isEmpty ? nil : value)
        case "meeting": self = .meetingStart
        case "endmeeting": self = .meetingEnd
        case "advance25": self = .advance25Minutes
        case "day": self = .nextWorkday
        case "weekend": self = .weekend
        case "real": self = .realTime
        case "level": guard let number else { return nil }; self = .level(number)
        case "xp": guard let number else { return nil }; self = .xp(number)
        case "streak": guard let number else { return nil }; self = .streak(number)
        case "breaks": guard let number else { return nil }; self = .breaksToday(number)
        case "cycles": guard let number else { return nil }; self = .cycles(number)
        case "fixture": self = .fixture(value)
        case "home": self = .mode(.home)
        case "office": self = .mode(.office)
        case "iconclick": self = .iconClick(option: value == "option")
        case "reset": self = .reset
        case "line": self = .line(value)
        case "shiny": self = .shiny(value != "off")
        case "branch": self = .branch(number)
        case "panel": self = .openPanel
        case "close": self = .closePanel
        case "setup": self = .replaySetup
        case "page": self = .page(value)
        case "cyclechoice": self = .cycleChoice
        case "branchchoice": self = .branchChoice
        default: return nil
        }
    }
}

extension AppModel {
    func execute(_ action: DebugAction) {
        // Never write to the real state: every action goes through Debug mode first.
        if case .iconClick = action {} else if action != .closePanel, action != .openPanel, action != .replaySetup, !debugMode { enterDebug() }
        switch action {
        case .wakeUp:
            applyToScheduler { $0.triggerWakeUp() }
        case .start:
            start()
        case .complete:
            applyToScheduler { $0.completeNow() }
        case .skip:
            applyToScheduler { $0.skipNow() }
        case .levelUp:
            triggerLevelUpDebug()
        case let .ssid(name):
            debugSSID = name
            readNetwork(name)
        case .meetingStart:
            setFakeMeeting(true)
        case .meetingEnd:
            setFakeMeeting(false)

        case .advance25Minutes:
            clock.advance(by: 25 * 60)
        case .nextWorkday:
            clock.jump(to: calendar.nextWorkday(after: clock.now))
            resyncAfterClockJump()
        case .weekend:
            clock.jump(to: calendar.nextMonday(after: clock.now))
            resyncAfterClockJump()
        case .realTime:
            clock.reset()
            resyncAfterClockJump()

        case let .level(n): modifyState { $0.progression.setLevel(n) }
        case let .xp(xp): modifyState { $0.progression.xp = min(max(0, xp), Progression.totalXP(forLevel: Progression.maxLevel)) }
        case let .streak(s): modifyState { $0.streak.count = min(max(0, s), 60) }
        case let .breaksToday(p): modifyState { $0.streak.breaksToday = min(max(0, p), 10) }
        case let .cycles(c): modifyState { $0.progression.setCompletedCycles(c) }
        case let .fixture(name):
            if var state = Fixtures.state(name) {
                state.streak.currentDay = nil
                replaceState(state)
            }
        case .reset:
            replaceState(GameState())
        case let .line(id):
            if LineCatalog.available.contains(where: { $0.id == id }) {
                modifyState { $0.pokemon = CurrentPokemon(lineId: id, shiny: $0.pokemon.shiny, branchDex: nil) }
            }
        case let .shiny(on):
            modifyState { $0.pokemon.shiny = on && LineCatalog.hasShiny($0.line) }
        case let .branch(dex):
            modifyState { $0.pokemon.branchDex = dex }
        case let .mode(m):
            toggleMode(m)
        case let .iconClick(option):
            // Simulated click on the status bar icon (NSApp.sendEvent, no accessibility permission).
            for w in NSApp.windows where w.className.contains("StatusBar") {
                var button: NSStatusBarButton?
                func search(_ v: NSView) { if let b = v as? NSStatusBarButton { button = b } else { v.subviews.forEach(search) } }
                if let v = w.contentView { search(v) }
                guard button != nil else { continue }
                let point = NSPoint(x: w.frame.width / 2, y: w.frame.height / 2)
                if let e = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: option ? [.option] : [],
                                              timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: w.windowNumber,
                                              context: nil, eventNumber: 1, clickCount: 1, pressure: 1) {
                    NSApp.sendEvent(e)
                }
            }
        case .openPanel: openMenu(page: .debug)
        case .closePanel: closeMenu()
        case .replaySetup: rerunSetup()
        case let .page(name):
            let pages: [String: MenuPage] = ["menu": .menu, "companion": .companion, "settings": .settings, "credits": .credits,
                                             "hof": .hallOfFame, "abandon": .abandon, "debug": .debug]
            if let page = pages[name] { openMenu(page: page) }
        case .cycleChoice: showCycleChoiceDebug()
        case .branchChoice: showBranchChoiceDebug()
        }
    }
}

/// Driving from a terminal (`STRETCHU_DEBUG=1`, development): distributed notification
/// `ch.antoine.stretchu.debug`, see README.
@MainActor
final class DebugSupport {
    static let notificationName = Notification.Name("ch.antoine.stretchu.debug")

    private var observer: NSObjectProtocol?

    init(model: AppModel) {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.notificationName, object: nil, queue: .main
        ) { [weak model] note in
            let command = note.userInfo?["command"] as? String
            MainActor.assumeIsolated {
                guard let command, let action = DebugAction(command: command) else { return }
                model?.execute(action)
            }
        }
    }
}
#endif
