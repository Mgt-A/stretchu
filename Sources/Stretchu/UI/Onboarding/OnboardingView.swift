import SwiftUI

/// The setup, in a 340 × 620 window: six steps, a default everywhere, "Skip" always possible.
struct OnboardingView: View {
    let model: OnboardingModel

    var body: some View {
        if let draw = model.randomDraw {
            RandomDrawView(draw: draw) { model.acceptRandomDraw() }
                .frame(width: 340, height: 620)
                .foregroundStyle(.white)
        } else {
            steps
        }
    }

    private var steps: some View {
        VStack(spacing: 0) {
            StepDots(count: OnboardingModel.Step.allCases.count, current: model.stepIndex)
                .padding(.top, 34)
                .padding(.bottom, 14)

            Group {
                switch model.step {
                case .welcome: WelcomeStep(model: model)
                case .pokemon: PokemonStep(model: model)
                case .equipment: EquipmentStep(model: model)
                case .program: ProgramStep(model: model)
                case .access: AccessStep(model: model)
                case .ready: ReadyStep(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 18)

            footer
        }
        .frame(width: 340, height: 620)
        .foregroundStyle(.white)
        .id(model.language)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if model.isFirst {
                Button(tr("setup.skip")) { model.skip() }.buttonStyle(.text).fixedSize()
            } else {
                Button(tr("setup.back")) { model.back() }
                    .buttonStyle(.secondary).fixedSize()
                    .keyboardShortcut(.cancelAction)
            }
            Spacer(minLength: 0)
            if model.isLast {
                Button(model.mode == .firstLaunch ? tr("setup.start") : tr("setup.done")) { model.finish() }
                    .buttonStyle(.primary).fixedSize()
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(tr("setup.continue")) { model.next() }
                    .buttonStyle(.primary).fixedSize()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct StepTitle {
    let title: String
    var body: String?

    /// Title and short text.
    @ViewBuilder var bodyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 20, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
            if let body {
                Text(body).font(.system(size: 12.5)).foregroundStyle(Color.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: A1 · welcome and language

private struct WelcomeStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 14) {
            SpriteSheetView(sprite: SpriteRef(dex: 25, shiny: false), animation: "Idle", boxWidth: 96, boxHeight: 84, scale: 2)
                .padding(.top, 6)
            VStack(spacing: 6) {
                Text(tr("setup.welcome.title")).font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
                Text(tr("setup.welcome.body")).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("setup.language").uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.white.opacity(0.55))
                ForEach(L10n.availableLanguages.sorted { $0 == "en" ? true : ($1 == "en" ? false : $0 < $1) }, id: \.self) { code in
                    Button { model.setLanguage(code) } label: {
                        HStack {
                            Image(systemName: model.language == code ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(model.language == code ? Color.accentColor : Color.white.opacity(0.4))
                            Text(LanguageChoice.name(code)).font(.system(size: 13.5))
                            Spacer()
                            if code == model.systemLanguage {
                                Text(tr("setup.language.mac")).font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(model.language == code ? 0.12 : 0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.language == code ? Color.accentColor : .clear, lineWidth: 1.5))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                Text(tr("setup.language.note")).freeCaption()
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }
}

// MARK: A2 · Pokémon

private struct PokemonStep: View {
    let model: OnboardingModel

    var body: some View {
        let lines = LineCatalog.available.sorted { $0.base.dex < $1.base.dex }
        let selected = LineCatalog.line(id: model.lineId) ?? .pikachu
        let game = model.app.game

        VStack(alignment: .leading, spacing: 8) {
            StepTitle(title: tr("setup.pokemon.title"), body: tr("setup.pokemon.body")).bodyView

            HStack(spacing: 6) {
                tab(tr("setup.pokemon.gen1"), active: true)
                tab(tr("setup.pokemon.gen2"), active: false)
            }

            if model.pokemonLocked {
                Text(tr("setup.pokemon.locked", game.species.name, game.progression.level))
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.18)))
            }

            PokemonGrid(lines: lines, selection: model.pokemonLocked ? game.pokemon.lineId : model.lineId,
                        caption: { "#\(String(format: "%03d", $0.base.dex))" },
                        disabled: model.pokemonLocked,
                        onRandom: model.pokemonLocked ? nil : { model.startRandomDraw() },
                        onSelect: { model.lineId = $0 })

            Text(tr("setup.pokemon.evolutions").uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.white.opacity(0.55))
            EvolutionStrip(line: model.pokemonLocked ? game.line : selected,
                           branchDex: model.pokemonLocked ? game.pokemon.branchDex : nil,
                           obtained: Pokedex.obtainedDexes(game.progression.cycles))
        }
    }

    private func tab(_ title: String, active: Bool) -> some View {
        Text(title).font(.system(size: 12, weight: active ? .semibold : .regular))
            .foregroundStyle(Color.white.opacity(active ? 1 : 0.4))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(active ? 0.16 : 0.05)))
    }
}

// MARK: A3 · equipment

private struct EquipmentStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle(title: tr("setup.equipment.title"), body: tr("setup.equipment.note")).bodyView
            ModePicker(mode: model.equipmentPlace) { model.equipmentPlace = $0 }
            EquipmentGridView(owned: Binding(get: { model.ownedAtCurrentPlace }, set: { model.setEquipment($0) }))
                .id(model.equipmentPlace)
            Spacer(minLength: 0)
        }
    }
}

// MARK: A4 · program and rhythm

private struct ProgramStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepTitle(title: tr("setup.program.title"), body: tr("setup.program.body")).bodyView
            ProgramChoiceView(general: model.generalProgram, custom: model.customProgram, selectedId: model.programId,
                              owned: model.allEquipment, message: model.programMessage,
                              onSelect: { model.selectProgram($0) },
                              onChooseFile: { if let url = ProgramFilePicker.choose() { model.importProgram(from: url) } })
            PageSection(title: tr("setup.rhythm")) {
                StepRow(title: tr("setup.rhythm.work"), value: "\(model.workMinutes) min",
                        canDecrease: model.workMinutes > UserSettings.workRange.lowerBound,
                        canIncrease: model.workMinutes < UserSettings.workRange.upperBound,
                        decrease: { model.workMinutes = max(UserSettings.workRange.lowerBound, model.workMinutes - 1) },
                        increase: { model.workMinutes = min(UserSettings.workRange.upperBound, model.workMinutes + 1) })
                StepRow(title: tr("setup.rhythm.exercise"), value: "\(model.step2Seconds) s",
                        canDecrease: model.step2Seconds > UserSettings.step2Range.lowerBound,
                        canIncrease: model.step2Seconds < UserSettings.step2Range.upperBound,
                        decrease: { model.step2Seconds = max(UserSettings.step2Range.lowerBound, model.step2Seconds - 5) },
                        increase: { model.step2Seconds = min(UserSettings.step2Range.upperBound, model.step2Seconds + 5) })
            }
            PageSection(title: tr("schedule.title")) {
                ScheduleEditor(schedule: model.schedule) { model.schedule = $0 }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: A5 · access

private struct AccessStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StepTitle(title: tr("setup.access.title"), body: tr("setup.access.note")).bodyView
            card(icon: "mic.slash", title: tr("access.micro.title"), badge: tr("access.micro.badge"), text: tr("access.micro.desc"))
            card(icon: "location", title: tr("access.location.title"), text: tr("access.location.desc")) {
                locationControl
            }
            card(icon: "power", title: tr("access.login.title"), text: tr("access.login.desc")) {
                Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .labelsHidden().toggleStyle(.switch)
            }
            card(icon: "wifi.slash", title: tr("access.internet.title"), badge: tr("access.internet.badge"), text: tr("access.internet.desc"))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var locationControl: some View {
        switch model.app.wifiAuthorization {
        case .notRequested:
            Button(tr("access.location.allow")) { model.app.requestWifiAuthorization() }.buttonStyle(.secondary).fixedSize()
        case .granted:
            Text(tr("access.location.granted")).font(.system(size: 12)).foregroundStyle(Color.green)
        case .denied:
            Text(tr("access.location.denied")).font(.system(size: 12)).foregroundStyle(Color.orange)
        }
    }

    private func card<Control: View>(icon: String, title: String, badge: String? = nil, text: String,
                                     @ViewBuilder control: () -> Control = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 18)
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Spacer(minLength: 4)
                if let badge { Text(badge).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.6)) }
                control()
            }
            Text(text).font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 26)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }
}

// MARK: A6 · ready

private struct ReadyStep: View {
    let model: OnboardingModel

    var body: some View {
        let line = LineCatalog.line(id: model.pokemonLocked ? model.app.game.pokemon.lineId : model.lineId) ?? .pikachu
        let shiny = model.pokemonLocked ? model.app.game.pokemon.shiny : model.shiny
        let name = (model.pokemonLocked ? model.app.game.species : line.base).name + (shiny ? " ✦ shiny" : "")
        let sprite = SpriteRef(dex: model.pokemonLocked ? model.app.game.species.dex : line.base.dex, shiny: shiny)

        VStack(spacing: 12) {
            // The victory pose when the species has one (Idle otherwise), at the welcome screen's size.
            SpriteSheetView(sprite: sprite, animation: "Pose", boxWidth: 96, boxHeight: 84, scale: 2).padding(.top, 6)
            Text(tr("setup.ready.title")).font(.system(size: 22, weight: .bold))

            VStack(spacing: 0) {
                row(tr("setup.ready.language"), LanguageChoice.name(model.language), .welcome)
                row(tr("setup.ready.pokemon"), name, .pokemon)
                row(PlaceMode.home.name, equipmentSummary(model.homeEquipment), .equipment)
                row(PlaceMode.office.name, equipmentSummary(model.officeEquipment), .equipment)
                row(tr("setup.ready.program"), programName, .program)
                row(tr("setup.ready.rhythm", model.workMinutes), "", .program)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

            Text(tr("setup.ready.health")).freeCaption().fixedSize(horizontal: false, vertical: true)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            Spacer(minLength: 0)
        }
    }

    private var programName: String {
        if model.programId == ProgramLibrary.generalId { return tr("program.general.name") }
        return model.programs.first { $0.id == model.programId }?.program.name ?? tr("program.custom.name")
    }

    private func equipmentSummary(_ set: Set<String>) -> String {
        let names = Equipment.ownable.filter(set.contains).map(Equipment.gridLabel)
        return names.isEmpty ? tr("setup.ready.bodyweight") : names.joined(separator: ", ")
    }

    private func row(_ title: String, _ value: String, _ step: OnboardingModel.Step) -> some View {
        Button { model.go(to: step) } label: {
            HStack {
                Text(title).font(.system(size: 12.5)).foregroundStyle(Color.white.opacity(0.65))
                Spacer(minLength: 8)
                Text(value).font(.system(size: 12.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
