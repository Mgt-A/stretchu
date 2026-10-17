import Foundation

enum PlaceMode: String, Codable, Equatable, CaseIterable {
    case home, office

    var name: String { self == .home ? tr("place.home") : tr("place.office") }
}

/// One exercise of the bundled catalog (Resources/Exercises/catalog.json).
struct Exercise: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    /// 3 steps at most, second person, gentle, never to the point of pain.
    let steps: [String]
    /// The `equipment` value of free-exercise-db, as is: nil or "body only" need nothing.
    let equipment: String?
    /// "stretching" or "mobility".
    let category: String
    let level: String
    let primaryMuscles: [String]
    /// Paths relative to Resources/Exercises/. Empty: steps only.
    let images: [String]
    let durationSeconds: Int
    let unilateral: Bool
    /// "free-exercise-db" or "stretchu" (made for the app).
    let origin: String

    init(id: String, name: String, steps: [String], equipment: String? = nil, category: String = "stretching",
         level: String = "beginner", primaryMuscles: [String] = [], images: [String] = [],
         durationSeconds: Int = 30, unilateral: Bool = false, origin: String = "stretchu") {
        self.id = id; self.name = name; self.steps = steps; self.equipment = equipment
        self.category = category; self.level = level; self.primaryMuscles = primaryMuscles
        self.images = images; self.durationSeconds = durationSeconds; self.unilateral = unilateral
        self.origin = origin
    }
}

/// What an exercise needs, and what the player owns.
enum Equipment {
    /// Values of free-exercise-db's `equipment` the app lets the player own. "body only" is always
    /// there; "other", "machine", "cable" and "barbell" have no place in a desk break.
    static let ownable = ["bands", "foam roll", "exercise ball", "medicine ball", "kettlebells", "dumbbell"]

    static func isAvailable(_ equipment: String?, owned: Set<String>) -> Bool {
        guard let equipment, equipment != "body only" else { return true }
        return owned.contains(equipment)
    }

    /// Equipment values the catalog actually uses and the player can own, in `ownable` order.
    static func inCatalog(_ catalog: [Exercise]) -> [String] {
        let used = Set(catalog.compactMap(\.equipment))
        return ownable.filter(used.contains)
    }

    /// SVG/PDF name (Resources/Icons, Tabler Icons) and label of each ownable equipment, for the grids.
    static func iconName(_ equipment: String) -> String {
        switch equipment {
        case "bands": "wave-sine"
        case "foam roll": "cylinder"
        case "exercise ball": "ball-volleyball"
        case "medicine ball": "ball-basketball"
        case "kettlebells": "weight"
        default: "barbell"
        }
    }

    static func gridLabel(_ equipment: String) -> String {
        switch equipment {
        case "bands": tr("equipment.grid.bands")
        case "foam roll": tr("equipment.grid.foamRoll")
        case "exercise ball": tr("equipment.grid.exerciseBall")
        case "medicine ball": tr("equipment.grid.medicineBall")
        case "kettlebells": tr("equipment.grid.kettlebells")
        default: tr("equipment.grid.dumbbell")
        }
    }

    /// Exercises of a program the equipment allows.
    static func availableCount(in program: Program, catalog: [Exercise], owned: Set<String>) -> Int {
        catalog.filter { program.exercises.contains($0.id) && isAvailable($0.equipment, owned: owned) }.count
    }

    static func count(of equipment: String, in catalog: [Exercise]) -> Int {
        catalog.filter { $0.equipment == equipment }.count
    }

    /// Label shown next to an exercise ("Home · foam roller"); nil when nothing is needed.
    static func label(_ equipment: String?) -> String? {
        switch equipment {
        case "bands": tr("equipment.bands")
        case "foam roll": tr("equipment.foamRoll")
        case "exercise ball": tr("equipment.exerciseBall")
        case "medicine ball": tr("equipment.medicineBall")
        case "kettlebells": tr("equipment.kettlebells")
        case "dumbbell": tr("equipment.dumbbell")
        default: nil
        }
    }
}

enum ExerciseCatalog {
    /// Fallback if the catalog can't be found: three text-only exercises.
    static let builtIn: [Exercise] = [
        Exercise(
            id: "builtin-rib-breathing",
            name: "Slow rib breathing",
            steps: [
                "Sit tall with your hands resting on your thighs.",
                "Breathe in through your nose for 4 seconds: belly, then ribs open without effort.",
                "Breathe out slowly for 6 seconds. Stop if you feel any pain.",
            ]),
        Exercise(
            id: "builtin-gentle-chest-opener",
            name: "Gentle chest opener",
            steps: [
                "Stand with your arms by your sides and your shoulders relaxed.",
                "Turn your palms forward and open your shoulders a little.",
                "Breathe slowly, without pressing on your ribs or going to the point of pain.",
            ]),
        Exercise(
            id: "builtin-neck-and-shoulders",
            name: "Neck and shoulders, gently",
            steps: [
                "Chin slightly tucked, eyes straight ahead.",
                "Turn your head slowly to the right, then to the left, without jerking.",
                "Let your shoulders drop at every breath out.",
            ]),
    ]

    private struct CatalogFile: Decodable { let exercises: [Exercise] }
    private struct Translation: Decodable { let name: String; let steps: [String] }
    private struct TranslationFile: Decodable { let exercises: [String: Translation] }

    static func load(from url: URL) throws -> [Exercise] {
        try JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: url)).exercises
    }

    /// `catalog.<language>.json`: names and steps by exercise id. A missing translation (or a
    /// missing file) leaves the English text.
    static func translations(language: String) -> [String: (name: String, steps: [String])] {
        guard language != "en", let url = AppResources.url("Exercises/catalog.\(language).json"),
              let file = try? JSONDecoder().decode(TranslationFile.self, from: Data(contentsOf: url))
        else { return [:] }
        return file.exercises.mapValues { ($0.name, $0.steps) }
    }

    /// The English catalog with the texts of `language`, English where one is missing.
    static func localized(_ english: [Exercise], language: String) -> [Exercise] {
        let table = translations(language: language)
        return english.map { exercise in
            guard let t = table[exercise.id], !t.name.isEmpty, !t.steps.isEmpty else { return exercise }
            return Exercise(id: exercise.id, name: t.name, steps: t.steps, equipment: exercise.equipment,
                            category: exercise.category, level: exercise.level, primaryMuscles: exercise.primaryMuscles,
                            images: exercise.images, durationSeconds: exercise.durationSeconds,
                            unilateral: exercise.unilateral, origin: exercise.origin)
        }
    }

    /// The English catalog, as shipped.
    static let english: [Exercise] = {
        guard let url = AppResources.url("Exercises/catalog.json"),
              let exercises = try? load(from: url), !exercises.isEmpty
        else { return builtIn }
        return exercises
    }()

    private nonisolated(unsafe) static var cache: [String: [Exercise]] = [:]
    private static let cacheLock = NSLock()

    /// The catalog in a language (computed once per language).
    static func catalog(language: String) -> [Exercise] {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let known = cache[language] { return known }
        let built = localized(english, language: language)
        cache[language] = built
        return built
    }

    /// The app's catalog in the interface language (which the player can change at any time).
    static var catalog: [Exercise] { catalog(language: L10n.languageCode) }

    /// Picks an exercise among the program's (all of the catalog without a program) that the
    /// player's equipment allows, outside the exclusions, not already picked today, different
    /// from `different`. When nothing is left, the filters relax in this order: the program's
    /// exercises that need no equipment, then the catalog's, then the whole catalog; and within the
    /// candidates, start the day over, then ignore the exclusions.
    static func pick(from catalog: [Exercise] = ExerciseCatalog.catalog, program: Program? = nil,
                     equipment owned: Set<String>, excluded: Set<String>, alreadyPicked: Set<String>,
                     different: String?) -> Exercise {
        let inProgram = program.map { p in catalog.filter { p.exercises.contains($0.id) } } ?? catalog
        let candidates: [Exercise] = [
            inProgram.filter { Equipment.isAvailable($0.equipment, owned: owned) },
            inProgram.filter { Equipment.isAvailable($0.equipment, owned: []) },
            catalog.filter { Equipment.isAvailable($0.equipment, owned: []) },
            catalog,
        ].first { !$0.isEmpty } ?? builtIn
        let levels: [(Exercise) -> Bool] = [
            { !excluded.contains($0.id) && !alreadyPicked.contains($0.id) && $0.id != different },
            { !excluded.contains($0.id) && $0.id != different },
            { !excluded.contains($0.id) },
            { $0.id != different },
            { _ in true },
        ]
        for filter in levels {
            if let choice = candidates.filter(filter).randomElement() { return choice }
        }
        return candidates[0]
    }
}

/// Exercises already offered today (persisted, emptied on the day change).
struct DailyPicks: Codable, Equatable {
    var day: Date?
    var ids: [String] = []

    private enum CodingKeys: String, CodingKey { case day, ids }
    /// Key written by the French-named builds, read as a fallback.
    private enum LegacyKeys: String, CodingKey { case day = "jour" }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)
        day = try c.decodeIfPresent(Date.self, forKey: .day) ?? old.decodeIfPresent(Date.self, forKey: .day)
        ids = try c.decodeIfPresent([String].self, forKey: .ids) ?? []
    }

    func ids(for now: Date, calendar: Calendar) -> Set<String> {
        guard let day, day == calendar.startOfDay(for: now) else { return [] }
        return Set(ids)
    }

    mutating func record(_ id: String, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        if day != today { day = today; ids = [] }
        if !ids.contains(id) { ids.append(id) }
    }
}
