import AppKit
import SwiftUI

/// Alternates an exercise's two images every 1.2 s.
/// Without images: nothing, the caller shows the steps only.
struct ExerciseMediaView: View {
    let images: [String]
    var interval: TimeInterval = 1.2

    var body: some View {
        let loaded = images.compactMap(Self.load)
        if loaded.count == 2 {
            TimelineView(.periodic(from: .now, by: interval)) { context in
                let index = Int(context.date.timeIntervalSinceReferenceDate / interval) % 2
                ZStack {
                    ForEach(0..<2, id: \.self) { i in
                        Image(nsImage: loaded[i])
                            .resizable()
                            .scaledToFill()
                            .opacity(index == i ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5), value: index)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor
    private static func load(_ path: String) -> NSImage? {
        if let known = cache[path] { return known }
        guard let url = AppResources.url("Exercises/\(path)"), let image = NSImage(contentsOf: url) else { return nil }
        cache[path] = image
        return image
    }
}
