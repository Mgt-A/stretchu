// Implementation of scripts/fetch-sprites.sh. Run from the repository root.
import Foundation

// Idle, Hop and Sleep exist for (almost) every species and drive the mood and the level up: a line
// without them is dropped. Eat, DeepBreath and LookUp only exist for about 27 species of the 151:
// they are downloaded when present, and the app falls back to Idle otherwise.
// A hovering species (Beedrill, Dragonair…) has no Idle sheet: its Walk stands for it.
let required = ["Hop", "Sleep"]
let optional = ["Idle", "Walk", "Eat", "DeepBreath", "LookUp", "Pose"]
let spriteCollab = "https://raw.githubusercontent.com/PMDCollab/SpriteCollab"
let pokeAPISprites = "https://raw.githubusercontent.com/PokeAPI/sprites"

struct Species { let dex: Int; var folder: String { String(format: "%04d", dex) } }

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let out = root.appendingPathComponent("Resources/Sprites")

// MARK: lines.json

guard let data = try? Data(contentsOf: root.appendingPathComponent("Resources/lines.json")),
      let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let commit = doc["spriteCollabCommit"] as? String,
      let itemsCommit = doc["pokeApiSpritesCommit"] as? String,
      let lines = doc["lines"] as? [[String: Any]]
else { fputs("Cannot read Resources/lines.json\n", stderr); exit(1) }

struct LineInfo { let id: String; let dexes: [Int]; let stones: [String] }
let lineInfos: [LineInfo] = lines.map { line in
    var dexes = (line["species"] as? [[String: Any]] ?? []).compactMap { $0["dex"] as? Int }
    var stones: [String] = []
    if let branch = line["branch"] as? [String: Any], let options = branch["options"] as? [[String: Any]] {
        dexes += options.compactMap { $0["dex"] as? Int }
        stones = options.compactMap { $0["stone"] as? String }
    }
    return LineInfo(id: line["id"] as? String ?? "?", dexes: dexes, stones: stones)
}
let allDexes = Array(Set(lineInfos.flatMap(\.dexes))).sorted()
let allStones = Array(Set(lineInfos.flatMap(\.stones))).sorted()

// MARK: downloading

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}

/// Downloads `url` to `destination` unless it is already there. false: not found (404) or failed.
func download(_ url: String, to destination: URL) -> Bool {
    if fm.fileExists(atPath: destination.path) { return true }
    guard let u = URL(string: url) else { return false }
    for attempt in 0..<3 {
        let done = DispatchSemaphore(value: 0)
        var result: Bool?
        var body: Data?
        URLSession.shared.dataTask(with: u) { data, response, _ in
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200, let data { body = data; result = true }
                else if http.statusCode == 404 { result = false }
            }
            done.signal()
        }.resume()
        done.wait()
        if result == true, let body {
            try? fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let part = destination.appendingPathExtension("part")
            do { try body.write(to: part); try? fm.removeItem(at: destination); try fm.moveItem(at: part, to: destination) }
            catch { return false }
            return true
        }
        if result == false { return false }
        Thread.sleep(forTimeInterval: Double(attempt + 1))
    }
    return false
}

func parallel<T>(_ items: [T], _ work: @escaping (T) -> Void) {
    let counter = Counter()
    DispatchQueue.concurrentPerform(iterations: min(8, max(1, items.count))) { _ in
        while true {
            let i = counter.next() - 1
            if i >= items.count { return }
            work(items[i])
        }
    }
}

// MARK: species

final class Results: @unchecked Sendable {
    private let lock = NSLock()
    var missing: [Int: String] = [:]
    var shiny: Set<Int> = []
    func fail(_ dex: Int, _ file: String) { lock.lock(); missing[dex] = file; lock.unlock() }
    func addShiny(_ dex: Int) { lock.lock(); shiny.insert(dex); lock.unlock() }
}
let results = Results()

let requiredFiles = ["AnimData.xml"] + required.map { "\($0)-Anim.png" }
let optionalFiles = optional.map { "\($0)-Anim.png" }
print("Downloading \(allDexes.count) species from SpriteCollab \(commit.prefix(7))…")

parallel(allDexes) { dex in
    let sp = Species(dex: dex)
    let base = "\(spriteCollab)/\(commit)/sprite/\(sp.folder)"
    let dir = out.appendingPathComponent("pmd/\(sp.folder)")
    for file in requiredFiles where !download("\(base)/\(file)", to: dir.appendingPathComponent(file)) {
        results.fail(dex, file)
        try? fm.removeItem(at: dir)
        return
    }
    for file in optionalFiles { _ = download("\(base)/\(file)", to: dir.appendingPathComponent(file)) }
    guard fm.fileExists(atPath: dir.appendingPathComponent("Idle-Anim.png").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("Walk-Anim.png").path) else {
        results.fail(dex, "Idle-Anim.png or Walk-Anim.png")
        try? fm.removeItem(at: dir)
        return
    }
    _ = download("\(base)/credits.txt", to: dir.appendingPathComponent("credits.txt"))

    // Shiny: form 0000, shiny 0001. Only kept when complete.
    let shinyBase = "\(base)/0000/0001"
    let shinyDir = dir.appendingPathComponent("shiny")
    var complete = true
    for file in requiredFiles where !download("\(shinyBase)/\(file)", to: shinyDir.appendingPathComponent(file)) {
        complete = false
        break
    }
    if complete {
        for file in optionalFiles { _ = download("\(shinyBase)/\(file)", to: shinyDir.appendingPathComponent(file)) }
        complete = fm.fileExists(atPath: shinyDir.appendingPathComponent("Idle-Anim.png").path)
            || fm.fileExists(atPath: shinyDir.appendingPathComponent("Walk-Anim.png").path)
    }
    if complete {
        _ = download("\(shinyBase)/credits.txt", to: shinyDir.appendingPathComponent("credits.txt"))
        results.addShiny(dex)
    } else {
        try? fm.removeItem(at: shinyDir)
    }
}

// MARK: prune the species of dropped lines

let keptEarly = Set(lineInfos.filter { line in
    !line.dexes.contains { results.missing[$0] != nil }
}.flatMap(\.dexes))
if let folders = try? fm.contentsOfDirectory(atPath: out.appendingPathComponent("pmd").path) {
    for folder in folders where !(Int(folder).map(keptEarly.contains) ?? false) {
        try? fm.removeItem(at: out.appendingPathComponent("pmd/\(folder)"))
    }
}

// MARK: evolution stones

var missingStones: Set<String> = []
for stone in allStones {
    let url = "\(pokeAPISprites)/\(itemsCommit)/sprites/items/\(stone).png"
    if !download(url, to: out.appendingPathComponent("items/\(stone).png")) { missingStones.insert(stone) }
}

// MARK: lines kept or dropped

var kept: [LineInfo] = []
for line in lineInfos {
    if let dex = line.dexes.first(where: { results.missing[$0] != nil }) {
        print("Line dropped: \(line.id) (species \(Species(dex: dex).folder) has no \(results.missing[dex]!))")
    } else if let stone = line.stones.first(where: { missingStones.contains($0) }) {
        print("Line dropped: \(line.id) (no sprite for \(stone))")
    } else {
        kept.append(line)
    }
}

// MARK: credits (credits.txt of each downloaded folder, names from credit_names.txt)

let namesFile = out.appendingPathComponent("credit_names.txt")
_ = download("\(spriteCollab)/\(commit)/credit_names.txt", to: namesFile)
var contacts: [String: String] = [:]   // author key -> contact URL ("" if none)
var displayNames: [String: String] = [:]
if let text = try? String(contentsOf: namesFile, encoding: .utf8) {
    for row in text.split(separator: "\n").dropFirst() {
        let cols = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard let name = cols.first, !name.isEmpty else { continue }
        // credits.txt files name an author by name or by Discord id: both lead to the name.
        for key in [name] + (cols.count > 1 && !cols[1].isEmpty ? [cols[1]] : []) {
            displayNames[key] = name
            if cols.count > 2, cols[2].hasPrefix("http") { contacts[key] = cols[2] }
        }
    }
}
let keptDexes = Set(kept.flatMap(\.dexes))
var bySpecies: [String: [String]] = [:]
var everyone = Set<String>()
for dex in keptDexes.sorted() {
    let folder = Species(dex: dex).folder
    var authors = Set<String>()
    for sub in ["", "shiny/"] {
        let url = out.appendingPathComponent("pmd/\(folder)/\(sub)credits.txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
        for row in text.split(separator: "\n") {
            let cols = row.split(separator: "\t", omittingEmptySubsequences: false)
            if cols.count > 1 { authors.insert(String(cols[1])) }
        }
    }
    bySpecies[folder] = Set(authors.map { displayNames[$0] ?? $0 }).sorted()
    everyone.formUnion(authors.map { displayNames[$0] ?? $0 })
}
let artists = everyone.sorted { $0.lowercased() < $1.lowercased() }.map { key -> [String: String] in
    var entry = ["name": displayNames[key] ?? key]
    if let contact = contacts[key] { entry["contact"] = contact }
    return entry
}
let credits: [String: Any] = [
    "source": "https://github.com/PMDCollab/SpriteCollab", "license": "CC BY-NC 4.0",
    "commit": commit, "artists": artists, "bySpecies": bySpecies,
]
let creditsData = try JSONSerialization.data(withJSONObject: credits, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try creditsData.write(to: out.appendingPathComponent("credits.json"))

// MARK: marker

let shinyCount = results.shiny.intersection(keptDexes).count
let marker = "SpriteCollab \(commit)\nPokeAPI/sprites \(itemsCommit)\n"
try marker.write(to: out.appendingPathComponent(".fetched"), atomically: true, encoding: .utf8)
print("Sprites up to date: \(kept.count) of \(lineInfos.count) lines, \(keptDexes.count) species (\(shinyCount) with a shiny), \(artists.count) artists credited.")
