import Foundation

struct TrafficSignal: Identifiable {
    let id: Int
    let name: String
    let type: String
    let latitude: Double
    let longitude: Double
}

final class TrafficSignalService {

    private(set) var signals: [TrafficSignal] = []

    // MARK: - GeoJSON private decode structs

    private struct FeatureCollection: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let properties: Properties
        let geometry: Geometry
    }

    private struct Properties: Decodable {
        let IntersectionName: String?
        let IntersectionType: String?
    }

    private struct Geometry: Decodable {
        let coordinates: [Double]   // [longitude, latitude]
    }

    // MARK: - Load

    func loadSignals() async {
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json") else {
            print("TrafficSignalService: data.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            // Strip BOM if present
            let trimmed: Data
            if data.prefix(3) == Data([0xEF, 0xBB, 0xBF]) {
                trimmed = data.dropFirst(3)
            } else {
                trimmed = data
            }
            let collection = try JSONDecoder().decode(FeatureCollection.self, from: trimmed)
            signals = collection.features.enumerated().map { index, feature in
                TrafficSignal(
                    id: index,
                    name: feature.properties.IntersectionName ?? "Unknown",
                    type: feature.properties.IntersectionType ?? "Signal",
                    latitude: feature.geometry.coordinates.count > 1 ? feature.geometry.coordinates[1] : 0,
                    longitude: feature.geometry.coordinates.first ?? 0
                )
            }
            print("TrafficSignalService: loaded \(signals.count) signals")
        } catch {
            print("TrafficSignalService: decode error \(error)")
        }
    }

    // MARK: - Query

    /// Returns the nearest signal and its distance in metres.
    func getClosest(lat: Double, lon: Double) -> (signal: TrafficSignal, distance: Double)? {
        guard !signals.isEmpty else { return nil }
        var best: TrafficSignal?
        var bestDist = Double.greatestFiniteMagnitude
        for signal in signals {
            let d = haversine(lat1: lat, lon1: lon, lat2: signal.latitude, lon2: signal.longitude)
            if d < bestDist {
                bestDist = d
                best = signal
            }
        }
        guard let found = best else { return nil }
        return (found, bestDist)
    }

    /// Returns all signals within `radius` metres of the given point.
    func getNearby(lat: Double, lon: Double, radius: Double) -> [(signal: TrafficSignal, distance: Double)] {
        return signals.compactMap { signal in
            let d = haversine(lat1: lat, lon1: lon, lat2: signal.latitude, lon2: signal.longitude)
            return d <= radius ? (signal, d) : nil
        }.sorted { $0.distance < $1.distance }
    }

    // MARK: - Haversine

    static func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6_371_000.0
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let dPhi = (lat2 - lat1) * .pi / 180
        let dLambda = (lon2 - lon1) * .pi / 180
        let a = sin(dPhi/2) * sin(dPhi/2) +
                cos(phi1) * cos(phi2) * sin(dLambda/2) * sin(dLambda/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }

    func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        return TrafficSignalService.haversine(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
    }
}
