import Foundation

/// One exercise of the bundled catalog (Resources/Exercises/catalog.json).
struct Exercise: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    /// 3 steps at most, second person, gentle, never to the point of pain.
    let steps: [String]
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

    init(id: String, name: String, steps: [String], category: String = "stretching",
         level: String = "beginner", primaryMuscles: [String] = [], images: [String] = [],
         durationSeconds: Int = 30, unilateral: Bool = false, origin: String = "stretchu") {
        self.id = id; self.name = name; self.steps = steps
        self.category = category; self.level = level; self.primaryMuscles = primaryMuscles
        self.images = images; self.durationSeconds = durationSeconds; self.unilateral = unilateral
        self.origin = origin
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
            return Exercise(id: exercise.id, name: t.name, steps: t.steps,
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

    /// Picks an exercise outside the exclusions, not already picked today, different from
    /// `different`. When nothing is left, the filters relax in this order: start the day over,
    /// then ignore the exclusions.
    static func pick(from catalog: [Exercise] = ExerciseCatalog.catalog, excluded: Set<String>,
                     alreadyPicked: Set<String>, different: String?) -> Exercise {
        let candidates = catalog.isEmpty ? builtIn : catalog
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
