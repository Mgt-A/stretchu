import Foundation

struct DayBreaks: Codable, Equatable {
    var day: Date
    var breaks: Int

    private enum CodingKeys: String, CodingKey { case day, breaks }
    /// Keys written by the French-named builds, read as a fallback.
    private enum LegacyKeys: String, CodingKey { case day = "jour", breaks = "pauses" }

    init(day: Date, breaks: Int) {
        self.day = day
        self.breaks = breaks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)
        guard let day = try c.decodeIfPresent(Date.self, forKey: .day) ?? old.decodeIfPresent(Date.self, forKey: .day)
        else { throw DecodingError.keyNotFound(CodingKeys.day, .init(codingPath: decoder.codingPath, debugDescription: "day")) }
        self.day = day
        breaks = try c.decodeIfPresent(Int.self, forKey: .breaks) ?? old.decodeIfPresent(Int.self, forKey: .breaks) ?? 0
    }
}

struct WeekdayCell: Equatable {
    enum State: Equatable { case met, missed, today, upcoming, weekend }
    let letter: String
    let state: State
    let breaks: Int
}

/// Streak of consecutive completed breaks, with the workday rules.
struct Streak: Codable, Equatable {
    static let keptDays = 14

    static let breaksPerDayToKeep = XPRules.breaksPerDayToKeepStreak
    static let maxMultiplier = XPRules.maxMultiplier

    var count: Int = 0
    var breaksToday: Int = 0
    /// Start of the reference day. nil = not adopted yet (first launch, prepared state).
    var currentDay: Date?
    /// Breaks of the last finished days (for the companion's week), 14 days at most.
    var history: [DayBreaks] = []

    init(count: Int = 0, breaksToday: Int = 0, currentDay: Date? = nil, history: [DayBreaks] = []) {
        self.count = count
        self.breaksToday = breaksToday
        self.currentDay = currentDay
        self.history = history
    }

    private enum CodingKeys: String, CodingKey { case count, breaksToday, currentDay, history }
    /// Keys written by the French-named builds, read as a fallback.
    private enum LegacyKeys: String, CodingKey {
        case count = "serie", breaksToday = "pausesDuJour", currentDay = "jourCourant", history = "historique"
    }

    // Older states don't have `history`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? old.decodeIfPresent(Int.self, forKey: .count) ?? 0
        breaksToday = try c.decodeIfPresent(Int.self, forKey: .breaksToday)
            ?? old.decodeIfPresent(Int.self, forKey: .breaksToday) ?? 0
        currentDay = try c.decodeIfPresent(Date.self, forKey: .currentDay)
            ?? old.decodeIfPresent(Date.self, forKey: .currentDay)
        history = try c.decodeIfPresent([DayBreaks].self, forKey: .history)
            ?? old.decodeIfPresent([DayBreaks].self, forKey: .history) ?? []
    }

    /// min(5, 1 + streak): +1 per completed break.
    static func multiplier(forStreak count: Int) -> Double {
        min(maxMultiplier, 1 + Double(max(0, count)))
    }

    /// base × multiplier, in integers.
    static func earnedXP(base: Int, streak: Int) -> Int {
        base * (1 + min(max(0, streak), XPRules.streakAtMaxMultiplier))
    }

    var multiplier: Double { Self.multiplier(forStreak: count) }

    /// Call before any read or change, and on every tick.
    /// On a day change: if the last elapsed workday had fewer than 5 completed breaks, or if a whole
    /// workday went by without a break, the streak falls to 0. Saturday and Sunday neither count
    /// nor penalize.
    mutating func sync(now: Date, calendar: Calendar, days: Set<Int> = ActiveSchedule.defaultDays) {
        let today = calendar.startOfDay(for: now)
        guard let previous = currentDay else {
            currentDay = today
            return
        }
        if today < previous {
            // The clock went back (Debug: return to real time). Adopt the day without penalty.
            currentDay = today
            breaksToday = 0
            return
        }
        guard today > previous else { return }

        var broken = calendar.isWorkday(previous, days: days) && breaksToday < Self.breaksPerDayToKeep
        var day = calendar.date(byAdding: .day, value: 1, to: previous)!
        while !broken, day < today {
            if calendar.isWorkday(day, days: days) { broken = true }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        if broken { count = 0 }
        history.append(DayBreaks(day: previous, breaks: breaksToday))
        if history.count > Self.keptDays { history.removeFirst(history.count - Self.keptDays) }
        breaksToday = 0
        currentDay = today
    }

    /// Monday to Sunday of the week of `now`, for the companion's row of days.
    func week(now: Date, calendar: Calendar, days: Set<Int> = ActiveSchedule.defaultDays,
              letters: [String] = L10n.weekdayLetters) -> [WeekdayCell] {
        let today = calendar.startOfDay(for: now)
        let offset = (calendar.component(.weekday, from: today) + 5) % 7 // Monday = 0
        let monday = calendar.date(byAdding: .day, value: -offset, to: today)!
        return (0..<7).map { index in
            let day = calendar.date(byAdding: .day, value: index, to: monday)!
            if day == today { return WeekdayCell(letter: letters[index], state: .today, breaks: breaksToday) }
            if day > today {
                return WeekdayCell(letter: letters[index], state: calendar.isWorkday(day, days: days) ? .upcoming : .weekend, breaks: 0)
            }
            let breaks = history.last { $0.day == day }?.breaks ?? 0
            guard calendar.isWorkday(day, days: days) else { return WeekdayCell(letter: letters[index], state: .weekend, breaks: breaks) }
            return WeekdayCell(letter: letters[index], state: breaks >= Self.breaksPerDayToKeep ? .met : .missed, breaks: breaks)
        }
    }

    mutating func completeBreak() {
        count += 1
        breaksToday += 1
    }

    mutating func skip() {
        count = 0
    }
}

extension Calendar {
    /// An active day: Monday to Friday unless the player chose other days.
    func isWorkday(_ date: Date, days: Set<Int> = ActiveSchedule.defaultDays) -> Bool {
        days.contains(component(.weekday, from: date)) // 1 = Sunday, 7 = Saturday
    }

    /// The next workday strictly after `date`, at 9:00.
    func nextWorkday(after reference: Date) -> Date {
        var day = date(byAdding: .day, value: 1, to: startOfDay(for: reference))!
        while !isWorkday(day) { day = date(byAdding: .day, value: 1, to: day)! }
        return date(bySettingHour: 9, minute: 0, second: 0, of: day)!
    }

    /// The next Monday strictly after `date`, at 9:00.
    func nextMonday(after reference: Date) -> Date {
        var day = date(byAdding: .day, value: 1, to: startOfDay(for: reference))!
        while component(.weekday, from: day) != 2 { day = date(byAdding: .day, value: 1, to: day)! }
        return date(bySettingHour: 9, minute: 0, second: 0, of: day)!
    }
}
