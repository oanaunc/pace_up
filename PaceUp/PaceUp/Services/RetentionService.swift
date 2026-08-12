//
//  RetentionService.swift
//  Pace Up
//
//  The 30-day cleanup.
//
//  ── What this deletes, and why it is scoped the way it is ──────────────────
//
//  Pace Up's own UI shows lifetime totals, personal records, streaks and
//  week-over-week comparisons. All of those are computed from activity
//  summaries. A retention policy that deleted whole activities would therefore
//  quietly destroy the app's own headline numbers: a 16.4 km longest run would
//  disappear thirty-one days after it happened, and the Profile screen's
//  activity count would stop counting.
//
//  So the default policy removes the *heavy* half — the full GPS trace and the
//  heart-rate series — and keeps the summary, the splits and a simplified
//  thumbnail route. That is where essentially all the bytes are: a one-hour run
//  is roughly 115 KB of trace against about 1 KB of summary.
//
//  `deleteEntireActivities` is offered as an explicit, separately confirmed
//  action for users who want history gone rather than slimmed.
//
//  Nothing here touches HealthKit. A user who asks Pace Up to forget old routes
//  has not asked Apple Health to forget their workouts, and deleting from the
//  system health database on their behalf would be the wrong reading of the
//  request.
//

import Foundation
import SwiftData

@MainActor
struct RetentionService {

    let context: ModelContext

    struct Preview: Equatable {
        var activityCount: Int
        var byteCount: Int
        var oldestDate: Date?

        var isEmpty: Bool { activityCount == 0 }

        var formattedSize: String {
            ByteCountFormatStyle(style: .file).format(Int64(byteCount))
        }
    }

    // MARK: Inspection

    /// What a purge would remove, for the confirmation sheet. Showing a real
    /// number here is the difference between an informed confirmation and a
    /// blind one.
    func preview(olderThan days: Int, now: Date = .now) -> Preview {
        let cutoff = Self.cutoff(days: days, from: now)
        let candidates = purgeCandidates(before: cutoff)

        return Preview(
            activityCount: candidates.count,
            byteCount: candidates.reduce(0) { $0 + ($1.detail?.byteCount ?? 0) },
            oldestDate: candidates.map(\.startDate).min()
        )
    }

    func previewFullDeletion(olderThan days: Int, now: Date = .now) -> Preview {
        let cutoff = Self.cutoff(days: days, from: now)
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.startDate < cutoff }
        )
        let activities = (try? context.fetch(descriptor)) ?? []
        return Preview(
            activityCount: activities.count,
            byteCount: activities.reduce(0) { $0 + ($1.detail?.byteCount ?? 0) },
            oldestDate: activities.map(\.startDate).min()
        )
    }

    // MARK: Purging

    /// Removes routes and detailed samples older than `days`, keeping summaries.
    @discardableResult
    func purgeDetail(olderThan days: Int, now: Date = .now) -> Int {
        let cutoff = Self.cutoff(days: days, from: now)
        let candidates = purgeCandidates(before: cutoff)
        guard !candidates.isEmpty else {
            AppSettings.shared.lastPurgeDate = now
            return 0
        }

        for activity in candidates {
            // Nulling a to-one relationship does not delete the destination
            // object — the cascade rule only fires when the *Activity* is
            // deleted. Without this explicit delete the ActivityDetail rows are
            // orphaned, keep their GPS blobs forever, and the cleanup frees
            // exactly zero bytes while reporting success.
            if let detail = activity.detail {
                context.delete(detail)
            }
            activity.purgeDetail(on: now)
        }
        try? context.save()
        AppSettings.shared.lastPurgeDate = now
        return candidates.count
    }

    /// Removes whole activities older than `days`. Destroys lifetime totals and
    /// records for that period — only ever call this from an explicitly labelled
    /// user action.
    @discardableResult
    func deleteEntireActivities(olderThan days: Int, now: Date = .now) -> Int {
        let cutoff = Self.cutoff(days: days, from: now)
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.startDate < cutoff }
        )
        let activities = (try? context.fetch(descriptor)) ?? []
        guard !activities.isEmpty else { return 0 }

        for activity in activities {
            context.delete(activity)
        }
        try? context.save()
        return activities.count
    }

    // MARK: Automatic cleanup

    /// Runs at most once a day when the user has enabled automatic cleanup.
    ///
    /// Called on foreground rather than from a background task: the work is a
    /// handful of nulled-out blobs, and tying it to a BGProcessingTask would
    /// make the behaviour depend on the system's scheduling mood.
    func runAutomaticPurgeIfNeeded(now: Date = .now) {
        let settings = AppSettings.shared
        guard settings.autoPurgeEnabled else { return }

        if let last = settings.lastPurgeDate,
           Calendar.current.isDate(last, inSameDayAs: now) {
            return
        }
        purgeDetail(olderThan: settings.retentionDays, now: now)
    }

    // MARK: Helpers

    private func purgeCandidates(before cutoff: Date) -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { activity in
                activity.startDate < cutoff && activity.isDetailPurged == false
            }
        )
        let activities = (try? context.fetch(descriptor)) ?? []
        return activities.filter { $0.detail != nil }
    }

    private static func cutoff(days: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -max(1, days), to: now) ?? now
    }
}
