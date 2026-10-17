import Foundation

/// A JSON file in ~/Library/Application Support/Stretchu/state.json, written atomically.
struct StateStore {
    let directory: URL
    let fileName: String
    var fileURL: URL { directory.appendingPathComponent(fileName) }
    var exists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    static var defaultDirectory: URL {
        #if STRETCHU_DEBUG
        // Development: another folder, to try the first launch without touching the real state.
        if let custom = ProcessInfo.processInfo.environment["STRETCHU_SUPPORT_DIR"] {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stretchu", isDirectory: true)
    }

    /// `state.json` is the real state; Debug mode works in `state.debug.json`.
    init(directory: URL = StateStore.defaultDirectory, fileName: String = "state.json") {
        self.directory = directory
        self.fileName = fileName
    }

    /// Where the player's program files live, next to the state.
    var programsDirectory: URL { directory.appendingPathComponent("programs", isDirectory: true) }

    /// A file written before programs existed (no `programId`, schema below 5).
    static func predatesPrograms(_ data: Data) -> Bool {
        struct Peek: Decodable { var schemaVersion: Int?; var programId: String? }
        guard let peek = try? JSONDecoder().decode(Peek.self, from: data) else { return false }
        return peek.programId == nil && (peek.schemaVersion ?? 1) < 5
    }

    func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// A fresh state if the file is missing. An unreadable file is set aside
    /// (state.corrupt-<timestamp>.json) so nothing is lost silently.
    func load() -> GameState {
        guard let data = try? Data(contentsOf: fileURL) else { return GameState() }
        do {
            var game = try Self.decoder.decode(GameState.self, from: data)
            if Self.predatesPrograms(data) {
                ProgramLibrary(userDirectory: programsDirectory).migrate(&game)
            }
            return game
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let base = (fileName as NSString).deletingPathExtension
            let aside = directory.appendingPathComponent("\(base).corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            return GameState()
        }
    }

    func save(_ state: GameState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}
