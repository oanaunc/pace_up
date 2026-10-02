//
//  WaymarkStore.swift
//  Pace Up
//
//  Reads and writes waymarks. Thin on purpose: SwiftData does the storage,
//  this keeps the side effects (media files, widget, Watch sync) in one place.
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
struct WaymarkStore {

    let context: ModelContext

    // MARK: Read

    func all() -> [Waymark] {
        let descriptor = FetchDescriptor<Waymark>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func waymark(id: UUID) -> Waymark? {
        var descriptor = FetchDescriptor<Waymark>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Waymarks left on this calendar day in earlier years — "On this day".
    func onThisDay(_ date: Date = .now, calendar: Calendar = .current) -> [Waymark] {
        let today = calendar.dateComponents([.month, .day, .year], from: date)
        return all().filter {
            let c = calendar.dateComponents([.month, .day, .year], from: $0.createdAt)
            return c.month == today.month && c.day == today.day && c.year != today.year
        }
    }

    // MARK: Write

    @discardableResult
    func insert(_ waymark: Waymark) -> Waymark {
        context.insert(waymark)
        try? context.save()
        didChange()
        return waymark
    }

    func delete(_ waymark: Waymark) {
        WaymarkMedia.deleteAudio(named: waymark.audioFileName)
        context.delete(waymark)
        try? context.save()
        didChange()
    }

    func deleteAll() {
        try? context.delete(model: Waymark.self)
        try? context.save()
        WaymarkMedia.deleteAll()
        didChange()
    }

    /// Records that the user walked back past a waymark. Opens a capsule whose
    /// date has come.
    func recordVisit(_ waymark: Waymark, at date: Date = .now) {
        waymark.visitDates.append(date)
        if waymark.isWaitingToBeOpened(at: date) {
            waymark.openedAt = date
        }
        try? context.save()
        didChange()
    }

    /// Side effects after any change: the widget and the Watch both hold a
    /// lightweight copy.
    func didChange() {
        let snapshot = all()
        WaymarkWidgetSnapshot.make(from: snapshot).save()
        WaymarkSync.shared.push(snapshot)
    }
}
