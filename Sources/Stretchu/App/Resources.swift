import AppKit

/// Locates resources: in the assembled app (Contents/Resources),
/// otherwise in the repository's Resources/ folder (swift run, swift test).
enum AppResources {
    static func url(_ relativePath: String) -> URL? {
        let fm = FileManager.default
        var roots: [URL] = []
        if let bundled = Bundle.main.resourceURL { roots.append(bundled) }
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        roots.append(cwd.appendingPathComponent("Resources"))
        for root in roots {
            let candidate = root.appendingPathComponent(relativePath)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}
