import ServiceManagement

/// Launch at login through SMAppService.mainApp. Only works from the installed app
/// (/Applications/Stretchu.app), not from `swift run`.
enum LaunchAtLogin {
    enum Status: Equatable {
        case enabled, disabled
        /// macOS asks for approval in System Settings > Login Items.
        case requiresApproval
        case unavailable
    }

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .disabled
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
