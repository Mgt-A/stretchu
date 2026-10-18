import AppKit
import SwiftUI

/// Grid of the equipment the catalog uses (2 columns): icon, name, number of exercises, check.
/// Used by the setup and by Settings.
struct EquipmentGridView: View {
    @Binding var owned: Set<String>
    var catalog: [Exercise] = ExerciseCatalog.english

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Equipment.inCatalog(catalog), id: \.self) { equipment in
                let on = owned.contains(equipment)
                Button {
                    if on { owned.remove(equipment) } else { owned.insert(equipment) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            EquipmentIcon(equipment: equipment, size: 22)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(on ? Color.accentColor : Color.white.opacity(0.35))
                        }
                        Text(Equipment.gridLabel(equipment)).font(.system(size: 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        Text(trPlural("setup.equipment.count", count: Equipment.count(of: equipment, in: catalog),
                                      Equipment.count(of: equipment, in: catalog)))
                            .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white.opacity(on ? 0.14 : 0.06)))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(on ? Color.accentColor : .clear, lineWidth: 1.5))
                    .contentShape(RoundedRectangle(cornerRadius: Radius.card))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The program choice: the general one, or a file written by hand or by an AI assistant.
struct ProgramChoiceView: View {
    let general: ProgramEntry?
    /// The player's own program, if one was imported.
    let custom: ProgramEntry?
    let selectedId: String
    /// Equipment owned at home and at the office, for the exercise count.
    let owned: Set<String>
    var message: String?
    let onSelect: (String) -> Void
    let onChooseFile: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let general {
                row(selected: selectedId == general.id, action: { onSelect(general.id) }) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("program.general.name")).font(.system(size: 14, weight: .semibold))
                        Text(tr("program.general.desc")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                        count(general)
                    }
                }
            }
            row(selected: custom.map { selectedId == $0.id } ?? false, action: { if let custom { onSelect(custom.id) } else { onChooseFile() } }) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(custom?.program.name ?? tr("program.custom.name")).font(.system(size: 14, weight: .semibold))
                    Text(tr("program.custom.desc")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    if let custom {
                        count(custom)
                        if custom.importResult.unknownCount > 0 {
                            Text(trPlural("program.unknownIgnored", count: custom.importResult.unknownCount, custom.importResult.unknownCount))
                                .font(.system(size: 11.5)).foregroundStyle(Color.orange)
                        }
                    }
                    HStack(spacing: 8) {
                        Button(tr("program.chooseFile"), action: onChooseFile).buttonStyle(.secondary)
                        Button(tr("program.howTo")) { NSWorkspace.shared.open(AppLinks.programDocumentation) }.buttonStyle(.secondary)
                    }
                    if let message { Text(message).font(.system(size: 11.5)).foregroundStyle(Color.red) }
                }
            }
        }
    }

    private func count(_ entry: ProgramEntry) -> some View {
        let n = Equipment.availableCount(in: entry.program, catalog: ExerciseCatalog.english, owned: owned)
        return Text(trPlural("program.exerciseCount", count: n, n)).font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.5))
    }

    private func row<Content: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14)).foregroundStyle(selected ? Color.accentColor : Color.white.opacity(0.4)).padding(.top, 1)
                content()
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white.opacity(selected ? 0.12 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
    }
}

enum AppLinks {
    /// How to write a program, or have an AI assistant write one.
    static let programDocumentation = URL(string: "https://github.com/Mgt-A/stretchu/blob/main/docs/CREATE-YOUR-PROGRAM.md")!
}

/// Opens the file picker for a program (.json).
@MainActor
enum ProgramFilePicker {
    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = tr("program.chooseFile")
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// A short message for an error of the import.
    static func message(for error: Error) -> String {
        switch error as? ProgramImportError {
        case .unsupportedSchemaVersion(let v): tr("program.error.version", v)
        case .noKnownExercise: tr("program.error.noExercise")
        default: tr("program.error.unreadable")
        }
    }
}

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
