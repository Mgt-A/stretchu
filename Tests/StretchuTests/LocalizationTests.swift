import XCTest
@testable import Stretchu

final class LocalizationTests: XCTestCase {
    private func table(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            L10n.bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language),
            "\(language) Localizable.strings missing")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Stretchu")
    }

    /// Keys used with `tr("…")` and `trPlural("…")` in the code.
    private func keysUsedInCode() throws -> (plain: Set<String>, plural: Set<String>) {
        let files = FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        let plain = try NSRegularExpression(pattern: #"\btr\("([A-Za-z0-9_.]+)""#)
        let plural = try NSRegularExpression(pattern: #"\btrPlural\("([A-Za-z0-9_.]+)""#)
        var plainKeys = Set<String>(), pluralKeys = Set<String>()
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for (regex, into) in [(plain, 0), (plural, 1)] {
                for match in regex.matches(in: text, range: range) {
                    let key = String(text[Range(match.range(at: 1), in: text)!])
                    if into == 0 { plainKeys.insert(key) } else { pluralKeys.insert(key) }
                }
            }
        }
        return (plainKeys, pluralKeys)
    }

    func testEveryEnglishKeyExistsInFrench() throws {
        let en = try table("en"), fr = try table("fr")
        let missing = Set(en.keys).subtracting(fr.keys).sorted()
        XCTAssertTrue(missing.isEmpty, "keys missing in fr.lproj: \(missing)")
    }

    func testEveryFrenchKeyExistsInEnglish() throws {
        let en = try table("en"), fr = try table("fr")
        let extra = Set(fr.keys).subtracting(en.keys).sorted()
        XCTAssertTrue(extra.isEmpty, "keys only in fr.lproj: \(extra)")
    }

    func testEveryKeyUsedInTheCodeExists() throws {
        let en = try table("en")
        let (plain, plural) = try keysUsedInCode()
        XCTAssertGreaterThan(plain.count, 100, "the scan should find the interface keys")
        for key in plain { XCTAssertNotNil(en[key], "tr(\"\(key)\") has no English string") }
        for key in plural {
            XCTAssertNotNil(en["\(key).one"], "\(key).one")
            XCTAssertNotNil(en["\(key).other"], "\(key).other")
        }
    }

    func testNoStringIsEmptyOrJustItsKey() throws {
        for language in ["en", "fr"] {
            for (key, value) in try table(language) {
                XCTAssertFalse(value.isEmpty, "\(language) \(key) is empty")
                XCTAssertNotEqual(value, key, "\(language) \(key) is not translated")
            }
        }
    }

    func testPlaceholdersMatchBetweenLanguages() throws {
        let en = try table("en"), fr = try table("fr")
        let regex = try NSRegularExpression(pattern: #"%\d\$@"#)
        func placeholders(_ s: String) -> [String] {
            regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
                .map { String(s[Range($0.range, in: s)!]) }.sorted()
        }
        for (key, value) in en {
            XCTAssertEqual(placeholders(value), placeholders(fr[key] ?? ""), key)
        }
    }

    func testTheFrenchTextsHaveNoEmDash() throws {
        for (key, value) in try table("fr") {
            XCTAssertFalse(value.contains("—"), key)
        }
    }

    func testFrenchIsTheCurrentFrenchTextWordForWord() throws {
        let fr = try table("fr")
        XCTAssertEqual(fr["wake.start"], "C'est parti")
        XCTAssertEqual(fr["wake.snooze"], "Plus tard · 5 min")
        XCTAssertEqual(fr["exercise.hurts"], "Ça tire")
        XCTAssertEqual(fr["menu.breakNow"], "Faire une pause maintenant")
        XCTAssertEqual(fr["settings.launchAtLogin"], "Lancer Stretchu à l'ouverture de session")
    }

    func testLookupByLanguage() {
        XCTAssertEqual(tr("wake.start", language: "en"), "Let's go")
        XCTAssertEqual(tr("wake.start", language: "fr"), "C'est parti")
        XCTAssertEqual(tr("exercise.xpAtEnd", "204", language: "fr"), "+204 XP à la fin")
        XCTAssertEqual(tr("exercise.xpAtEnd", "204", language: "en"), "+204 XP at the end")
    }

    func testAMissingKeyFallsBackToTheKey() {
        XCTAssertEqual(tr("no.such.key", language: "fr"), "no.such.key")
    }

    func testPlurals() {
        XCTAssertEqual(trPlural("menu.breaksToday", count: 0, 0, language: "fr"), "0 pause aujourd'hui")
        XCTAssertEqual(trPlural("menu.breaksToday", count: 1, 1, language: "fr"), "1 pause aujourd'hui")
        XCTAssertEqual(trPlural("menu.breaksToday", count: 2, 2, language: "fr"), "2 pauses aujourd'hui")
        XCTAssertEqual(trPlural("menu.breaksToday", count: 0, 0, language: "en"), "0 breaks today")
        XCTAssertEqual(trPlural("menu.breaksToday", count: 1, 1, language: "en"), "1 break today")
    }

    func testNumbersFollowTheLanguage() {
        XCTAssertEqual(Format.xp(1_234, locale: Locale(identifier: "en")), "1,234")
        XCTAssertEqual(Format.xp(1_234, locale: Locale(identifier: "fr")), "1\u{202F}234")
        XCTAssertEqual(Format.multiplier(3.4, locale: Locale(identifier: "fr")), "×3,4")
        XCTAssertEqual(Format.multiplier(3.4, locale: Locale(identifier: "en")), "×3.4")
    }

    func testWeekdayLettersHaveSevenEntries() {
        for language in ["en", "fr"] {
            XCTAssertEqual(L10n.string("weekday.letters", language: language).split(separator: ",").count, 7, language)
        }
    }

    func testInfoPlistStringsExistInBothLanguages() throws {
        let root = sourcesDir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        for language in ["en", "fr"] {
            let url = root.appendingPathComponent("\(language).lproj/InfoPlist.strings")
            let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], language)
            XCTAssertNotNil(dict["NSLocationUsageDescription"], language)
            XCTAssertNotNil(dict["NSLocationWhenInUseUsageDescription"], language)
        }
    }
}
