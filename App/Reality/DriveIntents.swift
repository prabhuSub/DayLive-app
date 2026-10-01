import AppIntents
import Foundation
import MapKit

/// For a Shortcuts automation: "When my Tesla connects → Hyperday › I'm driving".
/// iOS doesn't let apps watch Bluetooth/CarPlay in the background, so the automation tells us.
struct ImDrivingIntent: AppIntent {
    static var title: LocalizedStringResource = "I'm driving"
    static var description = IntentDescription("Tell Hyperday you started driving. Use it in a Shortcuts automation when your car connects.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RealityStore.shared.record(.driveStart)
        await LiveActivityManager.shared.refresh()
        return .result()
    }
}

struct ArrivedIntent: AppIntent {
    static var title: LocalizedStringResource = "Arrived"
    static var description = IntentDescription("Tell Hyperday you stopped driving. Use it in a Shortcuts automation when your car disconnects.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RealityStore.shared.record(.driveEnd)
        await LiveActivityManager.shared.refresh()
        return .result()
    }
}

/// #9 Drive card: arrival time from Apple Maps to the next block's location (or your Office).
@MainActor
enum DriveETA {
    private static var cache: (key: String, at: Date, arrive: Date)?

    static func arrival(to address: String?, orPlace place: Place?) async -> Date? {
        let key = address ?? place?.id ?? ""
        guard !key.isEmpty else { return nil }
        if let c = cache, c.key == key, Date.now.timeIntervalSince(c.at) < 180 { return c.arrive }

        var destination: MKMapItem?
        if let address, let mark = try? await CLGeocoder().geocodeAddressString(address).first {
            destination = MKMapItem(placemark: MKPlacemark(placemark: mark))
        } else if let place {
            destination = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        }
        guard let destination else { return nil }
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return nil }
        let arrive = Date.now.addingTimeInterval(eta.expectedTravelTime)
        cache = (key, .now, arrive)
        return arrive
    }
}
