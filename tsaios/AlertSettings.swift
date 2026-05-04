import Foundation

enum AlertTone: String, CaseIterable, Equatable, Codable {
    case tripleBeep = "tripleBeep"
    case singleBeep = "singleBeep"
    case alertChime = "alertChime"

    var displayName: String {
        switch self {
        case .tripleBeep: return "Triple Beep"
        case .singleBeep: return "Single Beep"
        case .alertChime: return "Alert Chime"
        }
    }
}

struct AlertSettings: Codable, Equatable {
    var minSpeedKmh: Double = 17.0
    var maxSpeedKmh: Double = 100.0
    var tone: AlertTone = .tripleBeep

    private static let userDefaultsKey = "AlertSettings"

    static func load() -> AlertSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(AlertSettings.self, from: data) else {
            return AlertSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AlertSettings.userDefaultsKey)
        }
    }

    /// Returns the alert radius in metres for the given speed (km/h), or nil if outside speed range.
    ///
    ///   17–30 km/h →  50 m
    ///   30–50 km/h →  60 m
    ///   50–60 km/h →  80 m
    ///   60–70 km/h →  90 m
    ///   70–100 km/h → 100 m
    func alertRadius(forSpeedKmh speedKmh: Double) -> Double? {
        guard speedKmh >= minSpeedKmh && speedKmh <= maxSpeedKmh else { return nil }
        switch speedKmh {
        case ..<30: return 50.0
        case ..<50: return 60.0
        case ..<60: return 80.0
        case ..<70: return 90.0
        default:    return 100.0
        }
    }
}
