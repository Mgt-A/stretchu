import SwiftUI

/// Segmented control (Home / Office, species pickers…).
struct Segments<Value: Hashable>: View {
    let values: [Value]
    let selection: Value
    let label: (Value) -> String
    var width: CGFloat? = nil
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { candidate in
                let active = selection == candidate
                Button { onSelect(candidate) } label: {
                    Text(label(candidate))
                        .font(.system(size: 13, weight: active ? .medium : .regular))
                        .foregroundStyle(active ? Color.white : Color.white.opacity(0.75))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 5).fill(active ? Color.white.opacity(0.22) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
    }
}

/// Two segments Home / Office.
struct ModePicker: View {
    let mode: PlaceMode
    var width: CGFloat? = nil
    let onSelect: (PlaceMode) -> Void

    var body: some View {
        Segments(values: PlaceMode.allCases, selection: mode, label: \.name, width: width, onSelect: onSelect)
    }
}

/// "title · value · − +" row: settings durations, Debug levels and streaks.
struct StepRow: View {
    let title: String
    let value: String
    var canDecrease = true
    var canIncrease = true
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 13)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Text(value).font(.system(size: 13)).monospacedDigit().lineLimit(1).frame(minWidth: 52, alignment: .trailing)
            button("minus", enabled: canDecrease, action: decrease)
            button("plus", enabled: canIncrease, action: increase)
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.14)))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }
}

/// Section title in small gray capitals.
struct PageSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
            content()
        }
    }
}

/// The active hours and days: start and end in quarter hours, a row of seven days.
struct ScheduleEditor: View {
    let schedule: ActiveSchedule
    let onChange: (ActiveSchedule) -> Void

    /// Monday first.
    private static let weekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        let step = ActiveSchedule.step
        VStack(alignment: .leading, spacing: 8) {
            StepRow(title: tr("schedule.start"), value: Format.clockTime(minute: schedule.startMinute),
                    canDecrease: schedule.startMinute > 0, canIncrease: schedule.startMinute + step < schedule.endMinute,
                    decrease: { change { $0.startMinute -= step } }, increase: { change { $0.startMinute += step } })
            StepRow(title: tr("schedule.end"), value: Format.clockTime(minute: schedule.endMinute),
                    canDecrease: schedule.endMinute - step > schedule.startMinute, canIncrease: schedule.endMinute + step <= 24 * 60,
                    decrease: { change { $0.endMinute -= step } }, increase: { change { $0.endMinute += step } })
            HStack(spacing: 4) {
                ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { index, weekday in
                    let on = schedule.days.contains(weekday)
                    Button { toggle(weekday) } label: {
                        Text(L10n.weekdayLetters[index]).font(.system(size: 12, weight: on ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.accentColor : Color.white.opacity(0.1)))
                            .opacity(on ? 1 : 0.6)
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(tr("schedule.note")).freeCaption().fixedSize(horizontal: false, vertical: true)
        }
    }

    private func change(_ edit: (inout ActiveSchedule) -> Void) {
        var next = schedule
        edit(&next)
        onChange(next.clamped())
    }

    /// At least one day stays on.
    private func toggle(_ weekday: Int) {
        change {
            if $0.days.contains(weekday) { if $0.days.count > 1 { $0.days.remove(weekday) } } else { $0.days.insert(weekday) }
        }
    }
}
