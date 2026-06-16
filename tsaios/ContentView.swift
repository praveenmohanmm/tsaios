import SwiftUI

struct ContentView: View {
    @ObservedObject var vm = AlertViewModel.shared
    @State private var showSettings = false

    // Dark navy theme
    private let navyBackground = Color(red: 0.07, green: 0.10, blue: 0.18)
    private let cardBackground  = Color(red: 0.11, green: 0.15, blue: 0.25)

    var body: some View {
        NavigationStack {
            ZStack {
                navyBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        headerCard
                        speedBanner
                        alertBanner
                        nearestSignalCard
                        controlButtons
                        radiusLegendCard
                        nearbyList
                        statsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(vm: vm)
            }
            .task {
                await vm.loadAndStart()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack {
            Text("🚦")
                .font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("Traffic Signal Alert")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("iOS")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Circle()
                .fill(vm.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            Text(vm.isTracking ? "Active" : "Stopped")
                .font(.caption)
                .foregroundColor(vm.isTracking ? .green : .gray)
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Speed banner

    @ViewBuilder
    private var speedBanner: some View {
        if vm.speedStatus == .tooSlow {
            bannerView(text: "Too slow — speed up to \(Int(vm.settings.minSpeedKmh)) km/h to enable alerts",
                       color: .orange)
        } else if vm.speedStatus == .tooFast {
            bannerView(text: "Too fast — alerts disabled above \(Int(vm.settings.maxSpeedKmh)) km/h",
                       color: .orange)
        }
    }

    // MARK: - Alert banner

    @ViewBuilder
    private var alertBanner: some View {
        if vm.alertBannerColor != .none {
            bannerView(text: vm.alertBannerText, color: bannerColor(vm.alertBannerColor))
        }
    }

    private func bannerColor(_ c: AlertViewModel.AlertBannerColor) -> Color {
        switch c {
        case .none:   return .clear
        case .green:  return .green
        case .orange: return .orange
        case .red:    return .red
        }
    }

    private func bannerView(text: String, color: Color) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - Nearest signal card

    @ViewBuilder
    private var nearestSignalCard: some View {
        if let signal = vm.nearestSignal, let dist = vm.nearestDistance {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nearest Signal")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(signal.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack {
                    Text(signal.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(dist)) m")
                        .font(.subheadline.bold())
                        .foregroundColor(.cyan)
                    speedPill
                }
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
        }
    }

    private var speedPill: some View {
        Text("\(Int(vm.speedKmh)) km/h")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.3))
            .foregroundColor(.cyan)
            .cornerRadius(8)
    }

    // MARK: - Control buttons

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // START — active (green) when not tracking; muted grey when already tracking
            Button {
                vm.startTracking()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    vm.isTracking
                        ? Color(white: 0.25)          // disabled: dark grey slab
                        : Color.green
                )
                .foregroundColor(
                    vm.isTracking
                        ? Color(white: 0.45)          // disabled: mid-grey text
                        : .white
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            vm.isTracking ? Color(white: 0.35) : Color.green,
                            lineWidth: vm.isTracking ? 1 : 0
                        )
                )
            }
            .disabled(vm.isTracking)

            // STOP — active (red) when tracking; muted grey when already stopped
            Button {
                vm.stopTracking()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    vm.isTracking
                        ? Color.red
                        : Color(white: 0.25)          // disabled: dark grey slab
                )
                .foregroundColor(
                    vm.isTracking
                        ? .white
                        : Color(white: 0.45)          // disabled: mid-grey text
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            vm.isTracking ? Color.red : Color(white: 0.35),
                            lineWidth: vm.isTracking ? 0 : 1
                        )
                )
            }
            .disabled(!vm.isTracking)
        }
    }

    // MARK: - Radius legend card

    private var radiusLegendCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Alert Radius")
                .font(.caption)
                .foregroundColor(.gray)
            legendRow(label: "17–30 km/h",  radius: "\(Int(vm.settings.radius17to30)) m")
            legendRow(label: "30–50 km/h",  radius: "\(Int(vm.settings.radius30to50)) m")
            legendRow(label: "50–60 km/h",  radius: "\(Int(vm.settings.radius50to60)) m")
            legendRow(label: "60–70 km/h",  radius: "\(Int(vm.settings.radius60to70)) m")
            legendRow(label: "70–100 km/h", radius: "\(Int(vm.settings.radius70to100)) m")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .cornerRadius(12)
    }

    private func legendRow(label: String, radius: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(radius)
                .font(.caption.bold())
                .foregroundColor(.cyan)
        }
    }

    // MARK: - Nearby signals list

    @ViewBuilder
    private var nearbyList: some View {
        if !vm.nearbySignals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Signals within range (\(vm.nearbySignals.count))")
                    .font(.caption)
                    .foregroundColor(.gray)

                ForEach(vm.nearbySignals.prefix(8), id: \.signal.id) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.signal.name)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text(item.signal.type)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(item.distance)) m")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                    }
                    .padding(.vertical, 4)

                    if item.signal.id != vm.nearbySignals.prefix(8).last?.signal.id {
                        Divider().background(Color.gray.opacity(0.3))
                    }
                }
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        HStack {
            statItem(label: "Signals", value: "\(vm.signalCount)")
            Divider()
                .frame(height: 30)
                .background(Color.gray.opacity(0.4))
            statItem(label: "Alerts Fired", value: "\(vm.alertsFired)")
            Divider()
                .frame(height: 30)
                .background(Color.gray.opacity(0.4))
            statItem(label: "Speed", value: "\(Int(vm.speedKmh)) km/h")
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
}
