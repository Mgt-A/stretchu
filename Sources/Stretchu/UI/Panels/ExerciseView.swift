import SwiftUI

/// `C · Exercise 30 s`: tall panel.
struct ExerciseView: View {
    let model: AppModel

    var body: some View {
        let exercise = model.exercise
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("exercise.header")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                StepsIndicator(step: 2, width: 18, inactive: 0.35)
            }

            ZStack(alignment: .bottomTrailing) {
                if exercise.images.isEmpty {
                    SpriteSheetView(sprite: model.sprite, animation: Moment.break2.animation, boxWidth: 100, boxHeight: 120, scale: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ExerciseMediaView(images: exercise.images)
                }
                // The overlay sprite only makes sense on an illustration: without one, the big
                // sprite in the middle is enough (no duplicate).
                if !exercise.images.isEmpty {
                    SpriteBox(sprite: model.sprite, moment: .break2, radius: Radius.card)
                        .padding(8)
                }
            }
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    Text([model.mode.name, Equipment.label(exercise.equipment)].compactMap { $0 }.joined(separator: " · "))
                        .panelCaption()
                    Text(tr("exercise.badge"))
                        .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.7))
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)").fontWeight(.semibold).foregroundStyle(Color.accentColor).monospacedDigit()
                        Text(step).fixedSize(horizontal: false, vertical: true).lineSpacing(2)
                    }
                    .font(.system(size: 13))
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.countdown(model.scheduler.remaining))
                        .font(.system(size: 30, weight: .semibold)).monospacedDigit()
                    Spacer()
                    Text(tr("exercise.xpAtEnd", Format.xp(model.expectedBreakXP))).panelCaption().monospacedDigit()
                }
                ProgressBar(value: model.scheduler.stepFraction)
            }

            HStack(spacing: 8) {
                Button(tr("exercise.hurts")) { model.exerciseHurts() }.buttonStyle(.secondary).fixedSize()
                Button(tr("exercise.other")) { model.anotherExercise() }.buttonStyle(.text)
                Spacer(minLength: 0)
                Button(tr("exercise.done")) { model.finish() }.buttonStyle(.primary).fixedSize()
            }
        }
        .padding(14)
        .frame(width: PanelSize.width, height: PanelSize.tall.height, alignment: .topLeading)
        .foregroundStyle(.white)
    }
}
