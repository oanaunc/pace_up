//
//  AchievementEngine.swift
//  Pace Up
//

import Foundation
import SwiftData

@MainActor
enum AchievementEngine {

    /// Awards any newly qualifying badges.
    ///
    /// Runs over the whole history rather than just the triggering activity, so
    /// a badge added in a later app release is granted retroactively to users
    /// who already earned it.
    @discardableResult
    static func evaluate(context: ModelContext,
                         triggeredBy activity: Activity? = nil,
                         calendar: Calendar = .current) -> [AchievementKind] {

        let unlocked = Set(
            ((try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? [])
                .compactMap(\.kind)
        )
        let stats = StatsService(context: context)
        let activities = stats.allActivities()
        guard !activities.isEmpty else { return [] }

        let totals = stats.lifetimeTotals()
        let runs = activities.filter { $0.type == .run }
        var newlyUnlocked: [AchievementKind] = []

        func award(_ kind: AchievementKind, on date: Date?, activityID: UUID? = nil) {
            guard !unlocked.contains(kind) else { return }
            context.insert(AchievementUnlock(
                kind: kind,
                unlockedAt: date ?? .now,
                activityID: activityID
            ))
            newlyUnlocked.append(kind)
        }

        // Distance milestones, single run.
        for (kind, metres) in [
            (AchievementKind.first5K, 5_000.0),
            (.first10K, 10_000.0),
            (.firstHalfMarathon, 21_097.0),
            (.firstMarathon, 42_195.0)
        ] {
            if let match = runs.filter({ $0.distance >= metres }).min(by: { $0.startDate < $1.startDate }) {
                award(kind, on: match.startDate, activityID: match.id)
            }
        }

        // Single-activity step milestones.
        if let match = activities.filter({ $0.steps >= 10_000 }).min(by: { $0.startDate < $1.startDate }) {
            award(.steps10KDay, on: match.startDate, activityID: match.id)
        }
        if let match = activities.filter({ $0.steps >= 20_000 }).min(by: { $0.startDate < $1.startDate }) {
            award(.steps20KDay, on: match.startDate, activityID: match.id)
        }

        // Lifetime milestones.
        if totals.steps >= 100_000 { award(.steps100KTotal, on: .now) }
        if totals.steps >= 1_000_000 { award(.steps1MTotal, on: .now) }
        if totals.distance >= 100_000 { award(.distance100KTotal, on: .now) }
        if totals.activityCount >= 10 { award(.tenActivities, on: .now) }
        if totals.activityCount >= 50 { award(.fiftyActivities, on: .now) }

        // Streaks.
        let longest = stats.longestStreak(calendar: calendar)
        if longest >= 7 { award(.streak7, on: .now) }
        if longest >= 30 { award(.streak30, on: .now) }

        // Time of day.
        if let early = activities.first(where: { calendar.component(.hour, from: $0.endDate) < 7 }) {
            award(.earlyBird, on: early.endDate, activityID: early.id)
        }
        if let late = activities.first(where: { calendar.component(.hour, from: $0.endDate) >= 22 }) {
            award(.nightOwl, on: late.endDate, activityID: late.id)
        }

        // Elevation.
        if let climb = activities.first(where: { $0.elevationGain >= 500 }) {
            award(.elevation500, on: climb.startDate, activityID: climb.id)
        }

        if !newlyUnlocked.isEmpty {
            try? context.save()
        }
        return newlyUnlocked
    }

    static func unlocks(context: ModelContext) -> [AchievementKind: Date] {
        let rows = (try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? []
        return rows.reduce(into: [:]) { result, row in
            if let kind = row.kind { result[kind] = row.unlockedAt }
        }
    }
}
