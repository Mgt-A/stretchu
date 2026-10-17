import XCTest

/// The public repository holds code, build and user or contributor docs only: no pointer to
/// private design documents, no personal condition named in the code.
final class PublicTreeTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // Assembled so that this file does not contain them.
    private let forbidden = ["SP" + "EC", "PLAN" + ".md", "ma" + "quette", "Tie" + "tze"]

    private func textFiles() -> [URL] {
        var urls: [URL] = []
        let fm = FileManager.default
        for dir in ["Sources", "Tests", "scripts", "Resources", "skill"] {
            guard let walker = fm.enumerator(at: root.appendingPathComponent(dir), includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
            for case let url as URL in walker {
                let path = url.path
                if path.contains("/Resources/Sprites/") || path.contains("/Tests/Fixtures/") { continue }
                guard ["swift", "strings", "json", "sh", "py", "md", "xml"].contains(url.pathExtension) else { continue }
                urls.append(url)
            }
        }
        for name in ["README.md", "CREDITS.md", "CONTRIBUTING.md", "Makefile", "Package.swift", "Info.plist"] {
            urls.append(root.appendingPathComponent(name))
        }
        return urls.filter { fm.fileExists(atPath: $0.path) && $0.lastPathComponent != "PublicTreeTests.swift" }
    }

    func testNoFileMentionsAPrivateDocumentOrAPersonalCondition() throws {
        for url in textFiles() {
            let text = try String(contentsOf: url, encoding: .utf8)
            for word in forbidden where text.contains(word) {
                XCTFail("\(url.path.replacingOccurrences(of: root.path + "/", with: "")) contains \"\(word)\"")
            }
        }
    }

    func testTestFilesAreNamedAfterAFeature() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Tests/StretchuTests").path)
        for name in names {
            for bad in ["Increment", "Retours", "V1", "V2"] {
                XCTAssertFalse(name.contains(bad), "\(name) is named after an increment, not a feature")
            }
        }
    }

    func testContributingDescribesTheArchitecture() throws {
        let text = try String(contentsOf: root.appendingPathComponent("CONTRIBUTING.md"), encoding: .utf8)
        for needle in ["## Architecture", "Engine", "Game", "Data", "UI", "lines.json", "make demo", "swift test"] {
            XCTAssertTrue(text.contains(needle), needle)
        }
    }
}
