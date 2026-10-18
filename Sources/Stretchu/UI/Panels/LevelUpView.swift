import SwiftUI

/// `C · Level up`: panel fitted to its content, closes by itself after 8 s.
struct LevelUpView: View {
    let model: AppModel

    var body: some View {
        let gain = model.levelUp
        let progression = model.game.progression
        HStack(alignment: .top, spacing: 14) {
            SpriteBox(sprite: model.sprite, moment: .levelUp)
            VStack(alignment: .leading, spacing: 6) {
                if gain?.candyEarned == true {
                    HStack(spacing: 4) {
                        if let candy = SpriteLibrary.stoneImage("rare-candy") {
                            Image(decorative: candy, scale: 1).interpolation(.none).resizable().frame(width: 16, height: 16)
                        }
                        Text(tr("levelup.candy")).panelCaption().foregroundStyle(Color.accentColor)
                    }
                } else {
                    Text(tr("levelup.header")).panelCaption()
                }
                Text(title(gain))
                    .font(.system(size: 22, weight: .bold)).monospacedDigit().lineLimit(1)
                Text(sentence(gain))
                    .font(.system(size: 13)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                ProgressBar(value: progression.fractionToNextLevel)
                Text(next(progression)).panelCaption().monospacedDigit().minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    Button(tr("levelup.see", model.species.name)) { model.showCompanion() }
                        .buttonStyle(.primary).fixedSize()
                    Button(tr("levelup.close")) { model.closeLevelUp() }.buttonStyle(.secondary).fixedSize()
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(width: PanelSize.width, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    private func title(_ gain: LevelUp?) -> String {
        guard let gain else { return tr("levelup.title.fallback") }
        return gain.cycleCompleted ? tr("levelup.title.cycle") : tr("levelup.title.level", gain.level)
    }

    private func sentence(_ gain: LevelUp?) -> String {
        guard let gain else { return "" }
        let xp = "+\(Format.xp(gain.xpGained)) XP"
        if gain.cycleCompleted {
            return tr("levelup.sentence.cycle", gain.finalSpecies?.name ?? gain.species.name, gain.species.name, xp)
        }
        if gain.newSpecies {
            let before = model.game.line.species(atLevel: gain.level - 1, branchDex: model.game.pokemon.branchDex)
            return tr("levelup.sentence.evolved", before.name, gain.species.name, xp)
        }
        return tr("levelup.sentence.level", gain.species.name, xp)
    }

    private func next(_ p: Progression) -> String {
        guard let next = p.nextLevelXP else { return tr("levelup.maxReached", Progression.maxLevel) }
        let line = model.game.line
        let branchDex = model.game.pokemon.branchDex
        let goal: String
        if let upcoming = line.chain(branchDex: branchDex).first(where: { $0.level > p.level }) {
            goal = tr("levelup.goal.evolve", upcoming.name, upcoming.level)
        } else if let branch = line.branch, branchDex == nil, p.level < branch.level {
            goal = tr("levelup.goal.branch", branch.level)
        } else {
            goal = tr("levelup.goal.hallOfFame", Progression.maxLevel)
        }
        return tr("levelup.next", p.level + 1, Format.xp(next), goal)
    }
}
