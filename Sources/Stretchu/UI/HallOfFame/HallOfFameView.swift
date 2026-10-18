import SwiftUI

/// Dates of a Hall of Fame row: "15 → 26 sept.", "29 sept. → 9 oct.", "→ 1 juil." when the
/// start is unknown.
enum HallOfFameFormat {
    static func dateRange(start: Date?, end: Date, calendar: Calendar = .current, locale: Locale = L10n.locale) -> String {
        func day(_ d: Date) -> String { d.formatted(.dateTime.day().locale(locale)) }
        func dayMonth(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated).locale(locale)) }
        guard let start else { return tr("hof.dateRange", "", dayMonth(end)).trimmingCharacters(in: .whitespaces) }
        let a = calendar.dateComponents([.year, .month], from: start), b = calendar.dateComponents([.year, .month], from: end)
        if a == b {
            let month = end.formatted(.dateTime.month(.abbreviated).locale(locale))
            return "\(tr("hof.dateRange", day(start), day(end))) \(month)"
        }
        return tr("hof.dateRange", dayMonth(start), dayMonth(end))
    }

    static func since(_ start: Date, locale: Locale = L10n.locale) -> String {
        tr("hof.since", start.formatted(.dateTime.day().month(.abbreviated).locale(locale)))
    }
}

/// The Hall of Fame: a page of the menu panel with two tabs, the cycles and the Pokédex.
struct HallOfFameView: View {
    enum Tab: Hashable { case history, pokedex }

    let model: AppModel
    @State private var tab: Tab = .history

    var body: some View {
        let progression = model.game.progression
        let summary = HallOfFame.summary(progression)

        VStack(alignment: .leading, spacing: 10) {
            PageHeader(title: tr("hof.title"), back: { model.back() })

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tr("hof.pokedex")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Text("\(summary.pokedex.obtained)").font(.system(size: 22, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                    Text("/ \(summary.pokedex.total)").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.55)).monospacedDigit()
                }
                ProgressBar(value: summary.pokedex.total == 0 ? 0 : Double(summary.pokedex.obtained) / Double(summary.pokedex.total))
                Text(trPlural("hof.summary", count: summary.cycles, summary.linesCompleted, summary.linesTotal, summary.cycles))
                    .panelCaption().monospacedDigit()
            }
            .padding(10).card(radius: Radius.card)

            Segments(values: [Tab.history, Tab.pokedex], selection: tab,
                     label: { $0 == .history ? tr("hof.tab.history") : tr("hof.tab.pokedex") }, onSelect: { tab = $0 })

            switch tab {
            case .history: history(progression)
            case .pokedex: pokedex(progression)
            }
        }
        .padding(14)
    }

    // MARK: history

    private func history(_ progression: Progression) -> some View {
        let rows = HallOfFame.rows(progression)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(rows) { row in historyRow(row, progression: progression) }
                if rows.count == 1 {
                    Text(tr("hof.empty")).freeCaption().padding(.top, 6)
                }
            }
            .padding(1)
        }
        .frame(height: 400)
    }

    private func historyRow(_ row: HallOfFameRow, progression: Progression) -> some View {
        let shiny = row.cycle.shiny
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        if row.isCurrent {
                            SpriteSheetView(sprite: SpriteRef(dex: model.species.dex, shiny: shiny), animation: "Idle",
                                            boxWidth: 56, boxHeight: 48)
                        } else {
                            ForEach(row.species, id: \.dex) { species in
                                SpeciesSprite(dex: species.dex, shiny: shiny, boxWidth: 36, boxHeight: 40)
                            }
                        }
                    }
                    .frame(minWidth: 56, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        if row.isCurrent {
                            Text(tr("hof.current", model.species.name, progression.level) + (shiny ? " ✦" : ""))
                                .font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            Text(row.cycle.startedAt.map { HallOfFameFormat.since($0) } ?? "").panelCaption()
                        } else {
                            Text((row.title?.name ?? "") + (shiny ? " ✦" : "")).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Text(row.cycle.endedAt.map { HallOfFameFormat.dateRange(start: row.cycle.startedAt, end: $0, calendar: model.calendar) } ?? "")
                                .panelCaption().monospacedDigit()
                        }
                        Text(row.species.map { "#\(String(format: "%03d", $0.dex))" }.joined(separator: " "))
                            .font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.4)).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                    if !row.isCurrent, let days = row.cycle.days(calendar: model.calendar, now: model.clock.now) {
                        Text(tr("hof.days", days)).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6)).monospacedDigit()
                    }
                }
                if row.isCurrent {
                    Button(tr("hof.abandonLink")) { model.go(.abandon) }.buttonStyle(.text).padding(.leading, -6)
                }
            }
            // Outside the content column: centered on the whole row, whatever its height.
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white.opacity(row.isCurrent ? 0.1 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(row.isCurrent ? Color.accentColor : .clear, lineWidth: 1.5))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card))
        .onTapGesture { model.openCycleStats(row.id) }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Pokédex

    private func pokedex(_ progression: Progression) -> some View {
        let obtained = Pokedex.obtainedDexes(progression.cycles)
        let shiny = Pokedex.shinyDexes(progression.cycles)
        return VStack(spacing: 4) {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                    ForEach(1...151, id: \.self) { dex in
                        let has = obtained.contains(dex)
                        VStack(spacing: 1) {
                            SpeciesSprite(dex: dex, shiny: shiny.contains(dex), silhouette: !has, boxWidth: 38, boxHeight: 32, fill: true)
                                .frame(width: 44, height: 36)
                            Text(String(format: "%03d", dex)).font(.system(size: 9.5))
                                .foregroundStyle(Color.white.opacity(has ? 0.7 : 0.3)).monospacedDigit()
                        }
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color.white.opacity(has ? 0.08 : 0.03)))
                        .overlay(alignment: .topLeading) {
                            if shiny.contains(dex) { Text("✦").font(.system(size: 9)).foregroundStyle(Color.accentColor).padding(2) }
                        }
                    }
                }
                .padding(1)
            }
            .frame(height: 380)
            Text(tr("hof.scroll")).font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.4))
        }
    }
}
