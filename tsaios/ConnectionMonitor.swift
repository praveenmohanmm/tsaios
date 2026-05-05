import UIKit
import AVFoundation
import Combine

/// Monitors charger and CarPlay connectivity.
///
/// • Charger  — UIDevice battery state (.charging / .full)
/// • CarPlay  — UIScreen connect/disconnect (CarPlay presents as an external screen)
///
/// When neither is active, `isConnected` becomes false and the ViewModel
/// stops scanning and speaks the alert via AVSpeechSynthesizer.
@MainActor
final class ConnectionMonitor {

    // MARK: - Published

    @Published private(set) var isConnected: Bool = false

    // MARK: - Private state

    private var chargerConnected: Bool = false { didSet { refresh() } }
    private var carPlayConnected: Bool = false { didSet { refresh() } }

    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        chargerConnected = isCharging()
        carPlayConnected = UIScreen.screens.count > 1

        // Charger plugged / unplugged
        NotificationCenter.default
            .publisher(for: UIDevice.batteryStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.chargerConnected = self?.isCharging() ?? false
            }
            .store(in: &cancellables)

        // CarPlay / external screen connected
        NotificationCenter.default
            .publisher(for: UIScreen.didConnectNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.carPlayConnected = true
            }
            .store(in: &cancellables)

        // CarPlay / external screen disconnected
        NotificationCenter.default
            .publisher(for: UIScreen.didDisconnectNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.carPlayConnected = UIScreen.screens.count > 1
            }
            .store(in: &cancellables)

        refresh()
    }

    // MARK: - TTS announcement

    func announce(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.volume = 1.0
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    // MARK: - Helpers

    private func isCharging() -> Bool {
        let s = UIDevice.current.batteryState
        return s == .charging || s == .full
    }

    private func refresh() {
        isConnected = chargerConnected || carPlayConnected
    }
}
