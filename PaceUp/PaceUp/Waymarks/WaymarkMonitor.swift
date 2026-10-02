//
//  WaymarkMonitor.swift
//  Pace Up
//
//  Decides when a waymark comes back.
//
//  This only runs while an activity is recording. Pace Up never asks for
//  Always location and never watches the user in the background outside a
//  recording — the same promise the rest of the app makes. The consequence is
//  the point of the feature: memories return to people who are out moving.
//
//  Rules, in order:
//    1. The fix must be accurate to 50 m or better.
//    2. The user must be inside the waymark's radius (plus a little slack for
//       the fix's own error, capped so a poor fix cannot widen it much).
//    3. Nothing dropped during the current recording comes back in it.
//    4. A waymark visited in the last four hours stays quiet — walking a loop
//       around the park should not buzz you twice.
//    5. Each waymark surfaces at most once per recording.
//

import Foundation
import SwiftData
import CoreLocation
import UIKit
import UserNotifications
import Observation

/// One moment of "you were here".
struct WaymarkEncounter: Identifiable, Equatable {
    enum Kind: Equatable {
        /// A note, photo or voice memo.
        case memory
        /// A capsule whose date had passed, opened just now by walking back.
        case capsuleOpened
        /// A capsule that is still sealed. Shown as a teaser with its date.
        case capsuleSealed(until: Date)
    }

    let id = UUID()
    let waymarkID: UUID
    let kind: Kind
    let title: String
    let createdAt: Date
    let previousVisits: Int
}

@MainActor
@Observable
final class WaymarkMonitor {

    static let shared = WaymarkMonitor()

    /// The encounter on screen, if any. Further encounters queue behind it.
    private(set) var current: WaymarkEncounter?
    private var queue: [WaymarkEncounter] = []

    /// Waymarks dropped during the current recording.
    private(set) var droppedThisSession: [UUID] = []
    /// Waymarks that came back during the current recording.
    private(set) var encounteredThisSession: [UUID] = []

    private var context: ModelContext?
    private var candidates: [Waymark] = []
    private var sessionID: UUID?
    private var lastEvaluated: CLLocation?

    private let quietPeriod: TimeInterval = 4 * 3600
    private let maximumAccuracy: CLLocationAccuracy = 50

    /// Debug demo data only: lets the same waymark surface on every test walk.
    private static var ignoresQuietPeriod: Bool {
        #if DEBUG
        return WaymarkDemoSeed.isRequested
        #else
        return false
        #endif
    }

    func configure(context: ModelContext) {
        self.context = context
    }

    // MARK: Session

    func beginSession(_ id: UUID) {
        sessionID = id
        droppedThisSession = []
        encounteredThisSession = []
        queue = []
        current = nil
        lastEvaluated = nil
        reloadCandidates()
    }

    func reloadCandidates() {
        guard let context else { return }
        candidates = WaymarkStore(context: context).all()
    }

    func noteDropped(_ waymark: Waymark) {
        droppedThisSession.append(waymark.id)
        reloadCandidates()
    }

    func dismissCurrent() {
        current = queue.isEmpty ? nil : queue.removeFirst()
    }

    // MARK: Evaluation

    /// Called by the recorder for every accepted fix.
    func evaluate(_ location: CLLocation) {
        guard sessionID != nil, let context else { return }
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= maximumAccuracy else { return }

        // Checking every fix is wasteful; every ten metres is plenty for a
        // 45 m radius.
        if let lastEvaluated, location.distance(from: lastEvaluated) < 10 { return }
        lastEvaluated = location

        let now = Date.now
        let slack = min(location.horizontalAccuracy, 20)
        let store = WaymarkStore(context: context)

        for waymark in candidates {
            guard !droppedThisSession.contains(waymark.id),
                  !encounteredThisSession.contains(waymark.id) else { continue }
            if let last = waymark.lastVisit, now.timeIntervalSince(last) < quietPeriod, !Self.ignoresQuietPeriod { continue }
            // Dropped a moment ago in a recording that has just ended: give it two
            // minutes. Short enough that walking straight back out finds it.
            if now.timeIntervalSince(waymark.createdAt) < 120 { continue }

            let distance = location.distance(from: waymark.location)
            guard distance <= waymark.radius + slack else { continue }

            let kind: WaymarkEncounter.Kind
            if waymark.isSealed(at: now), let until = waymark.sealedUntil {
                kind = .capsuleSealed(until: until)
            } else if waymark.isWaitingToBeOpened(at: now) {
                kind = .capsuleOpened
            } else {
                kind = .memory
            }

            let encounter = WaymarkEncounter(
                waymarkID: waymark.id,
                kind: kind,
                title: waymark.title,
                createdAt: waymark.createdAt,
                previousVisits: waymark.visitCount
            )

            encounteredThisSession.append(waymark.id)
            store.recordVisit(waymark, at: now)
            present(encounter)
        }
    }

    private func present(_ encounter: WaymarkEncounter) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if UIApplication.shared.applicationState != .active {
            WaymarkNotifications.post(encounter)
        }

        if current == nil {
            current = encounter
        } else {
            queue.append(encounter)
        }
    }
}

// MARK: - Notifications

/// A phone in a pocket cannot show a card. A local notification is the only
/// way a memory reaches someone mid-walk with the screen off.
enum WaymarkNotifications {

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func post(_ encounter: WaymarkEncounter) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.threadIdentifier = "waymarks"

        let ago = WaymarkFormat.ago(encounter.createdAt)
        switch encounter.kind {
        case .memory:
            content.title = String(localized: "You were here \(ago)")
            content.body = encounter.title
        case .capsuleOpened:
            content.title = String(localized: "A time capsule just opened")
            content.body = String(localized: "You sealed “\(encounter.title)” here \(ago). It's yours to read now.")
        case .capsuleSealed(let until):
            content.title = String(localized: "You're standing on a sealed capsule")
            content.body = String(localized: "“\(encounter.title)” opens \(until.formatted(date: .long, time: .omitted)). Come back then.")
        }

        let request = UNNotificationRequest(identifier: encounter.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

enum WaymarkFormat {
    /// "3 weeks ago", "a year ago".
    static func ago(_ date: Date, relativeTo now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// "Opens in 4 months".
    static func opensIn(_ date: Date, relativeTo now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(localized: "Opens \(formatter.localizedString(for: date, relativeTo: now))")
    }
}
