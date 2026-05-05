import WatchConnectivity
import WatchKit

/// Receives alert messages from the paired iPhone and fires the chosen haptic pattern.
///
/// Delivery paths:
///   • sendMessage            → Watch app in foreground  → playPattern() directly
///   • updateApplicationContext → Watch app locked/backgrounded → background task
///                                wakes app → playPattern() directly
///                                (WKInterfaceDevice.play() is supported in background tasks)
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?

    /// Suspends handleBackgroundConnectivity() until the delegate fires, then resolves.
    private var backgroundContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Background task entry point

    /// Called by the `.watchConnectivity` background task in WatchApp.swift.
    /// Suspends until the incoming delegate fires and plays the haptic,
    /// then returns so watchOS can reclaim the background budget.
    func handleBackgroundConnectivity() async {
        await withCheckedContinuation { continuation in
            backgroundContinuation = continuation
            // Safety timeout — background tasks must not run forever.
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 s
                self.resolveBackgroundTask()
            }
        }
    }

    private func resolveBackgroundTask() {
        backgroundContinuation?.resume()
        backgroundContinuation = nil
    }

    // MARK: - Alert handling

    fileprivate func receiveAlert(distanceMetres: Int, pattern: String) {
        // WKInterfaceDevice.play() works in both foreground AND background tasks.
        // No notification permission required — haptic fires directly on the Watch.
        Task { await self.playPattern(pattern) }
        lastAlertDistance = distanceMetres
        lastAlertTime = Date()
        resolveBackgroundTask()
    }

    // MARK: - Haptic pattern player

    private func playPattern(_ rawPattern: String) async {
        switch rawPattern {
        case "single":
            play(.notification)

        case "double":
            play(.notification)
            try? await sleep(ms: 220)
            play(.notification)

        case "triple":
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 200) }
                play(.notification)
            }

        case "longBuzz":
            for i in 0..<5 {
                if i > 0 { try? await sleep(ms: 150) }
                play(.notification)
            }

        case "urgentPulse":
            play(.failure)
            try? await sleep(ms: 350)
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 180) }
                play(.notification)
            }

        default:
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 200) }
                play(.notification)
            }
        }
    }

    // MARK: - Helpers

    private func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    private func sleep(ms: UInt64) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    /// Foreground: iPhone used sendMessage (Watch app was reachable).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let dist = message["haptic"] as? Int else { return }
        let pattern = message["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlert(distanceMetres: dist, pattern: pattern)
        }
    }

    /// Background: iPhone used updateApplicationContext (Watch was locked/backgrounded).
    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let dist = context["haptic"] as? Int else { return }
        let pattern = context["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlert(distanceMetres: dist, pattern: pattern)
        }
    }

    /// Legacy fallback: iPhone used transferUserInfo.
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let dist = userInfo["haptic"] as? Int else { return }
        let pattern = userInfo["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlert(distanceMetres: dist, pattern: pattern)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
}
