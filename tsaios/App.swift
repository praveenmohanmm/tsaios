import SwiftUI
import AppIntents

@main
struct tsaiosApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AudioService.configureAudioSession()
        // Register App Shortcuts with Siri so phrases work without the user
        // manually adding them in the Shortcuts app.
        AlertMEShortcuts.updateAppShortcutParameters()
        return true
    }
}
