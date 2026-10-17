import SwiftUI

/// `C · Wake-up`: short panel, 3 actions.
struct WakeUpView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                SpriteBox(sprite: model.sprite, moment: .wakeUp)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(tr("wake.header"))
                        Spacer(minLength: 4)
                        Text(tr("wake.now"))
                    }
                    .panelCaption()
                    Text(tr("wake.title")).panelTitle()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                step("1", tr("wake.step1", "\(model.game.settings.step1Seconds)"))
                step("2", tr("wake.step2", model.exercise.name, "\(model.game.settings.step2Seconds)"))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: 10, opacity: 0.06)

            HStack(spacing: 8) {
                Button(tr("wake.start")) { model.start() }
                    .buttonStyle(.primary).fixedSize()
                Button(tr("wake.snooze")) { model.snooze() }
                    .buttonStyle(.secondary).fixedSize()
                    .disabled(!model.scheduler.canSnooze)
                Spacer(minLength: 0)
                Button(tr("wake.skip")) { model.skip() }.buttonStyle(.text)
            }

            HStack {
                Text("+\(Format.xp(model.expectedBreakXP)) XP · \(Format.multiplier(model.game.streak.multiplier))")
                Spacer()
                Text(tr("wake.mode", model.mode.name))
            }
            .panelCaption().monospacedDigit()
        }
        .padding(14)
        .frame(width: PanelSize.width, height: PanelSize.short.height, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(number).fontWeight(.semibold).foregroundStyle(Color.accentColor).monospacedDigit()
            Text(text).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.system(size: 13))
    }
}
