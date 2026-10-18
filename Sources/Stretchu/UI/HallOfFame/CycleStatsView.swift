import SwiftUI

/// Figures of one cycle, opened from a Hall of Fame row. Counters live in `Cycle.stats`.
enum CycleStatsFormat {
    static func percent(_ rate: Double, locale: Locale = L10n.locale) -> String {
        rate.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    static func perDay(_ value: Double, locale: Locale = L10n.locale) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
}

struct CycleStatsView: View {
    let model: AppModel

    var body: some View {
        let rows = HallOfFame.rows(model.game.progression)
        let row = rows.first { $0.id == model.statsCycle }
        let stats = row?.cycle.stats
        let shiny = row?.cycle.shiny ?? false

        VStack(alignment: .leading, spacing: 10) {
            PageHeader(title: title(row, shiny: shiny), back: { model.go(.hallOfFame) })
            Text(subtitle(row)).panelCaption().monospacedDigit()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                metric(tr("cstats.breaks"), stats.map { "\($0.breaks)" }, "")
                metric(tr("cstats.skipRate"), stats?.skipRate.map { CycleStatsFormat.percent($0) } ?? dash,
                       stats.map { trPlural("cstats.skipped", count: $0.skips, $0.skips) } ?? "", accent: true)
                metric(tr("cstats.bestStreak"), stats.map { "\($0.bestStreak)" }, "")
                metric(tr("cstats.activeDays"), stats.map { "\($0.activeDays)" }, activeDaysOf(row))
                metric(tr("cstats.perDay"), stats?.breaksPerActiveDay.map { CycleStatsFormat.perDay($0) } ?? dash, "")
                metric(tr("cstats.bestDay"), stats.map { "\($0.bestDay)" }, stats == nil ? "" : tr("cstats.bestDayUnit"))
            }

            Text(stats == nil ? tr("cstats.none") : (row?.isCurrent == true ? tr("cstats.live") : ""))
                .font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(14)
    }

    private let dash = "–"

    private func title(_ row: HallOfFameRow?, shiny: Bool) -> String {
        guard let row else { return tr("hof.title") }
        let name = row.isCurrent ? model.species.name : (row.title?.name ?? "")
        return name + (shiny ? " ✦" : "")
    }

    private func subtitle(_ row: HallOfFameRow?) -> String {
        guard let row else { return "" }
        let cycle = row.cycle
        let range = cycle.endedAt.map { HallOfFameFormat.dateRange(start: cycle.startedAt, end: $0, calendar: model.calendar) }
            ?? cycle.startedAt.map { HallOfFameFormat.since($0) } ?? ""
        guard let days = cycle.days(calendar: model.calendar, now: model.clock.now) else { return range }
        return "\(range) · \(tr("hof.days", days + 1))"
    }

    /// "of 12": the days the cycle spans, both ends included.
    private func activeDaysOf(_ row: HallOfFameRow?) -> String {
        guard row?.cycle.stats != nil, let days = row?.cycle.days(calendar: model.calendar, now: model.clock.now) else { return "" }
        return tr("cstats.ofDays", days + 1)
    }

    private func metric(_ label: String, _ value: String?, _ detail: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.55)).lineLimit(1).minimumScaleFactor(0.8)
            Text(value ?? dash).font(.system(size: 24, weight: .semibold)).monospacedDigit()
                .foregroundStyle(accent ? Color.accentColor : .white)
            Text(detail.isEmpty ? " " : detail).font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.4)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).card(radius: Radius.card)
    }
}
