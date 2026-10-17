import Foundation

/// Name in the interface language, English when a translation is missing.
func localizedName(_ names: [String: String], language: String = L10n.languageCode) -> String {
    names[language] ?? names["en"] ?? names.values.sorted().first ?? ""
}

/// One species a companion goes through, with the level at which it appears.
struct Species: Codable, Equatable, Hashable {
    /// National Pokédex number.
    let dex: Int
    let slug: String
    let names: [String: String]
    /// First level at which the line shows this species.
    let level: Int

    var name: String { localizedName(names) }
    func name(language: String) -> String { localizedName(names, language: language) }
}

/// Evolution stone offered at the branch level, and the species it gives.
struct BranchOption: Codable, Equatable, Hashable {
    let stone: String
    let stoneNames: [String: String]
    let dex: Int
    let slug: String
    let names: [String: String]

    var stoneName: String { localizedName(stoneNames) }
    func species(level: Int) -> Species { Species(dex: dex, slug: slug, names: names, level: level) }
}

/// A line that branches (Eevee): at `level` the player chooses one option.
struct Branch: Codable, Equatable, Hashable {
    let level: Int
    let options: [BranchOption]
}

/// A line of Pokémon, read from Resources/lines.json. Evolution levels: 2 evolutions at 33 and 66,
/// 1 evolution at 50, none: the same species up to level 100.
struct PokemonLine: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let species: [Species]
    let branch: Branch?

    var base: Species { species[0] }

    /// Every species the line can show, branch options included.
    var allSpecies: [Species] {
        species + (branch?.options.map { $0.species(level: branch?.level ?? 0) } ?? [])
    }

    /// The species the line goes through: the fixed ones, then the chosen branch option if any.
    func chain(branchDex: Int?) -> [Species] {
        guard let branch, let dex = branchDex, let option = branch.options.first(where: { $0.dex == dex })
        else { return species }
        return species + [option.species(level: branch.level)]
    }

    /// Species shown at `level`. A branch not chosen yet leaves the line on its last fixed species.
    func species(atLevel level: Int, branchDex: Int?) -> Species {
        chain(branchDex: branchDex).last { $0.level <= level } ?? base
    }

    /// True once the line reached its branch level without a choice.
    func needsBranchChoice(atLevel level: Int, branchDex: Int?) -> Bool {
        guard let branch else { return false }
        return level >= branch.level && !branch.options.contains { $0.dex == branchDex }
    }

    /// Built-in Pikachu line, used when lines.json can't be read and by the tests.
    static let pikachu = PokemonLine(
        id: "pikachu",
        species: [
            Species(dex: 25, slug: "pikachu", names: ["en": "Pikachu", "fr": "Pikachu"], level: 1),
            Species(dex: 26, slug: "raichu", names: ["en": "Raichu", "fr": "Raichu"], level: 50),
        ],
        branch: nil)
}

/// What the player has chosen as companion for the current cycle.
struct CurrentPokemon: Codable, Equatable {
    var lineId = LineCatalog.defaultLineId
    var shiny = false
    /// Pokédex number of the chosen branch option (Eevee), nil until chosen.
    var branchDex: Int?

    init(lineId: String = LineCatalog.defaultLineId, shiny: Bool = false, branchDex: Int? = nil) {
        self.lineId = lineId
        self.shiny = shiny
        self.branchDex = branchDex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lineId = try c.decodeIfPresent(String.self, forKey: .lineId) ?? LineCatalog.defaultLineId
        shiny = try c.decodeIfPresent(Bool.self, forKey: .shiny) ?? false
        branchDex = try c.decodeIfPresent(Int.self, forKey: .branchDex)
    }
}

/// Where a sprite is: a species, normal or shiny.
struct SpriteRef: Equatable, Hashable {
    let dex: Int
    let shiny: Bool
}

enum LineCatalog {
    struct File: Codable {
        let schemaVersion: Int
        let spriteCollabCommit: String
        let pokeApiSpritesCommit: String
        let lines: [PokemonLine]
    }

    /// A state from before the lines existed was a Pichu: it becomes the Pikachu line.
    static let defaultLineId = "pikachu"

    /// Chance of a shiny at each choice of Pokémon.
    static let shinyChance = 0.20
    /// Chance of a shiny when the player lets chance choose the Pokémon.
    static let randomShinyChance = 0.30

    /// Every line of Resources/lines.json (Gen 1), downloaded or not.
    static let all: [PokemonLine] = {
        guard let url = AppResources.url("lines.json"),
              let file = try? JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        else { return [.pikachu] }
        return file.lines
    }()

    /// Lines whose sprites were downloaded (scripts/fetch-sprites.sh drops the others).
    static let available: [PokemonLine] = {
        let usable = available(in: all, spriteExists: { SpriteFiles.hasStill(dex: $0, shiny: false) },
                               stoneExists: { SpriteFiles.stoneExists($0) })
        return usable.isEmpty ? [.pikachu] : usable
    }()

    static func available(in lines: [PokemonLine], spriteExists: (Int) -> Bool, stoneExists: (String) -> Bool) -> [PokemonLine] {
        lines.filter { line in
            line.allSpecies.allSatisfy { spriteExists($0.dex) }
                && (line.branch?.options.allSatisfy { stoneExists($0.stone) } ?? true)
        }
    }

    static func line(id: String) -> PokemonLine? {
        available.first { $0.id == id } ?? all.first { $0.id == id }
    }

    /// The line of a choice, with a safe fallback.
    static func line(for pokemon: CurrentPokemon) -> PokemonLine {
        line(id: pokemon.lineId) ?? available.first { $0.id == defaultLineId } ?? available[0]
    }

    /// A shiny exists for a line only if every one of its species has a complete shiny sheet.
    static func hasShiny(_ line: PokemonLine, shinyExists: (Int) -> Bool = { SpriteFiles.hasStill(dex: $0, shiny: true) }) -> Bool {
        line.allSpecies.allSatisfy { shinyExists($0.dex) }
    }

    /// Draws the shiny at each choice of Pokémon: 20 %, the random source is injectable.
    /// A line without a shiny never gets one, and then the source is not consumed.
    static func rollShiny(for line: PokemonLine, chance: Double = shinyChance,
                          random: () -> Double = { Double.random(in: 0..<1) },
                          shinyExists: (Int) -> Bool = { SpriteFiles.hasStill(dex: $0, shiny: true) }) -> Bool {
        guard hasShiny(line, shinyExists: shinyExists) else { return false }
        return random() < chance
    }

    /// Choice of a Pokémon for a new cycle.
    static func choose(lineId: String, random: () -> Double = { Double.random(in: 0..<1) }) -> CurrentPokemon {
        let line = line(id: lineId) ?? .pikachu
        return CurrentPokemon(lineId: line.id, shiny: rollShiny(for: line, random: random), branchDex: nil)
    }
}

/// Sprite files on disk (Resources/Sprites, downloaded at build time).
enum SpriteFiles {
    static func relativePath(dex: Int, shiny: Bool, file: String) -> String {
        "Sprites/pmd/\(String(format: "%04d", dex))/\(shiny ? "shiny/" : "")\(file)"
    }

    static func exists(dex: Int, shiny: Bool, file: String) -> Bool {
        AppResources.url(relativePath(dex: dex, shiny: shiny, file: file)) != nil
    }

    /// A still picture can be drawn: the Idle sheet, or Walk for a species that has no Idle.
    static func hasStill(dex: Int, shiny: Bool) -> Bool {
        exists(dex: dex, shiny: shiny, file: "Idle-Anim.png") || exists(dex: dex, shiny: shiny, file: "Walk-Anim.png")
    }

    static func stoneExists(_ stone: String) -> Bool {
        AppResources.url("Sprites/items/\(stone).png") != nil
    }
}
