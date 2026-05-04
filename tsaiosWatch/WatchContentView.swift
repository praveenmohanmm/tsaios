import SwiftUI

struct WatchContentView: View {

    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 6) {
            Text("🚦")
                .font(.system(size: 40))

            Text("Alert ME")
                .font(.headline)

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
    }
}
