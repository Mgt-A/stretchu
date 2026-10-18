import SwiftUI

/// `C · Companion and leveling`: tall panel.
struct CompanionView: View {
    let model: AppModel
    /// Back arrow: returns to the menu, or closes the panel opened from Level up.
    let back: () -> Void

    var body: some View {
        let p = model.game.progression
        let streak = model.game.streak
        let mood = model.mood
        let species = model.species

        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: tr("companion.title"), back: back)

            HStack(alignment: .center, spacing: 14) {
                SpriteBox(sprite: model.sprite, moment: .companion(mood), width: 100, height: 120, radius: Radius.card, scale: 2, speed: 0.5)
                VStack(alignment: .leading, spacing: 6) {
                    Text(species.name).font(.system(size: 20, weight: .semibold))
                    Text(tr("companion.level", p.level)).font(.system(size: 13, weight: .medium)).monospacedDigit()
                    bar(p.fractionToNextLevel, height: 6)
                    Text(xpLine(p)).panelCaption().monospacedDigit()
                }
            }

            chain(p)
            multiplier(streak)
            week(streak)

            Divider().opacity(0.4)
            Button { model.go(.hallOfFame) } label: {
                HStack {
                    Text(tr("companion.cycles")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Text("\(p.completedCycles)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.white.opacity(0.55))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: PanelSize.width, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    private func xpLine(_ p: Progression) -> String {
        guard let next = p.nextLevelXP else { return "\(Format.xp(p.xp)) XP" }
        return "\(Format.xp(p.xp)) / \(Format.xp(next)) XP"
    }

    private func bar(_ value: Double, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2).fill(Color.white.opacity(0.14))
                RoundedRectangle(cornerRadius: height / 2).fill(Color.accentColor)
                    .frame(width: geo.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
    }

    // MARK: evolution chain

    private func chain(_ p: Progression) -> some View {
        HStack(spacing: 6) {
            ForEach(model.game.line.chain(branchDex: model.game.pokemon.branchDex), id: \.dex) { stage in
                let reached = p.level >= stage.level
                let current = stage == model.species
                VStack(spacing: 2) {
                    sprite(stage, silhouette: !reached)
                        .frame(height: 60)
                    Text(stage.name)
                        .font(.system(size: 12, weight: current ? .semibold : .regular))
                        .foregroundStyle(current ? Color.white : Color.white.opacity(0.6))
                    Text(subtitle(stage, current: current, reached: reached))
                        .font(.system(size: 11)).foregroundStyle(Color.white.opacity(current ? 0.6 : 0.45))
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.white.opacity(current ? 0.12 : 0.06)))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(current ? Color.accentColor : .clear, lineWidth: 1.5))
            }
        }
    }

    /// First Idle frame at ×1, no smoothing; silhouette until the species is reached.
    @ViewBuilder
    private func sprite(_ species: Species, silhouette: Bool) -> some View {
        if let cg = SpriteLibrary.idleFrame(SpriteRef(dex: species.dex, shiny: model.game.pokemon.shiny)) {
            Image(decorative: cg, scale: 1)
                .interpolation(.none)
                .brightness(silhouette ? -1 : 0)
                .opacity(silhouette ? 0.45 : 1)
        }
    }

    private func subtitle(_ stage: Species, current: Bool, reached: Bool) -> String {
        if current { return tr("companion.stage.current", stage.level) }
        return reached ? tr("companion.stage.reached", stage.level) : tr("companion.stage.locked", stage.level)
    }

    // MARK: multiplier

    private func multiplier(_ streak: Streak) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("companion.multiplier")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text(Format.multiplier(streak.multiplier))
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.accentColor).monospacedDigit()
            }
            bar(Double(min(streak.count, XPRules.streakAtMaxMultiplier)) / Double(XPRules.streakAtMaxMultiplier), height: 6)
            HStack {
                Text("×1")
                Spacer()
                Text(trPlural("companion.streak", count: streak.count, streak.count))
                Spacer()
                Text(tr("companion.maxAtStreak"))
            }
            .panelCaption().monospacedDigit()
            Text(tr("companion.rule"))
                .font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .card()
    }

    // MARK: days of the week

    private func week(_ streak: Streak) -> some View {
        let days = streak.week(now: model.clock.now, calendar: model.calendar, days: model.game.settings.schedule.days)
        let n = streak.breaksToday
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("companion.days")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text(n >= Streak.breaksPerDayToKeep
                     ? tr("companion.today.done", n)
                     : tr("companion.today.progress", n, Streak.breaksPerDayToKeep))
                    .font(.system(size: 12)).monospacedDigit()
            }
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 4) {
                        dayCell(day.state).frame(height: 22)
                        Text(day.letter).font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ state: WeekdayCell.State) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control)
        switch state {
        case .met: shape.fill(Color.accentColor)
        case .missed: shape.fill(Color.white.opacity(0.14))
        case .today: shape.fill(Color.white.opacity(0.1)).overlay(shape.stroke(Color.accentColor, lineWidth: 1.5))
        case .upcoming, .weekend: shape.stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
}
