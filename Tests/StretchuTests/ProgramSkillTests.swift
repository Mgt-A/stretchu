import XCTest
@testable import Stretchu

/// The skill and the README quote program examples: they must stay valid against the catalog.
final class ProgramSkillTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func catalogIds() throws -> Set<String> {
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Exercises/catalog.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let exercises = try XCTUnwrap(json["exercises"] as? [[String: Any]])
        return Set(exercises.compactMap { $0["id"] as? String })
    }

    private func jsonBlocks(in file: String) throws -> [String] {
        let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
        return text.components(separatedBy: "```json").dropFirst().compactMap { $0.components(separatedBy: "```").first }
    }

    func testTheSkillHasItsFrontMatter() throws {
        let text = try String(contentsOf: root.appendingPathComponent("skill/stretchu-program/SKILL.md"), encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("---\nname: stretchu-program\ndescription: "))
    }

    func testTheExampleOfTheSkillIsAValidProgramWithKnownIds() throws {
        let blocks = try jsonBlocks(in: "skill/stretchu-program/SKILL.md")
        XCTAssertFalse(blocks.isEmpty)
        for block in blocks {
            let result = try ProgramImport.parse(Data(block.utf8), catalogIds: try catalogIds())
            XCTAssertEqual(result.unknownCount, 0, "unknown ids in the skill example")
            XCTAssertFalse(result.settingsWereClamped)
        }
    }

    func testTheExamplesKeepAtLeastTenExercisesWithoutEquipmentAndListTheEquipmentTheyNeed() throws {
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Exercises/catalog.json"))
        let exercises = try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["exercises"] as? [[String: Any]])
        var equipmentOf: [String: String?] = [:]
        for e in exercises { equipmentOf[e["id"] as! String] = e["equipment"] as? String }
        for file in ["skill/stretchu-program/SKILL.md", "docs/PROGRAM.md"] {
            for block in try jsonBlocks(in: file) {
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(block.utf8)) as? [String: Any])
                let ids = try XCTUnwrap(json["exercises"] as? [String])
                let needed = Set(ids.compactMap { equipmentOf[$0] ?? nil }.filter { $0 != "body only" })
                XCTAssertGreaterThanOrEqual(ids.count - ids.filter { (equipmentOf[$0] ?? nil).map { $0 != "body only" } ?? false }.count, 10, file)
                XCTAssertEqual(Set(json["equipment"] as? [String] ?? []), needed, "\(file): equipment is the computed list")
            }
        }
    }

    func testTheGeneralProgramKeepsAtLeastTenExercisesWithoutEquipment() throws {
        let url = root.appendingPathComponent("Resources/Programs/general.json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let ids = try XCTUnwrap(json["exercises"] as? [String])
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Exercises/catalog.json"))
        let exercises = try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["exercises"] as? [[String: Any]])
        var free = Set<String>()
        for e in exercises where (e["equipment"] as? String) == nil || (e["equipment"] as? String) == "body only" { free.insert(e["id"] as! String) }
        XCTAssertGreaterThanOrEqual(ids.filter(free.contains).count, 10)
    }

    func testTheSkillNamesNoExerciseThatTheCatalogLacks() throws {
        let known = try catalogIds()
        let text = try String(contentsOf: root.appendingPathComponent("skill/stretchu-program/SKILL.md"), encoding: .utf8)
        let quoted = text.components(separatedBy: "\"").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        for value in quoted where value.range(of: #"^[A-Z0-9][A-Za-z0-9_\-]+$"#, options: .regularExpression) != nil && value.contains("_") {
            XCTAssertTrue(known.contains(value), "\(value) is not in the catalog")
        }
    }

    func testTheAppNeverNamesAnAssistantBrand() throws {
        for lang in ["en", "fr"] {
            let url = root.appendingPathComponent("Sources/Stretchu/Localization/\(lang).lproj/Localizable.strings")
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("Claude"), "\(lang) strings name an assistant")
        }
    }
}
