import SwiftUI

@main
struct tsaiosWatchApp: App {

    @StateObject private var session = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(session)
        }
        // Wake the app in the background when a WCSession message arrives
        // so the haptic fires even when the Watch face is not showing our app.
        .backgroundTask(.watchConnectivity) {
            await WatchSessionManager.shared.handleBackgroundConnectivity()
        }
    }
}
