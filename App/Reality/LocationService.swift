import CoreLocation
import Foundation

/// Watches your Home / Office / Gym areas (region monitoring: iOS wakes the app on arrive/leave,
/// no continuous GPS). Needs "Always" location to work in the background.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var oneShot: ((CLLocation?) -> Void)?

    override private init() {
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    /// "Set to here": ask for permission if needed, then return one location fix.
    func currentLocation(_ done: @escaping (CLLocation?) -> Void) {
        oneShot = done
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: oneShot = nil; done(nil)
        default: manager.requestLocation()
        }
    }

    /// Start (or refresh) watching the saved places. Asks for "Always" once places exist.
    func monitor(_ places: [Place]) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        if manager.authorizationStatus == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
        for r in manager.monitoredRegions { manager.stopMonitoring(for: r) }
        for p in places {
            let region = CLCircularRegion(center: p.coordinate, radius: max(100, p.radius), identifier: p.name)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }
    }

    // MARK: Delegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if oneShot != nil, manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let cb = oneShot
        oneShot = nil
        cb?(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let cb = oneShot
        oneShot = nil
        cb?(nil)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            RealityStore.shared.record(.arrived, place: region.identifier)
            await LiveActivityManager.shared.refresh()
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            RealityStore.shared.record(.departed, place: region.identifier)
            await LiveActivityManager.shared.refresh()
        }
    }
}
