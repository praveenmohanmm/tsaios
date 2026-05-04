import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var vm: AlertViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var testConfirmation: String = ""
    @State private var notificationsAllowed: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Speed Range (km/h)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum: \(Int(vm.settings.minSpeedKmh)) km/h")
                            .font(.subheadline)
                        Slider(
                            value: $vm.settings.minSpeedKmh,
                            in: 0...60,
                            step: 1
                        )
                        .onChange(of: vm.settings.minSpeedKmh) { _ in
                            if vm.settings.minSpeedKmh >= vm.settings.maxSpeedKmh {
                                vm.settings.minSpeedKmh = vm.settings.maxSpeedKmh - 1
                            }
                            vm.saveSettings()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum: \(Int(vm.settings.maxSpeedKmh)) km/h")
                            .font(.subheadline)
                        Slider(
                            value: $vm.settings.maxSpeedKmh,
                            in: 20...150,
                            step: 1
                        )
                        .onChange(of: vm.settings.maxSpeedKmh) { _ in
                            if vm.settings.maxSpeedKmh <= vm.settings.minSpeedKmh {
                                vm.settings.maxSpeedKmh = vm.settings.minSpeedKmh + 1
                            }
                            vm.saveSettings()
                        }
                    }
                }

                Section(header: Text("Alert Tone")) {
                    Picker("Tone", selection: $vm.settings.tone) {
                        ForEach(AlertTone.allCases, id: \.self) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.settings.tone) { _ in
                        vm.saveSettings()
                    }
                }

                Section(header: Text("Alert Radius (by speed)")) {
                    radiusRow(label: "17–30 km/h",  radius: "50 m")
                    radiusRow(label: "30–50 km/h",  radius: "60 m")
                    radiusRow(label: "50–60 km/h",  radius: "80 m")
                    radiusRow(label: "60–70 km/h",  radius: "90 m")
                    radiusRow(label: "70–100 km/h", radius: "100 m")
                }

                Section(
                    header: Text("Test"),
                    footer: testFooter
                ) {
                    Button {
                        runTest()
                    } label: {
                        HStack {
                            Label("Test Audio & Haptics", systemImage: "waveform.circle.fill")
                                .font(.subheadline.bold())
                            Spacer()
                            if !testConfirmation.isEmpty {
                                Text(testConfirmation)
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    if !notificationsAllowed {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Notifications are off — Watch haptic won't fire. Enable in Settings → Alert ME → Notifications.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await checkNotificationPermission()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var testFooter: some View {
        Text("Plays the selected tone and vibrates the iPhone. The Apple Watch will buzz if Notifications are allowed and the iPhone screen is off.")
    }

    private func runTest() {
        testConfirmation = ""
        vm.testAlert()
        testConfirmation = "✓ Fired!"
        // Clear the confirmation label after 2 seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testConfirmation = ""
        }
    }

    private func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAllowed = settings.authorizationStatus == .authorized ||
                               settings.authorizationStatus == .provisional
    }

    private func radiusRow(label: String, radius: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(radius)
                .foregroundColor(.secondary)
        }
    }
}
