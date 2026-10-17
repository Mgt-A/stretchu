import XCTest
@testable import Stretchu

final class ProgramFormatTests: XCTestCase {
    private let ids: Set<String> = ["Chin_Tucks", "Side_Neck_Stretch", "Shoulder_Circles", "Cat_Stretch"]

    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testTheExampleOfTheDocumentationReads() throws {
        let result = try ProgramImport.parse(data("""
        {"schemaVersion":1,"name":"Desk mobility, sore neck",
         "settings":{"workMinutes":25,"step1Seconds":20,"step2Seconds":30},
         "exercises":["Chin_Tucks","Side_Neck_Stretch","Shoulder_Circles"],"equipment":["bands"]}
        """), catalogIds: ids)
        XCTAssertEqual(result.program.name, "Desk mobility, sore neck")
        XCTAssertEqual(result.program.exercises, ["Chin_Tucks", "Side_Neck_Stretch", "Shoulder_Circles"])
        XCTAssertEqual(result.program.equipment, ["bands"])
        XCTAssertEqual(result.program.settings, Program.Settings(workMinutes: 25, step1Seconds: 20, step2Seconds: 30))
        XCTAssertEqual(result.unknownCount, 0)
        XCTAssertFalse(result.settingsWereClamped)
    }

    func testUnknownIdsAreIgnoredAndCounted() throws {
        let result = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"x","exercises":["Chin_Tucks","Nope","Nope_Either","Cat_Stretch"]}"#), catalogIds: ids)
        XCTAssertEqual(result.program.exercises, ["Chin_Tucks", "Cat_Stretch"])
        XCTAssertEqual(result.unknownExerciseIds, ["Nope", "Nope_Either"])
        XCTAssertEqual(result.unknownCount, 2)
    }

    func testDuplicatesCountOnce() throws {
        let result = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"x","exercises":["Chin_Tucks","Chin_Tucks","Nope","Nope"]}"#), catalogIds: ids)
        XCTAssertEqual(result.program.exercises, ["Chin_Tucks"])
        XCTAssertEqual(result.unknownCount, 1)
    }

    func testAFileWithoutAnyKnownIdIsRefused() {
        XCTAssertThrowsError(try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"x","exercises":["Nope","Nada"]}"#), catalogIds: ids)) {
            XCTAssertEqual($0 as? ProgramImportError, .noKnownExercise(unknown: 2))
        }
    }

    func testSettingsAreClampedLikeTheAppsSettings() throws {
        let result = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"x","exercises":["Chin_Tucks"],"settings":{"workMinutes":999,"step1Seconds":1,"step2Seconds":45}}"#), catalogIds: ids)
        XCTAssertEqual(result.program.settings.workMinutes, UserSettings.workRange.upperBound)
        XCTAssertEqual(result.program.settings.step1Seconds, UserSettings.step1Range.lowerBound)
        XCTAssertEqual(result.program.settings.step2Seconds, 45)
        XCTAssertTrue(result.settingsWereClamped)
    }

    func testSettingsAreOptional() throws {
        let result = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"x","exercises":["Chin_Tucks"],"settings":{"workMinutes":30}}"#), catalogIds: ids)
        XCTAssertEqual(result.program.settings, Program.Settings(workMinutes: 30, step1Seconds: nil, step2Seconds: nil))
        let applied = result.program.applying(to: UserSettings(workMinutes: 25, step1Seconds: 40, step2Seconds: 50))
        XCTAssertEqual(applied.workMinutes, 30)
        XCTAssertEqual(applied.step1Seconds, 40, "a duration the program doesn't mention is kept")
        XCTAssertEqual(applied.step2Seconds, 50)
    }

    func testUnknownEquipmentIsDropped() throws {
        let result = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"x","exercises":["Chin_Tucks"],"equipment":["bands","jetpack","foam roll"]}"#), catalogIds: ids)
        XCTAssertEqual(result.program.equipment, ["bands", "foam roll"])
    }

    func testANewerSchemaVersionIsRefusedWithItsNumber() {
        XCTAssertThrowsError(try ProgramImport.parse(data(#"{"schemaVersion":2,"name":"x","exercises":["Chin_Tucks"]}"#), catalogIds: ids)) {
            XCTAssertEqual($0 as? ProgramImportError, .unsupportedSchemaVersion(2))
        }
    }

    func testGarbageIsRefused() {
        for text in ["not json", "[]", #"{"name":"x"}"#, #"{"schemaVersion":1,"exercises":["Chin_Tucks"]}"#] {
            XCTAssertThrowsError(try ProgramImport.parse(data(text), catalogIds: ids), text) {
                XCTAssertEqual($0 as? ProgramImportError, .notAProgram)
            }
        }
    }

    func testAnEmptyNameGetsADefaultAndALongOneIsCut() throws {
        let blank = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"  ","exercises":["Chin_Tucks"]}"#), catalogIds: ids)
        XCTAssertEqual(blank.program.name, "Program")
        let long = try ProgramImport.parse(data(#"{"schemaVersion":1,"name":"\#(String(repeating: "a", count: 200))","exercises":["Chin_Tucks"]}"#), catalogIds: ids)
        XCTAssertEqual(long.program.name.count, 80)
    }
}

final class ShippedProgramTests: XCTestCase {
    private var resources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Programs")
    }

    func testOnlyTheGeneralProgramIsShipped() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".json") }.sorted()
        XCTAssertEqual(files, ["general.json", "program.schema.json"])
    }

    func testGeneralReadsAndOnlyUsesCatalogIdsThatNeedNothing() throws {
        let general = try XCTUnwrap(ProgramLibrary(userDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)).general())
        XCTAssertEqual(general.id, "general")
        XCTAssertTrue(general.isBundled)
        XCTAssertEqual(general.importResult.unknownCount, 0, "every id of general exists in the catalog")
        XCTAssertEqual(general.program.exercises.count, 32)
        XCTAssertEqual(general.program.equipment, [])
        let byId = Dictionary(uniqueKeysWithValues: ExerciseCatalog.english.map { ($0.id, $0) })
        for id in general.program.exercises {
            XCTAssertTrue(Equipment.isAvailable(byId[id]?.equipment, owned: []), "\(id) needs equipment")
        }
        XCTAssertFalse(general.importResult.settingsWereClamped)
    }

    func testGeneralCoversNeckShouldersBackHipsAndWrists() throws {
        let general = try XCTUnwrap(ProgramLibrary(userDirectory: FileManager.default.temporaryDirectory).general())
        let byId = Dictionary(uniqueKeysWithValues: ExerciseCatalog.english.map { ($0.id, $0) })
        let muscles = Set(general.program.exercises.flatMap { byId[$0]?.primaryMuscles ?? [] })
        for needed in ["neck", "shoulders", "lower back", "middle back", "forearms"] {
            XCTAssertTrue(muscles.contains(needed), needed)
        }
    }

    func testTheSchemaMatchesTheCode() throws {
        let data = try Data(contentsOf: resources.appendingPathComponent("program.schema.json"))
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(schema["required"] as? [String], ["schemaVersion", "name", "exercises"])
        let props = try XCTUnwrap(schema["properties"] as? [String: Any])
        let equipment = try XCTUnwrap((props["equipment"] as? [String: Any])?["items"] as? [String: Any])
        XCTAssertEqual(equipment["enum"] as? [String], Equipment.ownable)
        let settings = try XCTUnwrap((props["settings"] as? [String: Any])?["properties"] as? [String: [String: Any]])
        XCTAssertEqual(settings["workMinutes"]?["minimum"] as? Int, UserSettings.workRange.lowerBound)
        XCTAssertEqual(settings["workMinutes"]?["maximum"] as? Int, UserSettings.workRange.upperBound)
        XCTAssertEqual(settings["step1Seconds"]?["minimum"] as? Int, UserSettings.step1Range.lowerBound)
        XCTAssertEqual(settings["step1Seconds"]?["maximum"] as? Int, UserSettings.step1Range.upperBound)
        XCTAssertEqual(settings["step2Seconds"]?["minimum"] as? Int, UserSettings.step2Range.lowerBound)
        XCTAssertEqual(settings["step2Seconds"]?["maximum"] as? Int, UserSettings.step2Range.upperBound)
    }

    func testGeneralSatisfiesTheSchemaRequirements() throws {
        let data = try Data(contentsOf: resources.appendingPathComponent("general.json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertFalse((object["name"] as? String ?? "").isEmpty)
        let exercises = try XCTUnwrap(object["exercises"] as? [String])
        XCTAssertEqual(Set(exercises).count, exercises.count, "uniqueItems")
        XCTAssertEqual(Set(object.keys).subtracting(["schemaVersion", "name", "settings", "exercises", "equipment"]), [], "additionalProperties")
    }

    func testTheDocumentationExampleIsAValidProgram() throws {
        let doc = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/PROGRAM.md")
        let text = try String(contentsOf: doc, encoding: .utf8)
        let start = try XCTUnwrap(text.range(of: "```json\n")?.upperBound)
        let end = try XCTUnwrap(text.range(of: "\n```", range: start..<text.endIndex)?.lowerBound)
        let result = try ProgramImport.parse(Data(text[start..<end].utf8), catalogIds: Set(ExerciseCatalog.english.map(\.id)))
        XCTAssertEqual(result.unknownCount, 0)
    }
}

final class ProgramLibraryTests: XCTestCase {
    var dir: URL!
    var library: ProgramLibrary!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-programs-\(UUID().uuidString)")
        library = ProgramLibrary(userDirectory: dir.appendingPathComponent("programs"))
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func write(_ name: String, _ json: String, in folder: URL? = nil) throws -> URL {
        let target = folder ?? dir!
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let url = target.appendingPathComponent(name)
        try Data(json.utf8).write(to: url)
        return url
    }

    func testWithoutAFolderOnlyGeneralIsThere() {
        XCTAssertTrue(library.userEntries().isEmpty)
        XCTAssertNotNil(library.entry(id: "general"))
    }

    func testImportingCopiesTheFileIntoTheProgramsFolderAndReportsWhatWasIgnored() throws {
        let source = try write("mine.json", #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks","zzz"],"equipment":["bands"]}"#)
        let entry = try library.importFile(at: source)
        XCTAssertEqual(entry.id, "mine")
        XCTAssertEqual(entry.importResult.unknownCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("programs/mine.json").path))
        XCTAssertEqual(library.userEntries().map(\.id), ["mine"])
        XCTAssertEqual(library.entry(id: "mine")?.program.exercises, ["Chin_Tucks"])
    }

    func testAnInvalidFileIsNotCopied() throws {
        let source = try write("bad.json", "nope")
        XCTAssertThrowsError(try library.importFile(at: source))
        XCTAssertTrue(library.userEntries().isEmpty)
    }

    func testAFileCalledGeneralDoesNotReplaceTheShippedProgram() throws {
        let source = try write("general.json", #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks"]}"#)
        let entry = try library.importFile(at: source)
        XCTAssertEqual(entry.id, "general-imported")
        XCTAssertEqual(library.general()?.program.name, "General")
    }

    func testTheShippedProgramComesFirstThenTheFilesByName() throws {
        let folder = dir.appendingPathComponent("programs")
        _ = try write("zeta.json", #"{"schemaVersion":1,"name":"Z","exercises":["Chin_Tucks"]}"#, in: folder)
        _ = try write("alpha.json", #"{"schemaVersion":1,"name":"A","exercises":["Chin_Tucks"]}"#, in: folder)
        _ = try write("broken.json", "{", in: folder)
        _ = try write("notes.txt", "hello", in: folder)
        XCTAssertEqual(library.entries().map(\.id), ["general", "alpha", "zeta"])
    }
}

/// A state from before the programs existed keeps what it had.
final class ProgramMigrationTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("stretchu-program-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private let oldState = #"{"schemaVersion":4,"progression":{"xp":1000,"cycles":[{"lineId":"pikachu"}]}}"#

    private func install(state: String, programs: [String: String] = [:]) throws {
        try Data(state.utf8).write(to: dir.appendingPathComponent("state.json"))
        let folder = dir.appendingPathComponent("programs")
        for (name, json) in programs {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(json.utf8).write(to: folder.appendingPathComponent(name))
        }
    }

    func testWithoutAProgramFileAnOldStateGetsGeneral() throws {
        try install(state: oldState)
        let game = StateStore(directory: dir).load()
        XCTAssertEqual(game.programId, "general")
        XCTAssertEqual(game.settings.homeEquipment, [])
    }

    func testWithAProgramFileAnOldStateImportsItAndKeepsItsEquipmentAtHome() throws {
        try install(state: oldState, programs: ["mine.json": #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks","Wall_Slides"],"equipment":["bands","foam roll"]}"#])
        let game = StateStore(directory: dir).load()
        XCTAssertEqual(game.programId, "mine")
        XCTAssertEqual(game.settings.homeEquipment, ["bands", "foam roll"])
        XCTAssertEqual(game.settings.officeEquipment, [])
    }

    func testTheMigrationDoesNotTouchTheDurations() throws {
        try install(state: #"{"schemaVersion":4,"progression":{"xp":0,"cycles":[{"lineId":"pikachu"}]},"settings":{"workMinutes":40}}"#,
                    programs: ["mine.json": #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks"],"settings":{"workMinutes":10}}"#])
        XCTAssertEqual(StateStore(directory: dir).load().settings.workMinutes, 40)
    }

    func testAStateThatAlreadyHasAProgramIsLeftAlone() throws {
        try install(state: #"{"schemaVersion":5,"progression":{"xp":0,"cycles":[{"lineId":"pikachu"}]},"programId":"general"}"#,
                    programs: ["mine.json": #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks"],"equipment":["bands"]}"#])
        let game = StateStore(directory: dir).load()
        XCTAssertEqual(game.programId, "general")
        XCTAssertEqual(game.settings.homeEquipment, [])
    }

    func testTheOldFrenchKeyedStateMigratesToo() throws {
        try install(state: #"{"schemaVersion":1,"progression":{"xp":274825,"cyclesTermines":0,"hallOfFame":[]}}"#,
                    programs: ["mine.json": #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks"],"equipment":["foam roll"]}"#])
        let game = StateStore(directory: dir).load()
        XCTAssertEqual(game.programId, "mine")
        XCTAssertEqual(game.progression.level, 65)
    }

    func testSavedAndReloadedItKeepsTheChoiceWithoutMigratingAgain() throws {
        try install(state: oldState, programs: ["mine.json": #"{"schemaVersion":1,"name":"Mine","exercises":["Chin_Tucks"],"equipment":["bands"]}"#])
        let store = StateStore(directory: dir)
        var game = store.load()
        game.programId = "general"
        game.settings.homeEquipment = []
        try store.save(game)
        let again = store.load()
        XCTAssertEqual(again.programId, "general", "the file now says schema 5: no migration")
        XCTAssertEqual(again.settings.homeEquipment, [])
    }
}
