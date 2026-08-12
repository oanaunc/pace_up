//
//  LocationProvider.swift
//  Pace Up
//
//  Thin, non-isolated wrapper around CLLocationManager.
//
//  Keeping the delegate out of the `@MainActor` recorder avoids the actor
//  isolation contortions that come from conforming an isolated class to a
//  non-isolated Objective-C protocol.
//

import Foundation
import CoreLocation

final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    var onLocations: (([CLLocation]) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus, CLAccuracyAuthorization) -> Void)?
    var onFailure: ((Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        // Core Location's own auto-pause suspends updates without telling the
        // app in a way we can reliably resume from. Pace Up implements its own
        // auto-pause on top of the raw stream instead.
        manager.pausesLocationUpdatesAutomatically = false
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var accuracyAuthorization: CLAccuracyAuthorization { manager.accuracyAuthorization }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Asks for temporary full accuracy when the user has granted only
    /// approximate location. Approximate location is useless for a route.
    func requestFullAccuracy() {
        manager.requestTemporaryFullAccuracyAuthorization(
            withPurposeKey: "PreciseLocationForRouteTracking"
        )
    }

    /// Low-power updates used before recording starts, so the map can centre on
    /// the user and the GPS-ready indicator can settle.
    func startPreview() {
        manager.allowsBackgroundLocationUpdates = false
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.startUpdatingLocation()
    }

    /// Full-rate updates with background delivery enabled.
    ///
    /// `allowsBackgroundLocationUpdates` requires the `location` background
    /// mode in the target's capabilities. With When In Use authorization the
    /// system shows the blue status indicator for the whole recording, which is
    /// the correct and expected behaviour for a run tracker.
    func startRecording() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let handler = onLocations
        Task { @MainActor in handler?(locations) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let handler = onAuthorizationChange
        let status = manager.authorizationStatus
        let accuracy = manager.accuracyAuthorization
        Task { @MainActor in handler?(status, accuracy) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown is transient — Core Location is still trying.
        if let clError = error as? CLError, clError.code == .locationUnknown { return }
        let handler = onFailure
        Task { @MainActor in handler?(error) }
    }
}
