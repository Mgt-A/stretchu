import Foundation

/// Interface strings. English is the source language (`en.lproj`), French is the translation.
/// Keys live in `Sources/Stretchu/Localization/<language>.lproj/Localizable.strings`.
enum L10n {
    /// The SwiftPM resource bundle: next to the executable's resources in the assembled app,
    /// otherwise the one SwiftPM generates for `swift run` and `swift test`.
    static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Stretchu_Stretchu.bundle"),
           let bundled = Bundle(url: url) {
            return bundled
        }
        return Bundle.module
    }()

    /// `STRETCHU_LANGUAGE=fr|en` forces a language (development, screenshots).
    static let forcedLanguage: String? = ProcessInfo.processInfo.environment["STRETCHU_LANGUAGE"]

    /// The language the player chose in the setup or in Settings; nil follows the Mac's.
    nonisolated(unsafe) static var userLanguage: String?

    /// The Mac's language when the app is translated into it, English otherwise. Read from the
    /// global preferences, so the app's own language override (below) doesn't change the answer.
    static var systemLanguageCode: String {
        let tags = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
            ?? Locale.preferredLanguages
        for tag in tags {
            let code = String(tag.split(separator: "-").first ?? "")
            if availableLanguages.contains(code) { return code }
        }
        return "en"
    }

    /// Makes macOS itself (permission prompts, file panels) use the chosen language the next time
    /// the app starts. nil gives the choice back to the Mac.
    static func setProcessLanguage(_ code: String?) {
        if let code { UserDefaults.standard.set([code], forKey: "AppleLanguages") }
        else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
    }

    /// Language the interface is shown in: "en" or "fr".
    static var languageCode: String {
        if let forcedLanguage, availableLanguages.contains(forcedLanguage) { return forcedLanguage }
        if let userLanguage, availableLanguages.contains(userLanguage) { return userLanguage }
        return systemLanguageCode
    }

    static var availableLanguages: [String] { bundle.localizations.filter { $0 != "Base" } }

    static var locale: Locale { Locale(identifier: languageCode) }

    /// The `.lproj` bundle of one language, for lookups that must not depend on the system language.
    static func bundle(for language: String) -> Bundle? {
        bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    /// Monday to Sunday initials, comma-separated in the strings file.
    static var weekdayLetters: [String] {
        string("weekday.letters").split(separator: ",").map { String($0) }
    }

    /// Looks a key up in `language` (default: the current one), then in English, then returns the key.
    static func string(_ key: String, language: String? = nil) -> String {
        let code = language ?? languageCode
        for candidate in [code, "en"] {
            guard let table = bundle(for: candidate) else { continue }
            let value = table.localizedString(forKey: key, value: "\u{0}", table: nil)
            if value != "\u{0}" { return value }
        }
        return key
    }
}

/// Localized string with positional arguments (`%1$@`, `%2$@`). Numbers are passed pre-formatted.
func tr(_ key: String, _ args: Any..., language: String? = nil) -> String {
    let format = L10n.string(key, language: language)
    guard !args.isEmpty else { return format }
    let locale = language.map(Locale.init(identifier:)) ?? L10n.locale
    return String(format: format, locale: locale, arguments: args.map { String(describing: $0) })
}

/// Singular/plural pair `<key>.one` / `<key>.other`. French treats 0 and 1 as singular, English only 1.
func trPlural(_ key: String, count: Int, _ args: Any..., language: String? = nil) -> String {
    let code = language ?? L10n.languageCode
    let singular = code == "fr" ? abs(count) < 2 : count == 1
    let suffixed = key + (singular ? ".one" : ".other")
    let format = L10n.string(suffixed, language: language)
    let locale = Locale(identifier: code)
    return String(format: format, locale: locale, arguments: args.map { String(describing: $0) })
}
