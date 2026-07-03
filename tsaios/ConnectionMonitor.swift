import AVFoundation
import UIKit
import Combine

/// Detects Apple CarPlay by watching AVAudioSession route changes.
///
/// CarPlay registers a `.carAudio` output port when connected. This monitor
/// only reports the connect transition — disconnect is intentionally ignored,
/// scanning is never auto-stopped by CarPlay state.
///
/// Three complementary signals catch cases the single notification misses:
///   1. AVAudioSession.routeChangeNotification — primary, with a short
///      settle delay because the route isn't always final at notification time.
///   2. UIApplication.didBecomeActiveNotification — re-checks if CarPlay
///      connected while the app was backgrounded/suspended.
///   3. 3-second polling fallback — catches wireless CarPlay and any case
///      where the notification is missed entirely.
@MainActor
final class ConnectionMonitor {

    @Published private(set) var isConnected: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        isConnected = Self.carPlayActive()

        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Check at multiple delays: wired CarPlay is fast (~0.5s),
                // wireless CarPlay can take 2-5s to finalise the route.
                for delay in [0.5, 1.5, 3.5, 6.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.refresh()
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // 2-second poll — catches any notification gaps and keeps state in sync
        // regardless of what other apps do to the audio route.
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    private func refresh() {
        let active = Self.carPlayActive()
        guard active != isConnected else { return }
        isConnected = active
    }

    /// `.carAudio` is unique to CarPlay — Bluetooth uses `.bluetoothA2DP`.
    private static func carPlayActive() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { $0.portType == .carAudio }
    }
}
