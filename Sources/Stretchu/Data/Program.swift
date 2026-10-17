import Foundation

/// A program: the exercises drawn at each break (docs/PROGRAM.md). Written by hand, by an AI
/// assistant, or shipped with the app (`general`).
struct Program: Codable, Equatable {
    struct Settings: Codable, Equatable {
        var workMinutes: Int?
        var step1Seconds: Int?
        var step2Seconds: Int?
    }

    static let supportedSchemaVersion = 1

    var schemaVersion = Program.supportedSchemaVersion
    var name: String
    var settings = Settings()
    /// Ids of the catalog.
    var exercises: [String]
    /// What the program needs, among `Equipment.ownable`.
    var equipment: [String] = []

    init(name: String, settings: Settings = Settings(), exercises: [String], equipment: [String] = []) {
        self.name = name
        self.settings = settings
        self.exercises = exercises
        self.equipment = equipment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        name = try c.decode(String.self, forKey: .name)
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        exercises = try c.decode([String].self, forKey: .exercises)
        equipment = try c.decodeIfPresent([String].self, forKey: .equipment) ?? []
    }

    /// The settings the program asks for, clamped to the ranges of `UserSettings`; the other
    /// durations are kept.
    func applying(to settings: UserSettings) -> UserSettings {
        var result = settings
        if let v = self.settings.workMinutes { result.workMinutes = v }
        if let v = self.settings.step1Seconds { result.step1Seconds = v }
        if let v = self.settings.step2Seconds { result.step2Seconds = v }
        return result.clamped()
    }

    /// True if one of the program's settings is outside the allowed range.
    var hasOutOfRangeSettings: Bool {
        let asked = applying(to: UserSettings(workMinutes: settings.workMinutes ?? 25, step1Seconds: settings.step1Seconds ?? 20,
                                              step2Seconds: settings.step2Seconds ?? 30))
        return asked.workMinutes != (settings.workMinutes ?? asked.workMinutes)
            || asked.step1Seconds != (settings.step1Seconds ?? asked.step1Seconds)
            || asked.step2Seconds != (settings.step2Seconds ?? asked.step2Seconds)
    }
}

enum ProgramImportError: Error, Equatable {
    case notAProgram
    case unsupportedSchemaVersion(Int)
    case noKnownExercise(unknown: Int)
}

/// Reading a program file: ids that are not in the catalog are ignored and counted, settings
/// outside the ranges are clamped, equipment the app doesn't know is dropped.
struct ProgramImport: Equatable {
    let program: Program
    let unknownExerciseIds: [String]
    let settingsWereClamped: Bool

    var unknownCount: Int { unknownExerciseIds.count }

    static func parse(_ data: Data, catalogIds: Set<String>) throws -> ProgramImport {
        guard let raw = try? JSONDecoder().decode(Program.self, from: data) else {
            // Not JSON, or a field missing: a version we can't read is told apart when we can.
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = object["schemaVersion"] as? Int, version != Program.supportedSchemaVersion {
                throw ProgramImportError.unsupportedSchemaVersion(version)
            }
            throw ProgramImportError.notAProgram
        }
        guard raw.schemaVersion == Program.supportedSchemaVersion else {
            throw ProgramImportError.unsupportedSchemaVersion(raw.schemaVersion)
        }
        var seen = Set<String>()
        let unique = raw.exercises.filter { seen.insert($0).inserted }
        let known = unique.filter(catalogIds.contains)
        let unknown = unique.filter { !catalogIds.contains($0) }
        guard !known.isEmpty else { throw ProgramImportError.noKnownExercise(unknown: unknown.count) }
        let clamped = raw.hasOutOfRangeSettings
        let applied = raw.applying(to: UserSettings())
        var cleaned = raw
        cleaned.name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Program" : String(raw.name.prefix(80))
        cleaned.exercises = known
        cleaned.equipment = Equipment.ownable.filter(Set(raw.equipment).contains)
        cleaned.settings = Program.Settings(
            workMinutes: raw.settings.workMinutes == nil ? nil : applied.workMinutes,
            step1Seconds: raw.settings.step1Seconds == nil ? nil : applied.step1Seconds,
            step2Seconds: raw.settings.step2Seconds == nil ? nil : applied.step2Seconds)
        return ProgramImport(program: cleaned, unknownExerciseIds: unknown, settingsWereClamped: clamped)
    }
}

/// A program available to the player.
struct ProgramEntry: Equatable, Identifiable {
    /// "general" for the shipped one, the file name without extension for the others.
    let id: String
    let importResult: ProgramImport
    let isBundled: Bool

    var program: Program { importResult.program }
}

/// The shipped program (Resources/Programs/general.json) and the player's files
/// (`~/Library/Application Support/Stretchu/programs/*.json`).
struct ProgramLibrary {
    static let generalId = "general"

    let userDirectory: URL
    let catalogIds: Set<String>

    init(userDirectory: URL, catalog: [Exercise] = ExerciseCatalog.english) {
        self.userDirectory = userDirectory
        self.catalogIds = Set(catalog.map(\.id))
    }

    func general() -> ProgramEntry? {
        guard let url = AppResources.url("Programs/general.json"), let data = try? Data(contentsOf: url),
              let result = try? ProgramImport.parse(data, catalogIds: catalogIds)
        else { return nil }
        return ProgramEntry(id: Self.generalId, importResult: result, isBundled: true)
    }

    /// The valid files of the user's folder, by file name.
    func userEntries() -> [ProgramEntry] {
        let files = (try? FileManager.default.contentsOfDirectory(at: userDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            guard let data = try? Data(contentsOf: url), let result = try? ProgramImport.parse(data, catalogIds: catalogIds)
            else { return nil }
            return ProgramEntry(id: url.deletingPathExtension().lastPathComponent, importResult: result, isBundled: false)
        }
    }

    /// The shipped program first, then the player's.
    func entries() -> [ProgramEntry] {
        (general().map { [$0] } ?? []) + userEntries().filter { $0.id != Self.generalId }
    }

    func entry(id: String) -> ProgramEntry? {
        entries().first { $0.id == id }
    }

    /// Copies a program file into the user's folder. Returns what was read from it.
    func importFile(at url: URL) throws -> ProgramEntry {
        let data = try Data(contentsOf: url)
        let result = try ProgramImport.parse(data, catalogIds: catalogIds)
        try FileManager.default.createDirectory(at: userDirectory, withIntermediateDirectories: true)
        var id = url.deletingPathExtension().lastPathComponent
        if id == Self.generalId { id = "general-imported" }
        try data.write(to: userDirectory.appendingPathComponent("\(id).json"), options: .atomic)
        return ProgramEntry(id: id, importResult: result, isBundled: false)
    }

    /// A state from before the programs existed keeps what it had: the player's program if there
    /// is one (its equipment becomes the home equipment, as the old home mode allowed it), else
    /// `general`. The office never had heavy gear, it stays empty.
    func migrate(_ game: inout GameState) {
        if let mine = userEntries().first {
            game.programId = mine.id
            game.settings.homeEquipment = mine.program.equipment
            game.settings.officeEquipment = []
        } else {
            game.programId = Self.generalId
        }
    }
}
