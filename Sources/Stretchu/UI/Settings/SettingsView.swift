import SwiftUI

/// Settings page of the menu panel: durations, default mode, Wi-Fi networks,
/// hidden exercises, launch at login. No free text input: networks are
/// picked when the app sees them.
struct SettingsView: View {
    let model: AppModel
    @State private var launch = LaunchAtLogin.status
    @State private var launchError: String?
    @State private var equipmentPlace: PlaceMode = .home
    @State private var programMessage: String?

    var body: some View {
        let settings = model.game.settings
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: tr("settings.title"), back: { model.back() })

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {

                PageSection(title: tr("settings.durations")) {
                    row(tr("settings.work"), value: settings.workMinutes, unit: "min", range: UserSettings.workRange, step: 1) { $0.workMinutes = $1 }
                    row(tr("settings.step1"), value: settings.step1Seconds, unit: "s", range: UserSettings.step1Range, step: 5) { $0.step1Seconds = $1 }
                    row(tr("settings.step2"), value: settings.step2Seconds, unit: "s", range: UserSettings.step2Range, step: 5) { $0.step2Seconds = $1 }
                    row(tr("settings.snooze"), value: settings.snoozeMinutes, unit: "min", range: UserSettings.snoozeRange, step: 1) { $0.snoozeMinutes = $1 }
                    if settings != UserSettings(defaultMode: settings.defaultMode) {
                        Button(tr("settings.defaults")) {
                            model.updateSettings { $0 = UserSettings(defaultMode: $0.defaultMode) }
                        }
                        .buttonStyle(.text)
                    }
                }

                PageSection(title: tr("schedule.title")) {
                    ScheduleEditor(schedule: settings.schedule) { new in model.updateSettings { $0.schedule = new } }
                }

                PageSection(title: tr("settings.language")) {
                    Segments(values: [String?.none] + L10n.availableLanguages.sorted().map { Optional($0) }, selection: model.game.language,
                             label: { $0.map(LanguageChoice.name) ?? tr("settings.language.auto") },
                             onSelect: { model.setLanguage($0) })
                }

                PageSection(title: tr("settings.equipment")) {
                    ModePicker(mode: equipmentPlace) { equipmentPlace = $0 }
                    EquipmentGridView(owned: Binding(
                        get: { model.game.settings.equipment(for: equipmentPlace) },
                        set: { model.setEquipment(Array($0), for: equipmentPlace) }))
                        .id(equipmentPlace)
                }

                PageSection(title: tr("settings.program")) {
                    let programs = model.availablePrograms
                    let own = programs.filter { !$0.isBundled }
                    ProgramChoiceView(
                        general: programs.first { $0.isBundled },
                        custom: own.first { $0.id == model.game.programId } ?? own.first,
                        selectedId: model.game.programId,
                        owned: model.game.settings.equipment(for: .home).union(model.game.settings.equipment(for: .office)),
                        message: programMessage,
                        onSelect: { model.selectProgram(id: $0) },
                        onChooseFile: {
                            guard let url = ProgramFilePicker.choose() else { return }
                            do { try model.importProgram(from: url); programMessage = nil }
                            catch { programMessage = ProgramFilePicker.message(for: error) }
                        })
                }

                PageSection(title: tr("settings.defaultMode")) {
                    ModePicker(mode: settings.defaultMode) { choice in
                        model.updateSettings { $0.defaultMode = choice }
                    }
                    Text(tr("settings.defaultMode.note")).freeCaption()
                }

                PageSection(title: tr("settings.networks")) {
                    if model.game.networks.isEmpty {
                        Text(tr("settings.networks.none")).freeCaption()
                    }
                    ForEach(model.game.networks.keys.sorted(), id: \.self) { ssid in
                        HStack(spacing: 8) {
                            Text(ssid).font(.system(size: 13)).lineLimit(1)
                            Spacer(minLength: 4)
                            ModePicker(mode: model.game.networks[ssid] ?? .home, width: 130) { model.setNetwork(ssid, $0) }
                            Button { model.removeNetwork(ssid) } label: {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                                    .frame(width: 24, height: 24).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(tr("settings.networks.remove"))
                        }
                    }
                    if let ssid = model.ssid, model.game.networks[ssid] == nil {
                        HStack(spacing: 8) {
                            Text(tr("settings.networks.quoted", ssid)).font(.system(size: 13)).lineLimit(1)
                            Spacer(minLength: 4)
                            ModePicker(mode: model.mode, width: 130) { model.linkNetwork(to: $0) }
                        }
                        Text(tr("settings.networks.current")).freeCaption()
                    } else {
                        Text(tr("settings.networks.hint")).freeCaption()
                    }
                }

                PageSection(title: tr("settings.excluded")) {
                    let excluded = ExerciseCatalog.catalog.filter { model.game.excludedExercises.contains($0.id) }
                    if excluded.isEmpty {
                        Text(tr("settings.excluded.none")).freeCaption()
                    }
                    ForEach(excluded) { exercise in
                        HStack {
                            Text(exercise.name).font(.system(size: 13)).lineLimit(1)
                            Spacer(minLength: 4)
                            Button(tr("settings.excluded.restore")) { model.restoreExercise(exercise.id) }.buttonStyle(.secondary).fixedSize()
                        }
                    }
                }

                PageSection(title: tr("settings.startup")) {
                    Toggle(isOn: Binding(
                        get: { launch == .enabled || launch == .requiresApproval },
                        set: { enabled in
                            do {
                                try LaunchAtLogin.set(enabled)
                                launchError = nil
                            } catch {
                                launchError = tr("settings.launch.error", error.localizedDescription)
                            }
                            launch = LaunchAtLogin.status
                        })
                    ) {
                        Text(tr("settings.launchAtLogin")).font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .disabled(launch == .unavailable)
                    switch launch {
                    case .requiresApproval:
                        Text(tr("settings.launch.approve")).freeCaption()
                    case .unavailable:
                        Text(tr("settings.launch.unavailable")).freeCaption()
                    default:
                        EmptyView()
                    }
                    if let launchError { Text(launchError).font(.system(size: 11.5)).foregroundStyle(.red) }
                }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(14)
        .frame(height: PanelSize.tall.height)
        .onAppear { launch = LaunchAtLogin.status }
    }

    private func row(_ title: String, value: Int, unit: String, range: ClosedRange<Int>, step: Int,
                     apply: @escaping (inout UserSettings, Int) -> Void) -> some View {
        StepRow(title: title, value: "\(value) \(unit)",
                canDecrease: value > range.lowerBound, canIncrease: value < range.upperBound,
                decrease: { model.updateSettings { apply(&$0, max(range.lowerBound, value - step)) } },
                increase: { model.updateSettings { apply(&$0, min(range.upperBound, value + step)) } })
    }
}
