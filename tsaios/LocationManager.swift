import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var speedMs: Double = 0.0          // metres per second, ≥ 0
    @Published var isAuthorized: Bool = false
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()
    private var previousLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .automotiveNavigation
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        // Haversine-derived speed fallback when device speed is unavailable
        let computedSpeed: Double
        if loc.speed >= 0 {
            computedSpeed = loc.speed
        } else if let prev = previousLocation {
            let dist = loc.distance(from: prev)
            let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
            computedSpeed = dt > 0 ? dist / dt : 0
        } else {
            computedSpeed = 0
        }
        previousLocation = loc

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
            self.speedMs = computedSpeed
            self.lastLocation = loc
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }
}
