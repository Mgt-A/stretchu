import AppKit
import SwiftUI

/// Still picture of a species: the first frame of its Idle animation, at an integer scale that
/// fits the box, without smoothing. A silhouette stands for a species not obtained yet; a species
/// whose sprite wasn't downloaded shows a dashed outline.
struct SpeciesSprite: View {
    let dex: Int
    var shiny = false
    var silhouette = false
    var boxWidth: CGFloat = 56
    var boxHeight: CGFloat = 48
    /// Grids: every sprite is scaled to fill the same box, so a Mew and a Moltres look equally big.
    var fill = false
    /// Paints the sprite in one flat color (the draw's silhouettes, black then white).
    var flatColor: Color? = nil
    /// The integer scale asked for when not filling.
    var scale = 2

    var body: some View {
        Group {
            if let frame = SpriteLibrary.idleFrame(SpriteRef(dex: dex, shiny: shiny)) {
                let place = SpriteLayout.place(spriteWidth: frame.width, spriteHeight: frame.height,
                                               boxWidth: Int(boxWidth), boxHeight: Int(boxHeight), requested: fill ? nil : scale)
                Color.clear
                    .frame(width: boxWidth, height: boxHeight)
                    .overlay(alignment: .topLeading) {
                        Image(decorative: frame, scale: 1)
                            .renderingMode(flatColor == nil ? .original : .template)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: CGFloat(place.width), height: CGFloat(place.height))
                            .foregroundStyle(flatColor ?? .primary)
                            .brightness(silhouette ? -1 : 0)
                            .opacity(silhouette ? 0.45 : 1)
                            .padding(.leading, CGFloat(place.x))
                            .padding(.top, CGFloat(place.y))
                    }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: boxWidth * 0.6, height: boxHeight * 0.7)
            }
        }
        .frame(width: boxWidth, height: boxHeight)
    }
}

/// Tabler icon of an equipment (Resources/Icons/*.pdf), tinted like text.
struct EquipmentIcon: View {
    let equipment: String
    var size: CGFloat = 22

    var body: some View {
        if let url = AppResources.url("Icons/\(Equipment.iconName(equipment)).pdf"), let image = NSImage(contentsOf: url) {
            Image(nsImage: image).renderingMode(.template).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}

/// A cell of a Pokémon grid: sprite, name and a small caption, with an accent outline when selected.
struct PokemonTile: View {
    let dex: Int
    let name: String
    let caption: String
    var captionColor = Color.white.opacity(0.45)
    var shiny = false
    var selected = false
    var silhouette = false
    var checkmark = false
    var dimmed = false

    var body: some View {
        VStack(spacing: 2) {
            SpeciesSprite(dex: dex, shiny: shiny, silhouette: silhouette, boxWidth: 48, boxHeight: 44, fill: true)
                .frame(width: 64, height: 48)
            Text(name).font(.system(size: 12, weight: selected ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
            Text(caption).font(.system(size: 10.5)).foregroundStyle(captionColor).lineLimit(1).monospacedDigit()
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(selected ? 0.14 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
        .overlay(alignment: .topTrailing) {
            if checkmark {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.accentColor).padding(6)
            }
        }
        .opacity(dimmed ? 0.4 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Scrollable grid of the available lines, three columns. Used by the setup and by the choice of
/// the next Pokémon.
struct PokemonGrid: View {
    let lines: [PokemonLine]
    let selection: String
    var shiny: (String) -> Bool = { _ in false }
    var caption: (PokemonLine) -> String
    var captionColor: (PokemonLine) -> Color = { _ in Color.white.opacity(0.45) }
    var checkmark: (PokemonLine) -> Bool = { _ in false }
    var disabled = false
    /// The "Random" cell at the head of the grid; nil hides it.
    var onRandom: (() -> Void)? = nil
    let onSelect: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
          ScrollView(showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                if let onRandom {
                    Button(action: onRandom) { RandomTile() }
                        .buttonStyle(.plain)
                        .disabled(disabled)
                }
                ForEach(lines) { line in
                    Button { onSelect(line.id) } label: {
                        PokemonTile(dex: line.base.dex, name: line.base.name, caption: caption(line),
                                    captionColor: captionColor(line), shiny: false,
                                    selected: selection == line.id, checkmark: checkmark(line))
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    .id(line.id)
                }
            }
            .padding(2)
          }
          // The selected line is in view when the grid appears, unless the "Random" cell heads it.
          .onAppear { if onRandom == nil { proxy.scrollTo(selection, anchor: .center) } }
        }
        .opacity(disabled ? 0.45 : 1)
    }
}

/// The evolutions of a line, one to four boxes centered, each with its level.
struct EvolutionStrip: View {
    let line: PokemonLine
    var branchDex: Int? = nil
    var obtained: Set<Int> = []
    var showAll = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(line.chain(branchDex: branchDex), id: \.dex) { species in cell(species, silhouette: false) }
            if let branch = line.branch, branchDex == nil, showAll {
                ForEach(branch.options, id: \.dex) { option in
                    cell(option.species(level: branch.level), silhouette: !obtained.contains(option.dex))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cell(_ species: Species, silhouette: Bool) -> some View {
        VStack(spacing: 2) {
            SpeciesSprite(dex: species.dex, silhouette: silhouette, boxWidth: 44, boxHeight: 40, fill: true)
                .frame(width: 52, height: 44)
            Text(species.name).font(.system(size: 11.5)).lineLimit(1).minimumScaleFactor(0.7)
            Text(tr("setup.pokemon.level", species.level)).font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.vertical, 6).padding(.horizontal, 4)
        .frame(width: 70)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }
}

/// "n of 6" bars at the top of the setup.
struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == current ? Color.accentColor : Color.white.opacity(index < current ? 0.5 : 0.2))
                    .frame(width: index == current ? 18 : 10, height: 4)
            }
        }
    }
}
