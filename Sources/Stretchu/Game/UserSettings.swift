import Foundation

/// Adjustable durations. Defaults: 25 min of work, 30 s for step 1, 30 s for step 2, 5 min of snooze.
struct UserSettings: Codable, Equatable {
    static let workRange = 5...90
    static let step1Range = 10...120
    static let step2Range = 15...180
    static let snoozeRange = 1...30

    var workMinutes = 25
    var step1Seconds = 30
    var step2Seconds = 30
    var snoozeMinutes = 5
    /// Mode when the network is unknown or unreadable (Settings, like a known network).
    var defaultMode: PlaceMode = .home
    /// Equipment the player has at home and at the office (values of `Equipment.ownable`);
    /// bodyweight exercises are always available.
    var homeEquipment: [String] = []
    var officeEquipment: [String] = []
    /// The hours and days Stretchu is awake.
    var schedule = ActiveSchedule()

    func equipment(for mode: PlaceMode) -> Set<String> {
        Set(mode == .home ? homeEquipment : officeEquipment)
    }

    init(workMinutes: Int = 25, step1Seconds: Int = 30, step2Seconds: Int = 30, snoozeMinutes: Int = 5,
         defaultMode: PlaceMode = .home, homeEquipment: [String] = [], officeEquipment: [String] = [],
         schedule: ActiveSchedule = ActiveSchedule()) {
        self.schedule = schedule
        self.homeEquipment = homeEquipment
        self.officeEquipment = officeEquipment
        self.workMinutes = workMinutes
        self.step1Seconds = step1Seconds
        self.step2Seconds = step2Seconds
        self.snoozeMinutes = snoozeMinutes
        self.defaultMode = defaultMode
    }

    private enum CodingKeys: String, CodingKey {
        case workMinutes, step1Seconds, step2Seconds, snoozeMinutes, defaultMode, homeEquipment, officeEquipment, schedule
    }

    /// Keys written by the French-named builds, read as a fallback.
    private enum LegacyKeys: String, CodingKey {
        case workMinutes = "travailMinutes"
        case step1Seconds = "etape1Secondes"
        case step2Seconds = "etape2Secondes"
        case snoozeMinutes = "reportMinutes"
        case defaultMode = "modeParDefaut"
    }

    // Older states don't have every key: defaults apply.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let old = try decoder.container(keyedBy: LegacyKeys.self)
        workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes)
            ?? old.decodeIfPresent(Int.self, forKey: .workMinutes) ?? 25
        step1Seconds = try c.decodeIfPresent(Int.self, forKey: .step1Seconds)
            ?? old.decodeIfPresent(Int.self, forKey: .step1Seconds) ?? 30
        step2Seconds = try c.decodeIfPresent(Int.self, forKey: .step2Seconds)
            ?? old.decodeIfPresent(Int.self, forKey: .step2Seconds) ?? 30
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes)
            ?? old.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5
        defaultMode = try c.decodeIfPresent(PlaceMode.self, forKey: .defaultMode)
            ?? old.decodeIfPresent(PlaceMode.self, forKey: .defaultMode) ?? .home
        homeEquipment = try c.decodeIfPresent([String].self, forKey: .homeEquipment) ?? []
        officeEquipment = try c.decodeIfPresent([String].self, forKey: .officeEquipment) ?? []
        schedule = try c.decodeIfPresent(ActiveSchedule.self, forKey: .schedule) ?? ActiveSchedule()
    }

    func clamped() -> UserSettings {
        UserSettings(
            workMinutes: min(max(workMinutes, Self.workRange.lowerBound), Self.workRange.upperBound),
            step1Seconds: min(max(step1Seconds, Self.step1Range.lowerBound), Self.step1Range.upperBound),
            step2Seconds: min(max(step2Seconds, Self.step2Range.lowerBound), Self.step2Range.upperBound),
            snoozeMinutes: min(max(snoozeMinutes, Self.snoozeRange.lowerBound), Self.snoozeRange.upperBound),
            defaultMode: defaultMode, homeEquipment: homeEquipment, officeEquipment: officeEquipment,
            schedule: schedule.clamped())
    }

    var config: SchedulerConfig {
        var c = SchedulerConfig()
        c.work = TimeInterval(workMinutes * 60)
        c.snooze = TimeInterval(snoozeMinutes * 60)
        c.step1 = TimeInterval(step1Seconds)
        c.step2 = TimeInterval(step2Seconds)
        c.schedule = schedule
        return c
    }
}
