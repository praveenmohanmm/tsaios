import WatchConnectivity
import WatchKit

/// Receives messages from the paired iPhone and plays a haptic immediately.
/// Works whether the Watch app is in the foreground or background — the
/// `.watchConnectivity` background task in WatchApp.swift ensures the app
/// is woken to process messages.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Called by the `.watchConnectivity` background task to keep the
    /// WCSession alive while a message is being processed in the background.
    func handleBackgroundConnectivity() async {
        // Activation is already done in init; nothing extra needed here.
        // The delegate callback fires during the background task window and
        // plays the haptic.
    }

    // MARK: - Haptic + state update

    fileprivate func receiveAlert(distanceMetres: Int) {
        WKInterfaceDevice.current().play(.notification)
        lastAlertDistance = distanceMetres
        lastAlertTime = Date()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    // Called when iPhone sends sendMessage — arrives even during background task.
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let dist = message["haptic"] as? Int else { return }
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlert(distanceMetres: dist)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
}
