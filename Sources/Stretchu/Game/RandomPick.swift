import Foundation

/// The "Random" choice of a Pokémon: which line comes out, whether it is shiny, and the
/// silhouettes that scroll before it. Pure logic, the random source is injectable.
enum RandomPick {
    struct Draw: Equatable {
        let lineId: String
        let shiny: Bool
        /// The lines shown one after the other before the result: never twice the same in a row,
        /// the result itself is not among them.
        let reel: [String]
    }

    static let reelLength = 14

    /// Lines the draw can land on: the ones whose base form is not in the Pokédex yet. When all
    /// of them are, every line becomes possible again.
    static func candidates(lines: [PokemonLine], obtained: Set<Int>) -> [PokemonLine] {
        let fresh = lines.filter { !obtained.contains($0.base.dex) }
        return fresh.isEmpty ? lines : fresh
    }

    /// 30 % shiny (20 % for a manual choice), never right after a give-up cycle: then the source
    /// is not even consumed for it.
    static func draw(lines: [PokemonLine], obtained: Set<Int>, afterAbandon: Bool,
                     random: () -> Double = { Double.random(in: 0..<1) },
                     shinyExists: (Int) -> Bool = { SpriteFiles.hasStill(dex: $0, shiny: true) }) -> Draw? {
        let pool = candidates(lines: lines, obtained: obtained)
        guard !pool.isEmpty else { return nil }
        let chosen = pool[index(random(), count: pool.count)]
        let reel = reel(from: lines, result: chosen, random: random)
        let shiny = afterAbandon ? false
            : LineCatalog.rollShiny(for: chosen, chance: LineCatalog.randomShinyChance, random: random, shinyExists: shinyExists)
        return Draw(lineId: chosen.id, shiny: shiny, reel: reel.map(\.id))
    }

    /// `reelLength` lines picked at random among `lines`: no line twice in a row, none equal to
    /// the result (so the result appears only at the end, after the scrolling).
    static func reel(from lines: [PokemonLine], result: PokemonLine, count: Int = reelLength,
                     random: () -> Double) -> [PokemonLine] {
        let others = lines.filter { $0.id != result.id }
        guard others.count > 1 else { return Array(others.prefix(count)) }
        var reel: [PokemonLine] = []
        while reel.count < count {
            let allowed = others.filter { $0.id != reel.last?.id }
            reel.append(allowed[index(random(), count: allowed.count)])
        }
        return reel
    }

    private static func index(_ value: Double, count: Int) -> Int {
        min(count - 1, max(0, Int(value * Double(count))))
    }
}
