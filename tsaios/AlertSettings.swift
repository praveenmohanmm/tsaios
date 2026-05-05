import Foundation

// MARK: - Watch Haptic Pattern

enum WatchHapticPattern: String, CaseIterable, Equatable, Codable {
    case single      = "single"      // 1 tap
    case double_     = "double"      // 2 taps
    case triple      = "triple"      // 3 taps (default)
    case longBuzz    = "longBuzz"    // 5 rapid taps
    case urgentPulse = "urgentPulse" // failure burst + 3 taps

    var displayName: String {
        switch self {
        case .single:      return "Single Tap"
        case .double_:     return "Double Tap"
        case .triple:      return "Triple Buzz"
        case .longBuzz:    return "Long Buzz ★"
        case .urgentPulse: return "Urgent Pulse ★"
        }
    }
}

// MARK: - Alert Tone

enum AlertTone: String, CaseIterable, Equatable, Codable {
    case tripleBeep  = "tripleBeep"
    case singleBeep  = "singleBeep"
    case alertChime  = "alertChime"
    case siren       = "siren"       // ★ loud: rising-falling frequency sweep
    case klaxon      = "klaxon"      // ★ loud: harsh alternating two-tone
    case rapidAlarm  = "rapidAlarm"  // ★ loud: 6 rapid high-pitched blasts

    var displayName: String {
        switch self {
        case .tripleBeep:  return "Triple Beep"
        case .singleBeep:  return "Single Beep"
        case .alertChime:  return "Alert Chime"
        case .siren:       return "Siren ★"
        case .klaxon:      return "Klaxon ★"
        case .rapidAlarm:  return "Rapid Alarm ★"
        }
    }
}

struct AlertSettings: Codable, Equatable {
    var minSpeedKmh: Double = 17.0
    var maxSpeedKmh: Double = 100.0
    var tone: AlertTone = .tripleBeep
    var hapticPattern: WatchHapticPattern = .triple

    // Per-band alert radii (metres). Each can be tuned independently.
    var radius17to30: Double  = 50.0   // 17–30 km/h
    var radius30to50: Double  = 60.0   // 30–50 km/h
    var radius50to60: Double  = 80.0   // 50–60 km/h
    var radius60to70: Double  = 90.0   // 60–70 km/h
    var radius70to100: Double = 100.0  // 70–100 km/h

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

    /// Returns the alert radius in metres for the given speed (km/h),
    /// or nil if the speed is outside [minSpeedKmh, maxSpeedKmh].
    func alertRadius(forSpeedKmh speedKmh: Double) -> Double? {
        guard speedKmh >= minSpeedKmh && speedKmh <= maxSpeedKmh else { return nil }
        switch speedKmh {
        case ..<30: return radius17to30
        case ..<50: return radius30to50
        case ..<60: return radius50to60
        case ..<70: return radius60to70
        default:    return radius70to100
        }
    }
}
