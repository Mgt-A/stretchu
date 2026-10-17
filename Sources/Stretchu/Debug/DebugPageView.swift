#if STRETCHU_DEBUG
import SwiftUI

/// Debug page of the menu panel: a toggle turns it on, the rest is set with the same − / +
/// as the settings. Everything happens on a copy of the state (state.debug.json).
struct DebugPageView: View {
    let model: AppModel
    @State private var previewDex: Int?
    @State private var previewAnimation = "Idle"

    var body: some View {
        let progression = model.game.progression
        let streak = model.game.streak
        let active = model.debugMode

        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: tr("debug.title"), back: { model.back() })

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tr("debug.mode")).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Toggle("", isOn: Binding(get: { model.debugMode }, set: { model.setDebugMode($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                Text(active ? tr("debug.note.on") : tr("debug.note.off"))
                    .freeCaption().fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .card(radius: 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    PageSection(title: tr("debug.state")) {
                        StepRow(title: tr("debug.level", model.species.name), value: "\(progression.level)",
                                canDecrease: progression.level > 1, canIncrease: progression.level < 100,
                                decrease: { model.execute(.level(progression.level - 1)) },
                                increase: { model.execute(.level(progression.level + 1)) })
                        StepRow(title: "XP", value: Format.xp(progression.xp),
                                canDecrease: progression.xp > 0, canIncrease: progression.xp < 999_999,
                                decrease: { model.execute(.xp(progression.xp - 1_000)) },
                                increase: { model.execute(.xp(progression.xp + 1_000)) })
                        let upcoming = model.game.line.chain(branchDex: model.game.pokemon.branchDex).first { $0.level > progression.level }
                        let target = upcoming?.level ?? Progression.maxLevel
                        Button(tr("debug.xpJustBefore", Format.xp(Progression.totalXP(forLevel: target) - 1), upcoming?.name ?? tr("debug.hallOfFame"))) {
                            model.execute(.xp(Progression.totalXP(forLevel: target) - 1))
                        }.buttonStyle(.secondary)
                        StepRow(title: tr("debug.streak", Format.multiplier(streak.multiplier)), value: "\(streak.count)",
                                canDecrease: streak.count > 0, canIncrease: streak.count < 60,
                                decrease: { model.execute(.streak(streak.count - 1)) },
                                increase: { model.execute(.streak(streak.count + 1)) })
                        StepRow(title: tr("debug.breaksToday", model.mood.animationName),
                                value: "\(streak.breaksToday)",
                                canDecrease: streak.breaksToday > 0, canIncrease: streak.breaksToday < 10,
                                decrease: { model.execute(.breaksToday(streak.breaksToday - 1)) },
                                increase: { model.execute(.breaksToday(streak.breaksToday + 1)) })
                        Text(tr("debug.pokedex", Pokedex.completion(cycles: progression.cycles).obtained, Pokedex.completion(cycles: progression.cycles).total)).freeCaption()
                        StepRow(title: tr("debug.cycles"), value: "\(progression.completedCycles)",
                                canDecrease: progression.completedCycles > 0, canIncrease: progression.completedCycles < 99,
                                decrease: { model.execute(.cycles(progression.completedCycles - 1)) },
                                increase: { model.execute(.cycles(progression.completedCycles + 1)) })
                    }

                    PageSection(title: tr("debug.triggers")) {
                        Text(tr("debug.phase", phase, Format.countdown(model.scheduler.remaining))).freeCaption().monospacedDigit()
                        pair(tr("debug.wakeUp"), { model.execute(.wakeUp) }, tr("debug.skip"), { model.execute(.skip) })
                        pair(tr("debug.completeNow"), { model.execute(.complete) }, tr("debug.levelUp"), { model.execute(.levelUp) })
                        Text(tr("debug.meeting", model.inMeeting ? tr("debug.meeting.ongoing") : tr("debug.meeting.none"),
                                model.fakeMeeting ? tr("debug.meeting.fake") : ""))
                            .freeCaption()
                        pair(tr("debug.fakeMeetingStart"), { model.execute(.meetingStart) }, tr("debug.fakeMeetingEnd"), { model.execute(.meetingEnd) })
                    }

                    PageSection(title: tr("debug.time")) {
                        Text(model.clock.isSimulated
                             ? model.clock.now.formatted(.dateTime.weekday().day().month().hour().minute().locale(L10n.locale))
                             : tr("debug.realTime")).freeCaption()
                        Button(tr("debug.advance25")) { model.execute(.advance25Minutes) }.buttonStyle(.secondary)
                        pair(tr("debug.nextWorkday"), { model.execute(.nextWorkday) }, tr("debug.weekend"), { model.execute(.weekend) })
                        Button(tr("debug.backToRealTime")) { model.execute(.realTime) }.buttonStyle(.secondary)
                    }

                    PageSection(title: tr("debug.animations")) {
                        Segments(values: model.game.line.allSpecies.map(\.dex), selection: previewDex ?? model.species.dex,
                                 label: { dex in model.game.line.allSpecies.first { $0.dex == dex }?.name ?? "\(dex)" }) { previewDex = $0 }
                        HStack(alignment: .top, spacing: 12) {
                            SpriteBox(sprite: previewRef, moment: Moment.preview(previewAnimation), width: 100, height: 120, radius: 14, scale: 2)
                            VStack(spacing: 6) {
                                ForEach(["Idle", "Eat", "LookUp", "DeepBreath", "Hop", "Sleep"], id: \.self) { name in
                                    Button(name) { previewAnimation = name }
                                        .buttonStyle(.secondary)
                                        .opacity(previewAnimation == name ? 1 : 0.7)
                                }
                            }
                        }
                        let sheet = SpriteLibrary.sheet(previewRef, animation: previewAnimation)
                        Text(sheet.map { tr("debug.sheetInfo", "\(previewRef.dex)", $0.name, $0.info.frameCount) }
                             ?? tr("debug.noSheet")).freeCaption()
                    }

                    PageSection(title: tr("debug.pokemon")) {
                        let lines = LineCatalog.available
                        let index = lines.firstIndex { $0.id == model.game.line.id } ?? 0
                        StepRow(title: model.game.line.base.name, value: "\(index + 1) / \(lines.count)",
                                canDecrease: index > 0, canIncrease: index < lines.count - 1,
                                decrease: { model.execute(.line(lines[index - 1].id)) },
                                increase: { model.execute(.line(lines[index + 1].id)) })
                        Toggle(tr("debug.shiny"), isOn: Binding(get: { model.game.pokemon.shiny },
                                                                set: { model.execute(.shiny($0)) }))
                            .disabled(!LineCatalog.hasShiny(model.game.line))
                        if let branch = model.game.line.branch {
                            HStack(spacing: 8) {
                                ForEach(branch.options, id: \.dex) { option in
                                    Button(option.stoneName) { model.execute(.branch(option.dex)) }
                                        .buttonStyle(.secondary)
                                        .opacity(model.game.pokemon.branchDex == option.dex ? 1 : 0.7)
                                }
                            }
                        }
                    }

                    PageSection(title: tr("debug.exercisesWifi")) {
                        ModePicker(mode: model.mode) { model.execute(.mode($0)) }
                        Text(tr("debug.exercise", model.exercise.name)).freeCaption().lineLimit(1)
                        Text(tr("debug.network", model.ssid ?? tr("debug.network.none"))).freeCaption()
                        HStack(spacing: 8) {
                            Button("Home-5G") { model.execute(.ssid("Home-5G")) }.buttonStyle(.secondary)
                            Button("Office-Corp") { model.execute(.ssid("Office-Corp")) }.buttonStyle(.secondary)
                            Button(tr("debug.network.noneButton")) { model.execute(.ssid(nil)) }.buttonStyle(.secondary)
                        }
                    }

                    PageSection(title: tr("debug.setup")) {
                        Button(tr("debug.replaySetup")) { model.execute(.replaySetup) }.buttonStyle(.secondary)
                    }

                    PageSection(title: tr("debug.fixtures")) {
                        ForEach(Fixtures.all, id: \.name) { fixture in
                            Button(fixture.description) { model.execute(.fixture(fixture.name)) }.buttonStyle(.secondary)
                        }
                        Button(tr("debug.reset")) { model.execute(.reset) }.buttonStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
            }
            .disabled(!active)
            .opacity(active ? 1 : 0.4)
            .frame(maxHeight: 470)
        }
        .padding(14)
    }

    private var previewRef: SpriteRef {
        SpriteRef(dex: previewDex ?? model.species.dex, shiny: model.game.pokemon.shiny)
    }

    private var phase: String {
        switch model.phase {
        case .work: model.scheduler.isDeferred ? tr("debug.phase.workDeferred") : model.scheduler.isIdle ? tr("debug.phase.workSuspended") : tr("debug.phase.work")
        case .wakeUp: tr("debug.phase.wakeUp")
        case .step1: tr("debug.phase.step1")
        case .step2: tr("debug.phase.step2")
        }
    }

    private func pair(_ a: String, _ actionA: @escaping () -> Void, _ b: String, _ actionB: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(a, action: actionA).buttonStyle(.secondary)
            Button(b, action: actionB).buttonStyle(.secondary)
        }
    }
}

extension Moment {
    /// Named animation of the Debug panel (preview).
    static func preview(_ name: String) -> Moment {
        switch name {
        case "Eat": .wakeUp
        case "LookUp": .break1
        case "DeepBreath": .break2
        case "Hop": .levelUp
        case "Sleep": .companion(.sleep)
        default: .menu
        }
    }
}
#endif
