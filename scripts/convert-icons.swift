// Converts the Tabler SVG icons of Resources/Icons to PDF (vector, loaded by every macOS the app
// supports, where loading an SVG is not guaranteed). The app only reads the PDFs; the SVGs stay as
// the source. Run from the repository root:  swift scripts/convert-icons.swift
import AppKit

let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/Icons")
let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension == "svg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else { fputs("No SVG in Resources/Icons\n", stderr); exit(1) }

for url in files {
    // The icons draw with `currentColor`: black here, the app tints the template image.
    guard let text = try? String(contentsOf: url, encoding: .utf8),
          let image = NSImage(data: Data(text.replacingOccurrences(of: "currentColor", with: "#000000").utf8))
    else { fputs("Cannot read \(url.lastPathComponent)\n", stderr); exit(1) }
    var box = CGRect(x: 0, y: 0, width: 24, height: 24)
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &box, nil)
    else { exit(1) }
    context.beginPDFPage(nil)
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    image.draw(in: box)
    NSGraphicsContext.restoreGraphicsState()
    context.endPDFPage()
    context.closePDF()
    let out = url.deletingPathExtension().appendingPathExtension("pdf")
    try data.write(to: out)
    print("\(url.lastPathComponent) -> \(out.lastPathComponent) (\(data.length) bytes)")
}
