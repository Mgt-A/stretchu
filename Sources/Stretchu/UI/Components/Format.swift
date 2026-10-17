import AppKit
import Foundation

/// Number and time formats. The locale follows the interface language: French has a narrow
/// space for thousands and a decimal comma, English a comma and a point.
enum Format {
    static func xp(_ value: Int, locale: Locale = L10n.locale) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func multiplier(_ value: Double, locale: Locale = L10n.locale) -> String {
        String(format: "×%.1f", locale: locale, value)
    }

    /// Minutes since midnight as a time of day: "8 h 30" in French, "8:30 AM" in English.
    static func clockTime(minute: Int, language: String = L10n.languageCode) -> String {
        let hour = minute / 60, min = minute % 60
        if language == "fr" { return min == 0 ? "\(hour) h" : String(format: "%d h %02d", hour, min) }
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelve, min, hour % 24 < 12 ? "AM" : "PM")
    }

    /// "Resumes tomorrow at 8:30 AM": when Stretchu wakes up again, seen from `now`.
    static func resume(at opening: Date, from now: Date, calendar: Calendar, language: String = L10n.languageCode,
                       locale: Locale = L10n.locale) -> String {
        let minute = calendar.component(.hour, from: opening) * 60 + calendar.component(.minute, from: opening)
        let time = clockTime(minute: minute, language: language)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: opening)).day ?? 0
        switch days {
        case 0: return tr("menu.resumeToday", time, language: language)
        case 1: return tr("menu.resumeTomorrow", time, language: language)
        default:
            let f = DateFormatter()
            f.locale = locale
            f.calendar = calendar
            f.setLocalizedDateFormatFromTemplate("EEEE")
            return tr("menu.resumeDay", f.string(from: opening), time, language: language)
        }
    }

    /// 1500 → "25:00", 20 → "00:20".
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Panel countdowns: 14 → "0:14", 754 → "12:34".
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Status bar timer: "25:00", then "9:59" under 10 min (one digit less).
    static func barTimer(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return total >= 600 ? String(format: "%02d:%02d", total / 60, total % 60)
                            : String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Widths of the status pill: each digit takes a cell as wide as the widest one, so nothing
/// moves from one second to the next, and "Break" takes the place of a timer.
enum TimerWidth {
    static var font: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular) }

    private static func measure(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// Cell of one character: digits share the width of the widest, the rest keeps its own.
    static func cellWidth(_ c: Character) -> CGFloat {
        if c.isNumber { return (0...9).map { measure("\($0)") }.max() ?? 0 }
        return measure(String(c))
    }

    static func textWidth(_ text: String) -> CGFloat {
        text.reduce(0) { $0 + cellWidth($1) }
    }

    enum Slot: Equatable {
        case timer(minuteDigits: Int)
        case pause
        case waiting
    }

    /// Width reserved for the pill's text. From 10 min on it is the same for the timer,
    /// "Break" and "···": clicking "Take a break now" moves nothing. Under 10 min the timer
    /// loses a digit and the slot narrows.
    static func slot(_ slot: Slot, pauseText: String = tr("pill.pause")) -> CGFloat {
        let wide = max(textWidth("00:00"), textWidth(pauseText))
        switch slot {
        case let .timer(minuteDigits): return minuteDigits >= 2 ? wide : textWidth("0:00")
        case .pause, .waiting: return wide
        }
    }
}
