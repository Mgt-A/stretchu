import AppKit
import SwiftUI

/// The random draw, about four seconds: silhouettes scroll and slow down, the one that came out
/// flashes black and white, the panel flashes, then the Pokémon appears in color. A click anywhere
/// skips to the end; with "reduce motion" it goes straight to the end. The result is final: the
/// only button is "Let's go".
struct RandomDrawView: View {
    let draw: RandomPick.Draw
    let onGo: () -> Void

    private enum Phase { case scrolling, flashing, revealed }

    @State private var phase = Phase.scrolling
    @State private var shownLine: PokemonLine?
    @State private var white = false
    @State private var flash = false
    @State private var run: Task<Void, Never>?

    private var result: PokemonLine { LineCatalog.line(id: draw.lineId) ?? .pikachu }
    private var revealed: Bool { phase == .revealed }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(subtitle).freeCaption().multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                arena.frame(width: 160, height: 130).padding(.vertical, 6)
                Text(revealed ? result.base.name + (draw.shiny ? " ✦" : "") : tr("random.unknown"))
                    .font(.system(size: 15, weight: .semibold))
                Text(revealed ? "#\(String(format: "%03d", result.base.dex))" : " ")
                    .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.45)).monospacedDigit()
                Spacer(minLength: 0)
                Button(tr("random.go")) { onGo() }
                    .buttonStyle(.primary).keyboardShortcut(.defaultAction)
                    .opacity(revealed ? 1 : 0).disabled(!revealed)
            }
            .padding(14)
            Rectangle().fill(Color.white).opacity(flash ? 1 : 0).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !revealed { skip() } }
        .foregroundStyle(.white)
        .onAppear { start() }
        .onDisappear { run?.cancel() }
    }

    private var title: String {
        switch phase {
        case .scrolling, .flashing: tr("random.title")
        case .revealed: draw.shiny ? tr("random.shiny") : tr("random.revealed")
        }
    }

    private var subtitle: String {
        switch phase {
        case .scrolling, .flashing: tr("random.waiting")
        case .revealed: draw.shiny ? tr("random.shinyBody") : tr("random.revealedBody")
        }
    }

    @ViewBuilder private var arena: some View {
        if revealed {
            SpriteSheetView(sprite: SpriteRef(dex: result.base.dex, shiny: draw.shiny), animation: "Idle",
                            boxWidth: 160, boxHeight: 130, scale: 4, margin: 0)
        } else if let line = shownLine {
            SpeciesSprite(dex: line.base.dex, boxWidth: 160, boxHeight: 130, flatColor: white ? .white : .black, scale: 4)
        } else {
            Color.clear
        }
    }

    private func start() {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            phase = .revealed
            return
        }
        run = Task { await play() }
    }

    private func skip() {
        run?.cancel()
        flash = false
        phase = .revealed
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func play() async {
        // Scrolling: more and more slowly, 1.6 s at least.
        var gap = 0.06, elapsed = 0.0
        for id in draw.reel {
            shownLine = LineCatalog.line(id: id)
            await pause(gap)
            if Task.isCancelled { return }
            elapsed += gap
            gap = min(0.26, gap * 1.18)
        }
        if elapsed < 1.6 { await pause(1.6 - elapsed) }
        // The line that came out, black and white, faster and faster.
        shownLine = result
        white = false
        var interval = 0.32, spent = 0.0
        while spent < 1.8 {
            white.toggle()
            await pause(interval)
            if Task.isCancelled { return }
            spent += interval
            interval = max(0.04, interval * 0.78)
        }
        white = true
        phase = .flashing
        withAnimation(.easeIn(duration: 0.18)) { flash = true }
        await pause(0.22)
        if Task.isCancelled { return }
        phase = .revealed
        withAnimation(.easeOut(duration: 0.4)) { flash = false }
    }
}

/// The "Random" cell at the head of a Pokémon grid.
struct RandomTile: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("?").font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.accentColor)
                .frame(width: 64, height: 48)
            Text(tr("random.tile")).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.8)
            Text(tr("random.tile.caption")).font(.system(size: 10.5)).foregroundStyle(Color.accentColor).lineLimit(1)
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card))
    }
}
