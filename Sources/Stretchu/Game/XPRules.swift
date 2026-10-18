import Foundation

/// Every number that shapes the progression, in one place.
///
/// Calibration: 10 breaks per workday, the multiplier at ×5 from the fifth break, reach level 100 in 8 workdays
/// (`ProgressionCalibrationTests` runs that simulation).
enum XPRules {
    // MARK: actions

    /// XP of a completed break, before the multiplier.
    static let breakXP = 2_500

    // MARK: curve

    /// Total XP to reach level n is `xpCoefficient × n²` (level 1 is 0 XP): 1,000,000 at level 100.
    static let xpCoefficient = 100
    static let maxLevel = 100

    static func totalXP(forLevel n: Int) -> Int {
        n <= 1 ? 0 : xpCoefficient * n * n
    }

    static var maxXP: Int { totalXP(forLevel: maxLevel) }

    static func level(forXP xp: Int) -> Int {
        var n = 1
        while n < maxLevel, xp >= totalXP(forLevel: n + 1) { n += 1 }
        return n
    }

    // MARK: streak

    /// Multiplier = min(maxMultiplier, 1 + streak): +1 per completed break, ×5 from the fifth.
    static let maxMultiplier = 5.0
    /// The streak at which the multiplier stops growing (1 + 4 = ×5).
    static let streakAtMaxMultiplier = 4
    /// Completed breaks a workday needs for the streak to survive it: just one, so a day without any breaks it.
    static let breaksPerDayToKeepStreak = 1

    // MARK: Rare Candy

    /// A Rare Candy (super bonbon) every time the streak reaches a multiple of this: 25, 50, 75…
    static let streakPerCandy = 25

    // MARK: migration from the old curve

    /// The curve used before the calibration: total XP to reach level n was n³.
    static func legacyTotalXP(forLevel n: Int) -> Int {
        n <= 1 ? 0 : n * n * n
    }

    /// Keeps the level and the fraction of level when the curve changes: the XP is recomputed.
    static func migratedXP(fromLegacy xp: Int) -> Int {
        let xp = max(0, xp)
        var n = 1
        while n < maxLevel, xp >= legacyTotalXP(forLevel: n + 1) { n += 1 }
        if n >= maxLevel { return maxXP }
        let oldBase = legacyTotalXP(forLevel: n), oldSpan = legacyTotalXP(forLevel: n + 1) - oldBase
        let newBase = totalXP(forLevel: n), newSpan = totalXP(forLevel: n + 1) - newBase
        // Integer arithmetic, rounded to the nearest XP.
        return newBase + ((xp - oldBase) * newSpan + oldSpan / 2) / oldSpan
    }
}
