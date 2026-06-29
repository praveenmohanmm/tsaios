import Foundation
import Combine
import UIKit
import AVFoundation

@MainActor
final class AlertViewModel: ObservableObject {

    /// Shared instance used by App Intents (Siri) so they reach the live
    /// in-process state rather than spinning up a separate instance.
    static let shared = AlertViewModel()

    // MARK: - Published state

    @Published var isTracking: Bool = false
    @Published var signalCount: Int = 0
    @Published var alertsFired: Int = 0
    @Published var speedKmh: Double = 0.0
    @Published var nearestSignal: TrafficSignal?
    @Published var nearestDistance: Double?
    @Published var nearbySignals: [(signal: TrafficSignal, distance: Double)] = []
    @Published var alertBannerText: String = ""
    @Published var alertBannerColor: AlertBannerColor = .none
    @Published var speedStatus: SpeedStatus = .ok
    @Published var settings: AlertSettings = AlertSettings.load()

    // MARK: - Alert banner color

    enum AlertBannerColor {
        case none, green, orange, red
    }

    enum SpeedStatus {
        case ok, tooSlow, tooFast
    }

    // MARK: - Private

    private let locationManager = LocationManager()
    private let signalService = TrafficSignalService()
    private let audioService = AudioService()
    private let connectionMonitor = ConnectionMonitor()
    private var cancellables = Set<AnyCancellable>()

    /// IDs of signals that have fired and must leave (radius + 50m) before alerting again.
    private var alertedSignalIds = Set<Int>()
    private var processingUpdate = false

    /// Fires after 15 minutes of continuous slow/stopped speed to auto-stop scanning.
    private var idleStopTask: Task<Void, Never>?
    private let synthesizer = AVSpeechSynthesizer()

    /// How long the user must be stationary/slow before scanning stops (15 minutes).
    private let idleStopInterval: TimeInterval = 15 * 60

    // MARK: - Init

    init() {
        locationManager.requestPermission()
        _ = PhoneSessionManager.shared   // activate WCSession at launch
        subscribeToLocation()
        subscribeToConnection()
    }

    // MARK: - Public API

    func loadAndStart() async {
        await signalService.loadSignals()
        signalCount = signalService.signals.count
        // CarPlay may already have been connected before signals finished
        // loading (e.g. app opened while already in the car) — the one-time
        // connect notification would have been missed by subscribeToConnection.
        if connectionMonitor.isConnected, !isTracking {
            startTracking()
        }
    }

    func startTracking() {
        guard !isTracking else { return }
        alertedSignalIds.removeAll()   // fresh session — don't suppress alerts from a prior run
        isTracking = true
        UIApplication.shared.isIdleTimerDisabled = true
        locationManager.startUpdating()
    }

    func stopTracking() {
        guard isTracking else { return }
        cancelIdleTimer()
        isTracking = false
        UIApplication.shared.isIdleTimerDisabled = false
        locationManager.stopUpdating()
        clearAlertState()
    }

    /// Stops (if running) and starts again with a clean alert state.
    /// Used by "Start Scanning" so repeated invocations always re-arm fully.
    func restartTracking() {
        if isTracking {
            stopTracking()
        }
        startTracking()
    }

    func saveSettings() {
        settings.save()
    }

    /// Fires an alert (audio + iPhone haptic + Watch notification) without
    /// requiring the user to be near a real signal — used by the
    /// "Test Alert" button on the Settings screen.
    func testAlert() {
        fireAlert(distanceMetres: 50)
    }

    // MARK: - Connection subscription (CarPlay connect only — disconnect is ignored)

    private func subscribeToConnection() {
        connectionMonitor.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] connected in
                guard let self, connected else { return }
                guard self.signalCount > 0, !self.isTracking else { return }
                self.startTracking()
            }
            .store(in: &cancellables)
    }

    // MARK: - Location subscription

    private func subscribeToLocation() {
        Publishers.CombineLatest(locationManager.$latitude, locationManager.$longitude)
            .combineLatest(locationManager.$speedMs)
            .receive(on: RunLoop.main)
            .sink { [weak self] combined, speedMs in
                guard let self = self else { return }
                let (lat, lon) = combined
                self.handleLocationUpdate(lat: lat, lon: lon, speedMs: speedMs)
            }
            .store(in: &cancellables)
    }

    // MARK: - Core processing

    private func handleLocationUpdate(lat: Double, lon: Double, speedMs: Double) {
        guard isTracking else { return }
        guard !processingUpdate else { return }   // re-entrancy guard
        guard lat != 0 || lon != 0 else { return }

        processingUpdate = true
        defer { processingUpdate = false }

        let kmh = speedMs * 3.6
        speedKmh = kmh

        // Speed gate check
        guard let radius = settings.alertRadius(forSpeedKmh: kmh) else {
            if kmh < settings.minSpeedKmh {
                speedStatus = .tooSlow
                armIdleTimer()   // start 15-min countdown while not driving
            } else {
                speedStatus = .tooFast
                cancelIdleTimer()
            }
            clearAlertState()
            return
        }
        speedStatus = .ok
        cancelIdleTimer()        // moving at driving speed — reset countdown

        // Update nearest signal
        if let closest = signalService.getClosest(lat: lat, lon: lon) {
            nearestSignal = closest.signal
            nearestDistance = closest.distance

            // Update alert banner color
            let dist = closest.distance
            if dist <= radius {
                if dist < 30 { alertBannerColor = .red }
                else if dist < 60 { alertBannerColor = .orange }
                else { alertBannerColor = .green }
                alertBannerText = "Signal ahead — \(Int(dist))m"
            } else {
                alertBannerColor = .none
                alertBannerText = ""
            }
        }

        // Nearby signals list
        nearbySignals = signalService.getNearby(lat: lat, lon: lon, radius: radius)

        // Hysteresis: clear alerted IDs for signals that moved far enough away
        let hysteresisRadius = radius + 50.0
        alertedSignalIds = alertedSignalIds.filter { id in
            guard let signal = signalService.signals.first(where: { $0.id == id }) else { return false }
            let d = TrafficSignalService.haversine(lat1: lat, lon1: lon, lat2: signal.latitude, lon2: signal.longitude)
            return d <= hysteresisRadius
        }

        // Fire alerts for any nearby signals not already alerted
        for item in nearbySignals {
            guard !alertedSignalIds.contains(item.signal.id) else { continue }
            alertedSignalIds.insert(item.signal.id)
            alertsFired += 1
            fireAlert(distanceMetres: Int(item.distance))
            break  // one alert per update cycle
        }
    }

    private func fireAlert(distanceMetres: Int) {
        // iPhone haptic
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)

        // Audio (plays in background via UIBackgroundModes: audio)
        audioService.play(settings.tone)

        // Apple Watch — direct WCSession message
        PhoneSessionManager.shared.sendHaptic(distanceMetres: distanceMetres,
                                              pattern: settings.hapticPattern)
    }

    // MARK: - Idle auto-stop

    private func armIdleTimer() {
        guard idleStopTask == nil else { return }   // already counting down
        idleStopTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(idleStopInterval * 1_000_000_000))
            } catch {
                return   // cancelled — user started driving again or stopped manually
            }
            stopTracking()
            speak("You have not been driving for 15 minutes. Stopping traffic signal scanning.")
        }
    }

    private func cancelIdleTimer() {
        idleStopTask?.cancel()
        idleStopTask = nil
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.volume = 1.0
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private func clearAlertState() {
        nearestSignal = nil
        nearestDistance = nil
        nearbySignals = []
        alertBannerColor = .none
        alertBannerText = ""
    }
}
