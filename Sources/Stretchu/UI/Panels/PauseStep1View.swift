import SwiftUI

/// Step 1 of 2: the warm-up, three things to do, no click. Laid out like the exercise (step 2):
/// the same header, title, numbered steps and countdown.
struct PauseStep1View: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("break1.header")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                StepsIndicator(step: 1, width: 18, inactive: 0.35)
            }

            HStack(spacing: 12) {
                SpriteBox(sprite: model.sprite, moment: .break1)
                Text(tr("break1.title"))
                    .font(.system(size: 17, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(["break1.stand", "break1.sip", "break1.look"].enumerated()), id: \.offset) { index, key in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)").fontWeight(.semibold).foregroundStyle(Color.accentColor).monospacedDigit()
                        Text(tr(key)).fixedSize(horizontal: false, vertical: true).lineSpacing(2)
                    }
                    .font(.system(size: 13))
                }
            }

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.countdown(model.scheduler.remaining))
                        .font(.system(size: 30, weight: .semibold)).monospacedDigit()
                    Spacer()
                    Text(tr("break1.hint")).panelCaption()
                    Button { model.skipStep1() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tr("break1.skip"))
                    .accessibilityLabel(tr("break1.skip"))
                }
                ProgressBar(value: model.scheduler.stepFraction)
            }
        }
        .padding(14)
        .frame(width: PanelSize.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.white)
    }
}
