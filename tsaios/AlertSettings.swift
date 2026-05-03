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
    var minSpeedKmh: Double = 20.0
    var maxSpeedKmh: Double = 80.0
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
    func alertRadius(forSpeedKmh speedKmh: Double) -> Double? {
        guard speedKmh >= minSpeedKmh && speedKmh <= maxSpeedKmh else { return nil }
        switch speedKmh {
        case ..<30: return 80.0
        case ..<50: return 100.0
        case ..<70: return 120.0
        default:    return 150.0
        }
    }
}
