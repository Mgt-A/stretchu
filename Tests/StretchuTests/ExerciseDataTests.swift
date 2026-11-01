import XCTest
@testable import Stretchu

/// Checks the real catalog (Resources/Exercises/catalog.json) and its pictures.
final class ExerciseDataTests: XCTestCase {
    private func load() throws -> [Exercise] {
        let url = try XCTUnwrap(AppResources.url("Exercises/catalog.json"), "catalog.json not found")
        return try ExerciseCatalog.load(from: url)
    }

    private func raw() throws -> [String: Any] {
        let url = try XCTUnwrap(AppResources.url("Exercises/catalog.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    func testTheCatalogIsAShortStaticList() throws {
        let count = try load().count
        XCTAssertGreaterThanOrEqual(count, 20)
        XCTAssertLessThanOrEqual(count, 30)
    }

    func testEveryExerciseComesFromTheLibraryWithItsPictures() throws {
        for e in try load() {
            XCTAssertEqual(e.origin, "free-exercise-db", e.id)
            XCTAssertFalse(e.images.isEmpty, e.id)
            XCTAssertTrue(e.images.allSatisfy { $0.hasSuffix(".jpg") }, e.id)
        }
    }

    func testNoExerciseNeedsEquipmentOrAFloor() throws {
        let exercises = try XCTUnwrap(raw()["exercises"] as? [[String: Any]])
        for e in exercises { XCTAssertNil(e["equipment"], e["id"] as? String ?? "") }
    }

    func testTheCatalogRecordsItsSource() throws {
        let source = try XCTUnwrap(raw()["source"] as? [String: Any])
        XCTAssertEqual(source["name"] as? String, "free-exercise-db")
        XCTAssertEqual((source["commit"] as? String)?.count, 40)
        XCTAssertEqual(source["license"] as? String, "Unlicense")
    }

    func testIdsAreUnique() throws {
        let ids = try load().map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEverySourceExerciseIsGentleStretchingOrMobility() throws {
        for e in try load() {
            XCTAssertTrue(["stretching", "mobility"].contains(e.category), "\(e.id): \(e.category)")
            XCTAssertNotEqual(e.level, "expert", e.id)
        }
    }

    func testThereIsNoSpaceField() throws {
        let exercises = try XCTUnwrap(raw()["exercises"] as? [[String: Any]])
        for e in exercises { XCTAssertNil(e["space"]); XCTAssertNil(e["modes"]) }
    }

    func testThreeStepsAndAOneLineName() throws {
        for e in try load() {
            XCTAssertEqual(e.steps.count, 3, e.id)
            XCTAssertFalse(e.name.contains("\n"), e.id)
            XCTAssertEqual(e.durationSeconds, 30, e.id)
            XCTAssertTrue(e.steps.allSatisfy { !$0.isEmpty }, e.id)
        }
    }

    func testEveryImageExists() throws {
        for e in try load() {
            XCTAssertFalse(e.images.isEmpty && e.origin == "free-exercise-db", e.id)
            for image in e.images {
                XCTAssertNotNil(AppResources.url("Exercises/\(image)"), "\(e.id): \(image) missing")
            }
        }
    }

    func testEveryPictureFolderBelongsToTheCatalog() throws {
        let ids = Set(try load().map(\.id))
        let root = try XCTUnwrap(AppResources.url("Exercises"))
        let folders = try FileManager.default.contentsOfDirectory(atPath: root.path).filter {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path, isDirectory: &isDir)
            return isDir.boolValue
        }
        for folder in folders { XCTAssertTrue(ids.contains(folder), "\(folder) has pictures but is not in the catalog") }
    }

    func testThePicturesStayUnderFifteenMegabytes() throws {
        let root = try XCTUnwrap(AppResources.url("Exercises"))
        var total = 0
        for case let url as URL in FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])! {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        XCTAssertLessThan(total, 15_000_000, "committed pictures: \(total) bytes")
    }

    func testGentleRuleNoArmPushingNoBallistics() throws {
        let forbidden = ["push-up", "pushup", "plank", "jump", "bounce", "pompe", "gainage", "planche", "saut", "rebond"]
        for e in try load() {
            let text = (e.name + " " + e.steps.joined(separator: " ")).lowercased()
            for word in forbidden where text.contains(word) { XCTFail("\(e.id) contains \"\(word)\"") }
        }
    }

    func testTheStepsAreGentle() throws {
        // Anything that could be read as "push through it" is out.
        for e in try load() {
            let text = e.steps.joined(separator: " ").lowercased()
            for word in ["force it", "no pain no gain", "as hard as you can", "until it hurts"] {
                XCTAssertFalse(text.contains(word), e.id)
            }
        }
    }

    func testTheOldCatalogFileIsGone() {
        XCTAssertNil(AppResources.url("Exercises/exercises.json"))
    }
}

/// French texts in catalog.fr.json, English where a translation is missing.
final class ExerciseTranslationTests: XCTestCase {
    private var english: [Exercise] { ExerciseCatalog.english }

    func testEveryExerciseHasAFrenchNameAndThreeFrenchSteps() throws {
        let table = ExerciseCatalog.translations(language: "fr")
        XCTAssertEqual(Set(table.keys), Set(english.map(\.id)), "the French file covers exactly the catalog")
        for (id, t) in table {
            XCTAssertFalse(t.name.isEmpty, id)
            XCTAssertEqual(t.steps.count, 3, id)
        }
    }

    func testFrenchTextsAddressThePlayerAsTuAndHaveNoEmDash() throws {
        for (id, t) in ExerciseCatalog.translations(language: "fr") {
            XCTAssertFalse((t.name + t.steps.joined()).contains("—"), id)
            let text = " " + t.steps.joined(separator: " ").lowercased() + " "
            XCTAssertFalse(text.contains(" vous ") || text.contains(" votre ") || text.contains(" vos "), id)
        }
    }

    func testTheLocalizedCatalogUsesTheFrenchTexts() throws {
        let fr = ExerciseCatalog.localized(english, language: "fr")
        let chin = try XCTUnwrap(fr.first { $0.id == "Chin_To_Chest_Stretch" })
        XCTAssertFalse(chin.name.isEmpty)
        XCTAssertNotEqual(chin.name, english.first { $0.id == "Chin_To_Chest_Stretch" }?.name)
        XCTAssertEqual(chin.images, english.first { $0.id == "Chin_To_Chest_Stretch" }?.images, "everything but the texts is kept")
    }

    func testAMissingTranslationFallsBackToEnglish() {
        // A language without a file: the English catalog.
        XCTAssertEqual(ExerciseCatalog.localized(english, language: "de"), english)
        XCTAssertEqual(ExerciseCatalog.localized(english, language: "en"), english)
        XCTAssertTrue(ExerciseCatalog.translations(language: "de").isEmpty)
    }
}
