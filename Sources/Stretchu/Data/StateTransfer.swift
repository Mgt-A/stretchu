import Foundation

enum StateTransferError: Error, Equatable {
    case unreadable
    case notAState
    /// Written by a newer Stretchu than this one.
    case newerVersion(Int)
}

/// Export and import of the whole state, to move it to another Mac.
enum StateTransfer {
    static let fileName = "stretchu-state.json"

    /// A validated state, and whether it was written before programs existed.
    struct Imported {
        var game: GameState
        var predatesPrograms: Bool
    }

    /// Decodes a state file (older formats go through the usual migration in `GameState.init(from:)`)
    /// and refuses anything that is not a state, or that a newer build wrote.
    static func validate(_ data: Data) throws -> Imported {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { throw StateTransferError.unreadable }
        guard let raw = json as? [String: Any] else { throw StateTransferError.notAState }
        // Every field has a default, so `{}` would decode: a state always has its progression.
        guard raw["progression"] is [String: Any] else { throw StateTransferError.notAState }
        if let version = raw["schemaVersion"] as? Int, version > GameState.currentSchemaVersion {
            throw StateTransferError.newerVersion(version)
        }
        do {
            return Imported(game: try StateStore.decoder.decode(GameState.self, from: data),
                            predatesPrograms: StateStore.predatesPrograms(data))
        } catch {
            throw StateTransferError.notAState
        }
    }

    static func read(from url: URL) throws -> Imported {
        guard let data = try? Data(contentsOf: url) else { throw StateTransferError.unreadable }
        return try validate(data)
    }
}

extension StateStore {
    /// Copies the stored state to `url`, or writes `fallback` when nothing was stored yet.
    func export(to url: URL, fallback: GameState) throws {
        let data = try (try? Data(contentsOf: fileURL)) ?? Self.encoder.encode(fallback)
        try data.write(to: url, options: .atomic)
    }
}
