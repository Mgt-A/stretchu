import SwiftUI

/// The choice of the next Pokémon: a cycle ended (the Hall of Fame header shows), or the player
/// gave up the cycle. A grid of every available line, finished ones first.
struct CycleChoiceView: View {
    let model: AppModel
    @State private var selection: String
    @State private var draw: RandomPick.Draw?

    init(model: AppModel) {
        self.model = model
        _selection = State(initialValue: model.game.pokemon.lineId)
    }

    var body: some View {
        if let draw {
            RandomDrawView(draw: draw) { model.chooseNextPokemon(lineId: draw.lineId, shiny: draw.shiny) }
                .frame(width: PanelSize.width, height: PanelSize.tall.height)
        } else {
            choiceGrid
        }
    }

    @ViewBuilder private var choiceGrid: some View {
        let choice = model.cycleChoice
        let progression = model.game.progression
        let counts = Pokedex.completedCounts(progression.cycles)
        let lines = HallOfFame.choiceOrder(LineCatalog.available, completedCounts: counts)
        let pokedex = Pokedex.completion(cycles: progression.cycles)

        VStack(alignment: .center, spacing: 10) {
            header(choice)

            PokemonGrid(
                lines: lines, selection: selection,
                caption: { line in
                    let n = counts[line.id, default: 0]
                    return n == 0 ? tr("cycle.new") : (n == 1 ? tr("cycle.done") : tr("cycle.done.count", n))
                },
                captionColor: { counts[$0.id, default: 0] == 0 ? Color.accentColor : Color.white.opacity(0.55) },
                checkmark: { counts[$0.id, default: 0] > 0 },
                onRandom: {
                    draw = RandomPick.draw(lines: LineCatalog.available, obtained: Pokedex.obtainedDexes(progression.cycles),
                                           afterAbandon: progression.current.afterAbandon)
                },
                onSelect: { selection = $0 })

            VStack(spacing: 4) {
                HStack {
                    Text(tr("hof.pokedex")).panelCaption()
                    Spacer()
                    Text("\(pokedex.obtained) / \(pokedex.total)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                }
                ProgressBar(value: pokedex.total == 0 ? 0 : Double(pokedex.obtained) / Double(pokedex.total))
            }

            HStack(spacing: 8) {
                if choice?.kind == .finished {
                    Button(tr("cycle.seeHallOfFame")) { model.openMenu(page: .hallOfFame) }.buttonStyle(.secondary).fixedSize()
                }
                Button(tr("cycle.hatch")) { model.chooseNextPokemon(lineId: selection) }.buttonStyle(.primary)
            }
        }
        .padding(14)
        .frame(width: PanelSize.width, height: PanelSize.tall.height, alignment: .top)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func header(_ choice: AppModel.CycleChoice?) -> some View {
        VStack(spacing: 6) {
            if choice?.kind == .finished, let species = choice?.finishedSpecies {
                SpeciesSprite(dex: species.dex, shiny: model.game.progression.completedCycleList.last?.shiny ?? false,
                              boxWidth: 64, boxHeight: 56)
                Text(tr("cycle.finished.title", species.name)).font(.system(size: 17, weight: .semibold))
                Text(choice?.days.map { tr("cycle.finished.body", $0) } ?? tr("cycle.finished.bodyNoDays"))
                    .freeCaption().multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(tr("cycle.abandoned.title")).font(.system(size: 17, weight: .semibold)).padding(.top, 8)
                Text(tr("cycle.abandoned.body"))
                    .freeCaption().multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Eevee reached level 50: the player picks a stone, which decides the evolution.
struct BranchChoiceView: View {
    let model: AppModel
    @State private var selection: Int?

    var body: some View {
        let line = model.game.line
        let options = line.branch?.options ?? []
        let obtained = Pokedex.obtainedDexes(model.game.progression.cycles)
        let chosen = options.first { $0.dex == (selection ?? options.first?.dex) }

        VStack(spacing: 12) {
            SpeciesSprite(dex: line.base.dex, shiny: model.game.pokemon.shiny, boxWidth: 80, boxHeight: 64)
            Text(tr("branch.title", line.base.name)).font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.center)
            Text(tr("branch.body")).freeCaption().multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(options, id: \.dex) { option in
                    let isSelected = option.dex == chosen?.dex
                    Button { selection = option.dex } label: {
                        VStack(spacing: 4) {
                            if let stone = SpriteLibrary.stoneImage(option.stone) {
                                Image(decorative: stone, scale: 1).interpolation(.none).resizable().frame(width: 40, height: 40)
                            }
                            Text(option.stoneName).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                            Text("#\(String(format: "%03d", option.dex))").font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.45))
                            SpeciesSprite(dex: option.dex, silhouette: !obtained.contains(option.dex), boxWidth: 48, boxHeight: 44, fill: true)
                                .frame(width: 56, height: 48)
                            Text(option.names.isEmpty ? option.slug : localizedName(option.names)).font(.system(size: 12)).lineLimit(1)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white.opacity(isSelected ? 0.14 : 0.06)))
                        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5))
                        .contentShape(RoundedRectangle(cornerRadius: Radius.card))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(tr("branch.note", line.base.name)).freeCaption().multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(tr("branch.later")) { model.postponeBranchChoice() }.buttonStyle(.secondary).fixedSize()
                Button(tr("branch.use", chosen?.stoneName ?? "")) {
                    if let dex = chosen?.dex { model.chooseBranch(dex: dex) }
                }
                .buttonStyle(.primary)
            }
        }
        .padding(14)
        .frame(width: PanelSize.width, height: PanelSize.tall.height, alignment: .top)
        .foregroundStyle(.white)
    }
}

/// Confirmation to give up the current cycle; replaces the Hall of Fame page in the panel.
struct AbandonView: View {
    let model: AppModel

    var body: some View {
        let species = model.species
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: tr("abandon.header"), back: { model.go(.hallOfFame) })

            HStack(spacing: 12) {
                SpriteBox(sprite: model.sprite, moment: .menu)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("abandon.title", species.name)).font(.system(size: 15, weight: .semibold))
                    Text(tr("menu.level", model.game.progression.level)).panelCaption()
                }
            }
            Text(tr("abandon.body")).font(.system(size: 13)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(tr("abandon.keep", species.name)) { model.go(.hallOfFame) }.buttonStyle(.secondary)
                Button(tr("abandon.confirm")) { model.abandonCycle() }.buttonStyle(.destructive)
            }
        }
        .padding(14)
    }
}
