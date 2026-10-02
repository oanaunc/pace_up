//
//  WaymarkWidgetSnapshot.swift
//  Pace Up
//
//  What the Memory Lane widget shows. Mirrored by `MemoryLaneSnapshot` in the
//  widget target — keep the field names identical.
//

import Foundation
import WidgetKit

struct WaymarkWidgetSnapshot: Codable, Equatable {
    static let key = "waymarkWidgetSnapshot"
    static let widgetKind = "PaceUpMemoryLaneWidget"

    var totalWaymarks: Int
    var sealedCapsules: Int
    /// Capsules whose date has come but which nobody has walked back to.
    var capsulesWaiting: Int
    var nextCapsuleTitle: String?
    var nextCapsuleOpens: Date?
    /// Most recent "on this day" memory title and its year.
    var onThisDayTitle: String?
    var onThisDayYear: Int?
    var updatedAt: Date

    static func make(from waymarks: [Waymark], now: Date = .now) -> WaymarkWidgetSnapshot {
        let sealed = waymarks.filter { $0.isSealed(at: now) }
        let next = sealed.min { ($0.sealedUntil ?? .distantFuture) < ($1.sealedUntil ?? .distantFuture) }

        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day, .year], from: now)
        let onThisDay = waymarks.first {
            let c = calendar.dateComponents([.month, .day, .year], from: $0.createdAt)
            return c.month == today.month && c.day == today.day && c.year != today.year && $0.isReadable(at: now)
        }

        return WaymarkWidgetSnapshot(
            totalWaymarks: waymarks.count,
            sealedCapsules: sealed.count,
            capsulesWaiting: waymarks.filter { $0.isWaitingToBeOpened(at: now) }.count,
            nextCapsuleTitle: next.map { $0.addressedTo.map { String(localized: "To \($0)") } ?? String(localized: "Sealed capsule") },
            nextCapsuleOpens: next?.sealedUntil,
            onThisDayTitle: onThisDay?.title,
            onThisDayYear: onThisDay.map { calendar.component(.year, from: $0.createdAt) },
            updatedAt: now
        )
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }
}
