import SwiftUI

struct WatchContentView: View {

    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 6) {
            Text("🚦")
                .font(.system(size: 36))

            Text("Alert ME")
                .font(.headline)

            // Extended session status — green = background active, red = tap to activate
            HStack(spacing: 4) {
                Circle()
                    .fill(session.extendedSessionActive ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(session.extendedSessionActive ? "Active" : "Tap to activate")
                    .font(.caption2)
                    .foregroundStyle(session.extendedSessionActive ? .green : .red)
            }

            if let dist = session.lastAlertDistance,
               let time = session.lastAlertTime {
                Text("\(dist) m")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
                Text(time, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Monitoring…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            // Start the extended runtime session as soon as the Watch app
            // is visible — keeps WCSession reachable for instant haptics.
            session.startExtendedSession()
        }
    }
}
