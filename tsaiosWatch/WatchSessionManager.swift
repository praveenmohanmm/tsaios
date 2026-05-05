import WatchConnectivity
import WatchKit

/// Manages WCSession and an WKExtendedRuntimeSession that keeps the Watch app
/// running in the background.
///
/// When the extended session is active, WCSession.isReachable == true on the
/// iPhone side, so the iPhone uses sendMessage for instant haptic delivery —
/// even when the Watch display is off / locked.
///
/// The user opens the Watch app once before driving; the session auto-restarts
/// whenever it is about to expire.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?
    @Published var extendedSessionActive = false

    private var extendedSession: WKExtendedRuntimeSession?

    /// Suspends handleBackgroundConnectivity() until the delegate fires.
    private var backgroundContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Extended runtime session

    /// Start (or restart) the extended runtime session.
    /// Must be called while the app is in the foreground, or from within
    /// an already-running extended session (e.g. on willExpire).
    func startExtendedSession() {
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        extendedSession = s
    }

    // MARK: - Background task entry point (fallback when session not active)

    func handleBackgroundConnectivity() async {
        await withCheckedContinuation { continuation in
            backgroundContinuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self.resolveBackgroundTask()
            }
        }
    }

    private func resolveBackgroundTask() {
        backgroundContinuation?.resume()
        backgroundContinuation = nil
    }

    // MARK: - Haptic

    fileprivate func receiveAlert(distanceMetres: Int, pattern: String) {
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

    private func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    private func sleep(ms: UInt64) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchSessionManager: WKExtendedRuntimeSessionDelegate {

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            WatchSessionManager.shared.extendedSessionActive = true
        }
    }

    /// Called a few seconds before the session expires — restart immediately
    /// so there is no gap in coverage.
    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            WatchSessionManager.shared.startExtendedSession()
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?) {
        Task { @MainActor in
            WatchSessionManager.shared.extendedSessionActive = false
            // Brief pause then restart — avoids tight loop on persistent errors.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            WatchSessionManager.shared.startExtendedSession()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let dist = message["haptic"] as? Int else { return }
        let pattern = message["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlert(distanceMetres: dist, pattern: pattern)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let dist = context["haptic"] as? Int else { return }
        let pattern = context["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlert(distanceMetres: dist, pattern: pattern)
        }
    }

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
