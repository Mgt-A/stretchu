import AppKit
import SwiftUI

/// Content of the menu panel: the main page, or the companion, settings, debug in its place
/// (same width, back arrow, height following the content), anchored under the icon like the other panels.
struct MenuRoot: View {
    let model: AppModel

    var body: some View {
        Group {
            switch model.page {
            case .menu: MenuView(model: model)
            case .companion: CompanionView(model: model, back: { model.back() })
            case .settings: SettingsView(model: model)
            case .credits: CreditsView(model: model)
            case .hallOfFame: HallOfFameView(model: model)
            case .abandon: AbandonView(model: model)
            case .cycleStats: CycleStatsView(model: model)
            #if STRETCHU_DEBUG
            case .debug: DebugPageView(model: model)
            #endif
            }
        }
        .frame(width: PanelSize.width, alignment: .topLeading)
        .foregroundStyle(.white)
    }
}

/// Header of the secondary pages: back arrow and title.
struct PageHeader: View {
    let title: String
    let back: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white.opacity(0.14)))
                    .contentShape(RoundedRectangle(cornerRadius: Radius.control))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help(tr("common.back"))
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
    }
}

/// `C · Status bar menu`.
struct MenuView: View {
    let model: AppModel

    var body: some View {
        let p = model.game.progression
        let streak = model.game.streak

        VStack(alignment: .leading, spacing: 6) {
            #if STRETCHU_DEBUG
            if model.debugMode { debugBadge }
            #endif

            header(p)
                .padding(8)

            // Both cards have the same height.
            HStack(alignment: .top, spacing: 6) {
                multiplierCard(streak)
                nextBreakCard
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)

            Text(trPlural("menu.breaksToday", count: streak.breaksToday, streak.breaksToday))
                .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6)).monospacedDigit()
                .padding(.horizontal, 10).padding(.vertical, 4)

            separator()

            VStack(alignment: .leading, spacing: 8) {
                ModePicker(mode: model.mode) { model.toggleMode($0) }
                wifiLines
                meetingLine
                if let resume = model.resumeText {
                    Text(resume).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)

            separator()

            VStack(spacing: 1) {
                Button { model.closeMenu(); model.breakNow() } label: {
                    row(tr("menu.breakNow"), "⌘P")
                }
                .buttonStyle(MenuRowButtonStyle(isPrimary: true))
                .keyboardShortcut("p", modifiers: .command)
                .disabled(model.phase != .work)

                Button { model.toggleSuspension() } label: {
                    row(model.suspendedUntil == nil ? tr("menu.suspend") : tr("menu.resume"), nil)
                }
                .buttonStyle(MenuRowButtonStyle())
                .disabled(model.phase != .work)

                Button { model.go(.companion) } label: { row(tr("menu.companion"), "⌘L") }
                    .buttonStyle(MenuRowButtonStyle())
                    .keyboardShortcut("l", modifiers: .command)

                Button { model.go(.hallOfFame) } label: { row(tr("menu.hallOfFame"), "⌘Y") }
                    .buttonStyle(MenuRowButtonStyle())
                    .keyboardShortcut("y", modifiers: .command)

                if model.game.needsBranchChoice {
                    Button { model.showBranchChoice() } label: { row(tr("menu.chooseStone"), nil) }
                        .buttonStyle(MenuRowButtonStyle())
                }

                separator().padding(.vertical, 3)

                Button { model.go(.settings) } label: { row(tr("menu.settings"), "⌘,") }
                    .buttonStyle(MenuRowButtonStyle())
                    .keyboardShortcut(",", modifiers: .command)

                Button { model.rerunSetup() } label: { row(tr("menu.rerunSetup"), nil) }
                    .buttonStyle(MenuRowButtonStyle())

                #if STRETCHU_DEBUG
                Button { model.go(.debug) } label: { row(tr("menu.debug"), model.debugMode ? tr("menu.debug.on") : nil) }
                    .buttonStyle(MenuRowButtonStyle())
                #endif

                separator().padding(.vertical, 3)

                Button { model.go(.credits) } label: { row(tr("menu.credits"), nil) }
                    .buttonStyle(MenuRowButtonStyle())

                Button { NSApplication.shared.terminate(nil) } label: { row(tr("menu.quit"), "⌘Q") }
                    .buttonStyle(MenuRowButtonStyle())
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(6)
    }

    // MARK: blocks

    #if STRETCHU_DEBUG
    private var debugBadge: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.orange).frame(width: 8, height: 8)
            Text(tr("menu.debugBanner")).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Concentric with the panel corner: the menu pads its content by 6.
        .card(radius: Radius.panel - 6, opacity: 0.07)
    }
    #endif

    private func header(_ p: Progression) -> some View {
        HStack(spacing: 12) {
            SpriteBox(sprite: model.sprite, moment: .companion(model.mood))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.species.name).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    if model.game.candies > 0, p.level < Progression.maxLevel { candyButton }
                    Text(tr("menu.level", p.level)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                }
                ProgressBar(value: p.fractionToNextLevel)
                Text(xpLine(p)).panelCaption().monospacedDigit().minimumScaleFactor(0.8)
            }
        }
    }

    /// Only there when a Rare Candy is in stock: one click is +1 level.
    private var candyButton: some View {
        Button { model.useCandy() } label: {
            HStack(spacing: 3) {
                if let candy = SpriteLibrary.stoneImage("rare-candy") {
                    Image(decorative: candy, scale: 1).interpolation(.none).resizable().frame(width: 20, height: 20)
                }
                Text("×\(model.game.candies)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white.opacity(0.14)))
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
        .help(tr("menu.candy.help"))
    }

    private func xpLine(_ p: Progression) -> String {
        guard let next = p.nextLevelXP else { return "\(Format.xp(p.xp)) XP" }
        return tr("menu.xpLine", Format.xp(p.xp), Format.xp(next), p.level + 1, Format.xp(next - p.xp))
    }

    private func multiplierCard(_ streak: Streak) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tr("menu.multiplier")).panelCaption()
            Text(Format.multiplier(streak.multiplier))
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.accentColor).monospacedDigit()
            Spacer(minLength: 0)
            // Same footer line as the neighbouring card's bar: text and bar centered at the same height.
            Text(tr("menu.streakMax", streak.count))
                .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5)).monospacedDigit().lineLimit(1)
                .frame(height: 14, alignment: .center)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(radius: Radius.card)
    }

    private var nextBreakCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tr("menu.nextBreak")).panelCaption()
            Text(model.nextBreakValue)
                .font(.system(size: 24, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            ProgressBar(value: model.scheduler.workFraction, color: Color.white.opacity(0.7))
                .frame(height: 14, alignment: .center)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(radius: Radius.card)
    }

    @ViewBuilder
    private var wifiLines: some View {
        if let ssid = model.ssid {
            Text(tr("menu.wifi.line", ssid, model.mode == .home ? tr("menu.wifi.home") : tr("menu.wifi.office")))
                .panelCaption().minimumScaleFactor(0.85)
            if model.networkUnlinked {
                HStack(spacing: 8) {
                    Text(tr("menu.network.is")).panelCaption()
                    ForEach(PlaceMode.allCases, id: \.self) { mode in
                        Button(mode.name) { model.linkNetwork(to: mode) }.buttonStyle(.secondary).fixedSize()
                    }
                }
            }
        } else {
            switch model.wifiAuthorization {
            case .notRequested:
                HStack {
                    Text(tr("menu.wifi.notRead")).panelCaption()
                    Spacer()
                    Button(tr("menu.wifi.allow")) { model.requestWifiAuthorization() }.buttonStyle(.secondary).fixedSize()
                }
            case .denied:
                Text(tr("menu.wifi.denied")).panelCaption()
            case .granted:
                Text(tr("menu.wifi.none")).panelCaption()
            }
        }
    }

    private var meetingLine: some View {
        HStack(spacing: 8) {
            Circle().fill(model.inMeeting ? Color.orange : Color(red: 0.19, green: 0.82, blue: 0.35)).frame(width: 8, height: 8)
            Text(model.inMeeting
                 ? (model.scheduler.isWaiting ? tr("menu.meeting.waiting") : tr("menu.meeting.active"))
                 : tr("menu.meeting.none"))
                .font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.85)
        }
    }

    private func row(_ title: String, _ shortcut: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let shortcut { Text(shortcut).opacity(0.6) }
        }
    }

    private func separator() -> some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.horizontal, 8)
    }
}
