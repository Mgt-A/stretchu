import SwiftUI

/// Settings page of the menu panel: durations, hidden exercises, launch at login.
struct SettingsView: View {
    let model: AppModel
    @State private var launch = LaunchAtLogin.status
    @State private var launchError: String?
    @State private var dataMessage: String?
    @State private var dataFailed = false

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
                    if settings != UserSettings() {
                        Button(tr("settings.defaults")) {
                            model.updateSettings { $0 = UserSettings() }
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

                PageSection(title: tr("settings.data")) {
                    HStack(spacing: 8) {
                        Button(tr("settings.data.export")) { exportState() }.buttonStyle(.secondary).fixedSize()
                        Button(tr("settings.data.import")) { importState() }.buttonStyle(.secondary).fixedSize()
                    }
                    Text(tr("settings.data.note")).freeCaption()
                    if let dataMessage {
                        Text(dataMessage).font(.system(size: 11.5)).foregroundStyle(dataFailed ? Color.red : Color.secondary)
                    }
                }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(14)
        .frame(height: PanelSize.tall.height)
        .onAppear { launch = LaunchAtLogin.status }
    }

    private func exportState() {
        guard let url = StateFilePicker.chooseExportURL() else { return }
        do { try model.exportState(to: url); report(tr("settings.data.exported"), failed: false) }
        catch { report(tr("data.error.write"), failed: true) }
    }

    private func importState() {
        guard let url = StateFilePicker.chooseImportURL() else { return }
        do {
            let imported = try StateTransfer.read(from: url)
            guard StateFilePicker.confirmReplace(with: imported) else { return }
            model.importState(imported)
            report(tr("settings.data.imported"), failed: false)
        } catch {
            report(StateFilePicker.message(for: error), failed: true)
        }
    }

    private func report(_ text: String, failed: Bool) {
        dataMessage = text
        dataFailed = failed
    }

    private func row(_ title: String, value: Int, unit: String, range: ClosedRange<Int>, step: Int,
                     apply: @escaping (inout UserSettings, Int) -> Void) -> some View {
        StepRow(title: title, value: "\(value) \(unit)",
                canDecrease: value > range.lowerBound, canIncrease: value < range.upperBound,
                decrease: { model.updateSettings { apply(&$0, max(range.lowerBound, value - step)) } },
                increase: { model.updateSettings { apply(&$0, min(range.upperBound, value + step)) } })
    }
}
