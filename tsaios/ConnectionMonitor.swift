import AVFoundation
import UIKit
import Combine

/// Detects Apple CarPlay by watching AVAudioSession route changes.
///
/// When CarPlay connects, the audio route gains a `.carAudio` output port.
/// When CarPlay disconnects, that port disappears. This fires reliably for
/// both wired and wireless CarPlay without requiring a CarPlay entitlement.
@MainActor
final class ConnectionMonitor {

    // MARK: - Published

    @Published private(set) var isConnected: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Snapshot current state at launch (e.g. app opened while already in CarPlay)
        isConnected = Self.carPlayActive()

        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isConnected = Self.carPlayActive()
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

    // MARK: - Private

    /// Returns true when CarPlay is the active audio output.
    /// `.carAudio` is unique to CarPlay — Bluetooth audio uses `.bluetoothA2DP`.
    private static func carPlayActive() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { $0.portType == .carAudio }
    }
}
