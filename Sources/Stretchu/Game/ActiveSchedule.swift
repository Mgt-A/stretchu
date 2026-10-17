import Foundation

/// The hours and days Stretchu is awake. Outside them: no wake-up, no counter, the streak is not
/// at stake. A day that is not active behaves like the weekend always did.
struct ActiveSchedule: Codable, Equatable {
    /// Calendar weekday numbers (1 = Sunday ... 7 = Saturday): Monday to Friday.
    static let defaultDays: Set<Int> = [2, 3, 4, 5, 6]
    static let step = 15
    static let defaultStart = 8 * 60 + 30
    static let defaultEnd = 18 * 60

    /// Minutes since midnight.
    var startMinute = ActiveSchedule.defaultStart
    var endMinute = ActiveSchedule.defaultEnd
    var days = ActiveSchedule.defaultDays

    init(startMinute: Int = ActiveSchedule.defaultStart, endMinute: Int = ActiveSchedule.defaultEnd,
         days: Set<Int> = ActiveSchedule.defaultDays) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.days = days
    }

    private enum CodingKeys: String, CodingKey { case startMinute, endMinute, days }

    // A state written before the schedule existed has none: the defaults apply.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startMinute = try c.decodeIfPresent(Int.self, forKey: .startMinute) ?? Self.defaultStart
        endMinute = try c.decodeIfPresent(Int.self, forKey: .endMinute) ?? Self.defaultEnd
        days = Set(try c.decodeIfPresent([Int].self, forKey: .days) ?? Array(Self.defaultDays))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(startMinute, forKey: .startMinute)
        try c.encode(endMinute, forKey: .endMinute)
        try c.encode(days.sorted(), forKey: .days)
    }

    /// Quarter-hour steps, the end at least one step after the start, valid weekdays only; no day
    /// at all falls back to the default days.
    func clamped() -> ActiveSchedule {
        func snap(_ value: Int) -> Int { min(max(0, (value + Self.step / 2) / Self.step * Self.step), 24 * 60) }
        var start = min(snap(startMinute), 24 * 60 - Self.step)
        var end = snap(endMinute)
        if end < start + Self.step { end = start + Self.step }
        if end > 24 * 60 { end = 24 * 60; start = end - Self.step }
        let valid = days.filter { (1...7).contains($0) }
        return ActiveSchedule(startMinute: start, endMinute: end, days: valid.isEmpty ? Self.defaultDays : valid)
    }

    func isActiveDay(_ date: Date, calendar: Calendar) -> Bool {
        days.contains(calendar.component(.weekday, from: date))
    }

    /// Inside the hours of an active day. The start is included, the end is not.
    func isActive(at date: Date, calendar: Calendar) -> Bool {
        guard isActiveDay(date, calendar: calendar) else { return false }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return minute >= startMinute && minute < endMinute
    }

    /// The next opening strictly after `date`: today if it is before the opening of an active
    /// day, otherwise the next active day.
    func nextStart(after date: Date, calendar: Calendar) -> Date? {
        var day = calendar.startOfDay(for: date)
        for _ in 0..<8 {
            if isActiveDay(day, calendar: calendar),
               let opening = calendar.date(byAdding: .minute, value: startMinute, to: day), opening > date {
                return opening
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        return nil
    }
}
