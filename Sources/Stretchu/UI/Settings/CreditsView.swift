import SwiftUI

/// Credits: the sprites and the exercises, one short paragraph each, with a link to the source.
struct CreditsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: tr("credits.title"), back: { model.back() })

            PageSection(title: tr("credits.sprites")) { text("credits.sprites.body") }
            PageSection(title: tr("credits.exercises")) { text("credits.exercises.body") }

            Text(tr("credits.disclaimer")).freeCaption().fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }

    /// A short paragraph whose Markdown links open in the browser.
    private func text(_ key: String) -> some View {
        Text(.init(tr(key)))
            .font(.system(size: 12.5)).foregroundStyle(Color.white.opacity(0.75))
            .tint(Color.accentColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// credits.json as written by the fetch script.
struct SpriteCredits: Decodable, Equatable {
    struct Artist: Decodable, Equatable { let name: String; let contact: String? }
    let source: String
    let license: String
    let commit: String
    let artists: [Artist]
    let bySpecies: [String: [String]]

    static func load() -> SpriteCredits? {
        guard let url = AppResources.url("Sprites/credits.json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(SpriteCredits.self, from: data)
    }
}
