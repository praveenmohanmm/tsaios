import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: AlertViewModel
    @Environment(\.dismiss) private var dismiss

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

                Section(header: Text("Test"),
                        footer: Text("Plays the selected tone, vibrates iPhone, and posts a time-sensitive notification (Apple Watch should buzz).")) {
                    Button {
                        vm.testAlert()
                    } label: {
                        Label("Test Audio & Haptics", systemImage: "waveform.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
