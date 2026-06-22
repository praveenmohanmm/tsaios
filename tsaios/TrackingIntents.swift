import AppIntents

// MARK: - Start Tracking Intent

struct StartTrackingIntent: AppIntent {

    static var title: LocalizedStringResource = "Start Traffic Signal Scanning"
    static var description = IntentDescription(
        "Starts scanning for nearby traffic signals and alerts you when one is ahead. " +
        "Restarts cleanly even if scanning is already running.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let vm = AlertViewModel.shared
        guard vm.signalCount > 0 else {
            return .result(dialog: "Signal data is still loading. Please wait a moment and try again.")
        }
        vm.restartTracking()   // always a fresh start, even if already tracking
        return .result(dialog: "Starting traffic signal scanning.")
    }
}

// MARK: - Stop Tracking Intent

struct StopTrackingIntent: AppIntent {

    static var title: LocalizedStringResource = "Stop Traffic Signal Scanning"
    static var description = IntentDescription(
        "Stops scanning for traffic signals.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let vm = AlertViewModel.shared
        guard vm.isTracking else {
            return .result(dialog: "Traffic signal scanning is not active.")
        }
        vm.stopTracking()
        return .result(dialog: "Stopping traffic signal scanning.")
    }
}

// MARK: - Siri phrase registration

/// Registers phrases so Siri knows them without the user adding them
/// manually in the Shortcuts app. Requires iOS 16.4+.
///
/// Supported phrases (Siri understands both):
///   "Hey Siri, start tracking in Alert ME"
///   "Hey Siri, stop tracking in Alert ME"
struct AlertMEShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTrackingIntent(),
            phrases: [
                "Start tracking in \(.applicationName)",
                "Start scanning in \(.applicationName)",
            ],
            shortTitle: "Start Scanning",
            systemImageName: "light.beacon.max.fill"
        )
        AppShortcut(
            intent: StopTrackingIntent(),
            phrases: [
                "Stop tracking in \(.applicationName)",
                "Stop scanning in \(.applicationName)",
            ],
            shortTitle: "Stop Scanning",
            systemImageName: "light.beacon.max"
        )
    }
}
