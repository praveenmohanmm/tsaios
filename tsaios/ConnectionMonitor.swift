import AVFoundation
import UIKit
import Combine

/// Detects Apple CarPlay by watching AVAudioSession route changes.
///
/// CarPlay always registers a `.carAudio` output port when connected.
/// Three complementary signals are combined for reliability:
///   1. AVAudioSession.routeChangeNotification  — primary, with a short
///      settle delay because the route isn't always final at notification time.
///   2. UIApplication.didBecomeActiveNotification — re-checks if the app
///      was suspended while CarPlay connected / disconnected.
///   3. 3-second polling fallback — catches wireless CarPlay and any edge
///      cases where neither notification fires reliably.
@MainActor
final class ConnectionMonitor {

    // MARK: - Published

    @Published private(set) var isConnected: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        isConnected = Self.carPlayActive()

        // 1. Audio route change — fires on CarPlay connect / disconnect.
        //    Wait 0.5 s for the route to fully settle before reading it.
        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        // 2. App comes to foreground — catches connect / disconnect events
        //    that happened while the app was suspended.
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // 3. Polling fallback every 3 s — handles wireless CarPlay and any
        //    case where neither notification fires in time.
        Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
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

    /// Pending work item that will flip isConnected to false.
    /// Cancelled if CarPlay re-appears before the grace period expires.
    private var disconnectWork: DispatchWorkItem?

    private func refresh() {
        if Self.carPlayActive() {
            // CarPlay active — connect immediately and cancel any pending disconnect.
            disconnectWork?.cancel()
            disconnectWork = nil
            guard !isConnected else { return }
            isConnected = true
        } else {
            // CarPlay appears inactive.
            // Don't disconnect immediately — audio apps (radio, music) briefly
            // flip the route when they start, causing false disconnects.
            // Wait 5 s and only disconnect if CarPlay is still gone.
            guard disconnectWork == nil else { return }   // debounce already armed
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if !Self.carPlayActive() {
                    self.isConnected = false
                }
                self.disconnectWork = nil
            }
            disconnectWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
        }
    }

    /// `.carAudio` is unique to CarPlay — Bluetooth uses `.bluetoothA2DP`.
    private static func carPlayActive() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { $0.portType == .carAudio }
    }
}
