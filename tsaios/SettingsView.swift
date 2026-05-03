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
                            step: 5
                        )
                        .onChange(of: vm.settings.minSpeedKmh) { _ in
                            if vm.settings.minSpeedKmh >= vm.settings.maxSpeedKmh {
                                vm.settings.minSpeedKmh = vm.settings.maxSpeedKmh - 5
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
                            step: 5
                        )
                        .onChange(of: vm.settings.maxSpeedKmh) { _ in
                            if vm.settings.maxSpeedKmh <= vm.settings.minSpeedKmh {
                                vm.settings.maxSpeedKmh = vm.settings.minSpeedKmh + 5
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
                    radiusRow(label: "< 30 km/h", radius: "80 m")
                    radiusRow(label: "30–50 km/h", radius: "100 m")
                    radiusRow(label: "50–70 km/h", radius: "120 m")
                    radiusRow(label: "> 70 km/h", radius: "150 m")
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
