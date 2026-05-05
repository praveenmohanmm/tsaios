import UIKit
import AVFoundation
import Combine

/// Monitors CarPlay connectivity only.
///
/// CarPlay presents as an external UIScreen, so UIScreen connect/disconnect
/// notifications are the signal source. Charger state is intentionally ignored.
@MainActor
final class ConnectionMonitor {

    // MARK: - Published

    @Published private(set) var isConnected: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Check whether CarPlay is already active at launch
        isConnected = UIScreen.screens.count > 1

        // CarPlay connected
        NotificationCenter.default
            .publisher(for: UIScreen.didConnectNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isConnected = true
            }
            .store(in: &cancellables)

        // CarPlay disconnected
        NotificationCenter.default
            .publisher(for: UIScreen.didDisconnectNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isConnected = UIScreen.screens.count > 1
            }
            .store(in: &cancellables)
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
}
