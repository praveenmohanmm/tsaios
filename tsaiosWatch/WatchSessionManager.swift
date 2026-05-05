import WatchConnectivity
import WatchKit
import HealthKit

/// Manages WCSession and an HKWorkoutSession that keeps the Watch app
/// running in the background indefinitely.
///
/// Why HKWorkoutSession:
///   WKExtendedRuntimeSession without a background-mode entitlement expires
///   the instant the Watch screen turns off. HKWorkoutSession does NOT expire
///   on wrist-lower and — per Apple docs — keeps WCSession.isReachable = true
///   on the iPhone side, so sendMessage delivers haptics instantly even with
///   the Watch display off / locked.
///
/// Usage: open the Alert ME Watch app once before driving. The session starts
/// automatically and the green dot confirms coverage.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?
    @Published var extendedSessionActive = false

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?

    /// Suspends handleBackgroundConnectivity() until the delegate fires.
    private var backgroundContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Workout session (background keepalive)

    func startExtendedSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Request minimal HealthKit auth — we share/read nothing, we only
        // need the session for background execution.
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                         read: []) { [weak self] granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { self?.beginWorkout() }
        }
    }

    private func beginWorkout() {
        // Stop any existing session first.
        if let existing = workoutSession {
            existing.end()
        }
        let config = HKWorkoutConfiguration()
        config.activityType = .other        // generic — no fitness framing shown
        config.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore,
                                               configuration: config)
            session.delegate = self
            workoutSession = session
            healthStore.start(session)
        } catch {
            print("WatchSessionManager: HKWorkoutSession failed to start — \(error)")
        }
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

    // MARK: - Alert handling

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

// MARK: - HKWorkoutSessionDelegate

extension WatchSessionManager: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        Task { @MainActor in
            WatchSessionManager.shared.extendedSessionActive = (toState == .running)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        Task { @MainActor in
            WatchSessionManager.shared.extendedSessionActive = false
            // Restart after a brief pause.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            WatchSessionManager.shared.beginWorkout()
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
