import CoreLocation
import CoreWLAN
import Foundation

/// Home / Office: deduced from the SSID, with a manual toggle that wins until the next network change.
struct ModeResolver: Equatable {
    var networks: [String: PlaceMode] = [:]
    /// Mode when no known network decides (Settings).
    var defaultMode: PlaceMode = .home
    private(set) var ssid: String?
    private(set) var manualMode: PlaceMode?

    init(networks: [String: PlaceMode] = [:], defaultMode: PlaceMode = .home) {
        self.networks = networks
        self.defaultMode = defaultMode
    }

    /// Current mode: the manual choice, else the network's mode, else the default mode.
    var mode: PlaceMode {
        manualMode ?? ssid.flatMap { networks[$0] } ?? defaultMode
    }

    /// A network is connected but has no mode linked yet.
    var networkUnlinked: Bool {
        ssid.map { networks[$0] == nil } ?? false
    }

    /// Call on every SSID read. Another network cancels the manual choice.
    mutating func networkChanged(ssid new: String?) {
        guard new != ssid else { return }
        ssid = new
        manualMode = nil
    }

    mutating func toggle(to mode: PlaceMode) {
        manualMode = mode
    }

    /// Links the current network to a mode (first launch, settings).
    mutating func linkCurrentNetwork(to mode: PlaceMode) {
        guard let ssid else { return }
        networks[ssid] = mode
        manualMode = nil
    }
}

/// Reads the SSID with CoreWLAN. On macOS 14+, the network name is only returned with
/// the Location permission. Denied: nothing is read, the manual toggle is enough.
@MainActor
final class WifiModeDetector: NSObject, CLLocationManagerDelegate {
    enum Authorization { case notRequested, granted, denied }

    private let location = CLLocationManager()
    private(set) var authorization: Authorization = .notRequested
    /// Called when macOS reports a new authorization (the setup shows it live).
    var onChange: (() -> Void)?

    override init() {
        super.init()
        location.delegate = self
        refreshAuthorization()
    }

    func requestAuthorization() {
        guard authorization == .notRequested else { return }
        location.requestWhenInUseAuthorization()
    }

    func ssid() -> String? {
        guard authorization == .granted else { return nil }
        return CWWiFiClient.shared().interface()?.ssid()
    }

    private func refreshAuthorization() {
        switch location.authorizationStatus {
        case .notDetermined: authorization = .notRequested
        case .denied, .restricted: authorization = .denied
        default: authorization = .granted
        }
        onChange?()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refreshAuthorization() }
    }
}
