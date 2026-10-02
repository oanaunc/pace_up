//
//  WaymarkSync.swift
//  Pace Up
//
//  Keeps the Watch's copy of waymarks current, and accepts waymarks dropped
//  from the wrist. Phone ↔ Watch only, over WatchConnectivity. Nothing goes to
//  a server; there is no server.
//
//  The Watch gets a lightweight list (no photos, no audio, and no text for
//  capsules that are still sealed). That is enough for it to buzz when you
//  walk past, show the note, and point the way to the nearest one.
//

import Foundation
import SwiftData
import WatchConnectivity
import CoreLocation

/// Wire format shared with the Watch. Keep in sync with `WatchWaymark`.
struct WaymarkWire: Codable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var radius: Double
    var kind: String
    var title: String
    /// Note text, or nil for sealed capsules.
    var text: String?
    var createdAt: Date
    var sealedUntil: Date?
    var opened: Bool
    var hasPhoto: Bool
    var hasVoice: Bool
}

/// A waymark created on the Watch, sent to the phone to be stored.
struct WatchDrop: Codable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var title: String
    var text: String
    var createdAt: Date
    var sealedUntil: Date?
}

/// A visit recorded on the Watch.
struct WatchVisit: Codable {
    var id: UUID
    var date: Date
}

@MainActor
final class WaymarkSync: NSObject {

    static let shared = WaymarkSync()

    private var context: ModelContext?
    private var pending: [WaymarkWire]?

    /// The Watch only needs what it can reach on foot this season. 300 most
    /// recent keeps the application context comfortably under its size limit.
    private let maximumSynced = 300

    func activate(context: ModelContext) {
        self.context = context
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func push(_ waymarks: [Waymark]) {
        let wire = waymarks.prefix(maximumSynced).map(Self.wire(for:))
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pending = Array(wire)
            return
        }
        send(Array(wire), via: session)
    }

    private func send(_ wire: [WaymarkWire], via session: WCSession) {
        guard session.isPaired, session.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(wire) else { return }
        try? session.updateApplicationContext(["waymarks": data])
    }

    static func wire(for waymark: Waymark) -> WaymarkWire {
        let sealed = waymark.isSealed()
        return WaymarkWire(
            id: waymark.id,
            latitude: waymark.latitude,
            longitude: waymark.longitude,
            radius: waymark.radius,
            kind: waymark.kindRaw,
            title: sealed ? String(localized: "Sealed capsule") : waymark.title,
            text: sealed ? nil : (waymark.body.isEmpty ? nil : String(waymark.body.prefix(400))),
            createdAt: waymark.createdAt,
            sealedUntil: waymark.sealedUntil,
            opened: waymark.openedAt != nil,
            hasPhoto: waymark.photoData != nil,
            hasVoice: waymark.audioFileName != nil
        )
    }

    // MARK: Incoming

    fileprivate func receive(_ userInfo: [String: Any]) {
        guard let context else { return }
        let store = WaymarkStore(context: context)
        let decoder = JSONDecoder()

        if let data = userInfo["drop"] as? Data, let drop = try? decoder.decode(WatchDrop.self, from: data) {
            guard store.waymark(id: drop.id) == nil else { return }
            let waymark = Waymark(
                id: drop.id,
                createdAt: drop.createdAt,
                coordinate: CLLocationCoordinate2D(latitude: drop.latitude, longitude: drop.longitude),
                kind: drop.sealedUntil == nil ? .note : .capsule,
                title: drop.title,
                body: drop.text,
                sealedUntil: drop.sealedUntil,
                addressedTo: drop.sealedUntil == nil ? nil : String(localized: "Me, later")
            )
            store.insert(waymark)
        }

        if let data = userInfo["visit"] as? Data, let visit = try? decoder.decode(WatchVisit.self, from: data),
           let waymark = store.waymark(id: visit.id) {
            // The phone may already have counted the same pass if both were
            // recording. Within ten minutes is the same visit.
            if let last = waymark.lastVisit, abs(last.timeIntervalSince(visit.date)) < 600 { return }
            store.recordVisit(waymark, at: visit.date)
        }
    }
}

extension WaymarkSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let pending = self.pending {
                self.pending = nil
                self.send(pending, via: session)
            } else if let context = self.context {
                self.push(WaymarkStore(context: context).all())
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to a new Watch: reactivate so the new one gets the list.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let copy = userInfo
        Task { @MainActor in self.receive(copy) }
    }
}
