//
//  WatchWaymarkCenter.swift
//  Pace Up Watch
//
//  The wrist half of waymarks:
//    • keeps a copy of the phone's waymarks (sent over WatchConnectivity),
//    • taps you when a workout takes you back past one,
//    • lets you drop a new one by voice, and
//    • points the way to the nearest memory.
//
//  Location is used only while a workout is running, or for a single fix
//  when the home screen is open. Nothing leaves the Watch except to the
//  paired iPhone.
//

import Foundation
import CoreLocation
import WatchConnectivity
import WatchKit
import Combine

/// Mirror of `WaymarkWire` on the phone. Keep field names identical.
struct WatchWaymark: Codable, Identifiable, Equatable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var radius: Double
    var kind: String
    var title: String
    var text: String?
    var createdAt: Date
    var sealedUntil: Date?
    var opened: Bool
    var hasPhoto: Bool
    var hasVoice: Bool

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var isCapsule: Bool { kind == "capsule" }
    func isSealed(at date: Date = .now) -> Bool { isCapsule && (sealedUntil.map { date < $0 } ?? false) }
    func isReady(at date: Date = .now) -> Bool { isCapsule && !isSealed(at: date) && !opened }

    var symbol: String {
        switch kind {
        case "photo": return "camera.fill"
        case "voice": return "waveform"
        case "capsule": return "envelope.badge.fill"
        default: return "text.quote"
        }
    }
}

struct WatchDrop: Codable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var title: String
    var text: String
    var createdAt: Date
    var sealedUntil: Date?
}

struct WatchVisit: Codable {
    var id: UUID
    var date: Date
}

struct WatchEncounter: Identifiable, Equatable {
    enum Kind: Equatable { case memory, capsuleOpened, capsuleSealed(Date) }
    let id = UUID()
    let waymark: WatchWaymark
    let kind: Kind
}

@MainActor
final class WatchWaymarkCenter: NSObject, ObservableObject {

    @Published private(set) var waymarks: [WatchWaymark] = []
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLLocationDirection?
    @Published var encounter: WatchEncounter?
    @Published private(set) var droppedThisWorkout = 0

    private let manager = CLLocationManager()
    private var isTracking = false
    private var surfaced: Set<UUID> = []
    private var droppedIDs: Set<UUID> = []
    private var lastVisits: [UUID: Date] = [:]

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "waymarks.json")
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        load()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: Nearest

    /// The closest waymark that still has something to give: a memory, or a
    /// capsule ready to open. Sealed capsules are excluded — pointing someone
    /// at a lock they cannot open is a tease.
    var nearest: (waymark: WatchWaymark, distance: CLLocationDistance, bearing: Double)? {
        guard let location else { return nil }
        return waymarks
            .filter { !$0.isSealed() && !droppedIDs.contains($0.id) }
            .map { ($0, location.distance(from: $0.location)) }
            .min { $0.1 < $1.1 }
            .map { ($0.0, $0.1, Self.bearing(from: location.coordinate, to: $0.0.location.coordinate)) }
    }

    var sealedCount: Int { waymarks.filter { $0.isSealed() }.count }
    var readyCount: Int { waymarks.filter { $0.isReady() }.count }

    // MARK: Location

    /// One fix for the home screen.
    func refreshLocation() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.requestLocation()
    }

    func startWorkoutTracking() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        isTracking = true
        surfaced = []
        droppedIDs = []
        droppedThisWorkout = 0
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stopWorkoutTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func evaluate(_ location: CLLocation) {
        guard isTracking, location.horizontalAccuracy > 0, location.horizontalAccuracy <= 50 else { return }
        let now = Date.now
        for waymark in waymarks where !surfaced.contains(waymark.id) && !droppedIDs.contains(waymark.id) {
            if let last = lastVisits[waymark.id], now.timeIntervalSince(last) < 4 * 3600 { continue }
            if now.timeIntervalSince(waymark.createdAt) < 120 { continue }
            guard location.distance(from: waymark.location) <= waymark.radius + min(location.horizontalAccuracy, 20) else { continue }

            surfaced.insert(waymark.id)
            lastVisits[waymark.id] = now

            let kind: WatchEncounter.Kind
            if waymark.isSealed(at: now), let until = waymark.sealedUntil {
                kind = .capsuleSealed(until)
            } else if waymark.isReady(at: now) {
                kind = .capsuleOpened
                markOpened(waymark.id)
            } else {
                kind = .memory
            }
            WKInterfaceDevice.current().play(kind == .memory ? .notification : .success)
            encounter = WatchEncounter(waymark: waymark, kind: kind)
            send(["visit": WatchVisit(id: waymark.id, date: now)])
            break
        }
    }

    // MARK: Drop

    /// Leaves a waymark at the current position. The phone stores it; the
    /// Watch keeps a local copy so it shows up straight away.
    @discardableResult
    func drop(title: String, text: String, sealFor months: Int?) -> Bool {
        guard let location else { return false }
        let id = UUID()
        let sealedUntil = months.flatMap { Calendar.current.date(byAdding: .month, value: $0, to: .now) }
        let drop = WatchDrop(id: id, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                             title: title, text: text, createdAt: .now, sealedUntil: sealedUntil)
        send(["drop": drop])

        waymarks.insert(WatchWaymark(id: id, latitude: drop.latitude, longitude: drop.longitude, radius: 45,
                                     kind: sealedUntil == nil ? "note" : "capsule",
                                     title: sealedUntil == nil ? title : "Sealed capsule",
                                     text: sealedUntil == nil ? text : nil,
                                     createdAt: .now, sealedUntil: sealedUntil, opened: false,
                                     hasPhoto: false, hasVoice: false), at: 0)
        droppedIDs.insert(id)
        droppedThisWorkout += 1
        save()
        WKInterfaceDevice.current().play(.success)
        return true
    }

    // MARK: Sync

    private func send<T: Encodable>(_ payload: [String: T]) {
        guard WCSession.default.activationState == .activated,
              let entry = payload.first,
              let data = try? JSONEncoder().encode(entry.value) else { return }
        // transferUserInfo is queued and delivered even if the phone is out
        // of range right now.
        WCSession.default.transferUserInfo([entry.key: data])
    }

    private func markOpened(_ id: UUID) {
        guard let index = waymarks.firstIndex(where: { $0.id == id }) else { return }
        waymarks[index].opened = true
        save()
    }

    fileprivate func receive(context: [String: Any]) {
        guard let data = context["waymarks"] as? Data,
              let list = try? JSONDecoder().decode([WatchWaymark].self, from: data) else { return }
        waymarks = list
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let list = try? JSONDecoder().decode([WatchWaymark].self, from: data) else { return }
        waymarks = list
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(waymarks) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: Geometry

    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func compassPoint(_ bearing: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return points[Int((bearing + 22.5) / 45) % 8]
    }
}

extension WatchWaymarkCenter: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.location = latest
            self.evaluate(latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = value }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension WatchWaymarkCenter: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.receive(context: context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receive(context: applicationContext) }
    }
}
