import AppKit
import SwiftUI

/// Interface languages the player can pick.
enum LanguageChoice {
    /// Endonyms, never translated.
    static func name(_ code: String) -> String {
        switch code {
        case "fr": "Français"
        case "en": "English"
        default: Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code
        }
    }
}

/// The file panels and the confirmation of Settings, "Export my state…" and "Import a state…".
enum StateFilePicker {
    static func chooseExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = StateTransfer.fileName
        panel.message = tr("data.export.panel")
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = tr("data.import.panel")
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Overwriting the state cannot be undone: the player confirms, seeing what the file holds.
    static func confirmReplace(with game: GameState) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = tr("data.import.confirm.title")
        alert.informativeText = tr("data.import.confirm.body", game.progression.level, game.streak.count)
        alert.addButton(withTitle: tr("data.import.confirm.replace"))
        alert.addButton(withTitle: tr("data.import.confirm.cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func message(for error: Error) -> String {
        switch error as? StateTransferError {
        case .newerVersion(let v): tr("data.error.version", v)
        case .notAState: tr("data.error.notState")
        default: tr("data.error.unreadable")
        }
    }
}
