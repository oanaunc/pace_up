//
//  StatsService.swift
//  Pace Up
//
//  Everything the Progress, Records and Profile screens display is derived
//  here, from permanent activity summaries only.
//
//  Deriving rather than storing is deliberate. A stored "longest run" goes
//  stale the moment an activity is deleted, and the resulting bug — a record
//  the user cannot find the activity for — is the kind that erodes trust in
//  every other number in the app.
//

import Foundation
import SwiftData

@MainActor
struct StatsService {

    let context: ModelContext

    // MARK: Fetching

    func allActivities() -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func activities(since date: Date) -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.startDate >= date },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Lifetime totals

    struct LifetimeTotals: Equatable {
        var steps: Int
        var distance: Double
        var activityCount: Int
        var duration: TimeInterval
        var elevationGain: Double
    }

    func lifetimeTotals() -> LifetimeTotals {
        let activities = allActivities()
        return LifetimeTotals(
            steps: activities.reduce(0) { $0 + $1.steps },
            distance: activities.reduce(0) { $0 + $1.distance },
            activityCount: activities.count,
            duration: activities.reduce(0) { $0 + $1.movingDuration },
            elevationGain: activities.reduce(0) { $0 + $1.elevationGain }
        )
    }

    // MARK: Weekly comparison

    struct WeeklyComparison: Equatable {
        var thisWeek: Double
        var lastWeek: Double

        /// Percentage change, or nil when last week had no data to compare to.
        var percentChange: Double? {
            guard lastWeek > 0 else { return nil }
            return (thisWeek - lastWeek) / lastWeek * 100
        }
    }

    /// Distance covered this week versus last, from activity summaries.
    func weeklyDistanceComparison(calendar: Calendar = .current) -> WeeklyComparison {
        let now = Date.now
        guard
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
        else { return WeeklyComparison(thisWeek: 0, lastWeek: 0) }

        let activities = activities(since: lastWeekStart)
        let thisWeek = activities.filter { $0.startDate >= thisWeekStart }
            .reduce(0) { $0 + $1.distance }
        let lastWeek = activities.filter { $0.startDate < thisWeekStart }
            .reduce(0) { $0 + $1.distance }

        return WeeklyComparison(thisWeek: thisWeek, lastWeek: lastWeek)
    }

    // MARK: Streaks

    /// Consecutive days up to today on which the user either hit their step
    /// goal or recorded an activity.
    ///
    /// `stepsByDay` covers only the last seven days because that is what
    /// HealthKit is asked for on the hot path; beyond that window the streak
    /// falls back to recorded activities alone. A longer step history would
    /// mean a slow HealthKit query on every launch, which is a poor trade for a
    /// number on a card.
    func currentStreak(dailyStepGoal: Int,
                       stepsByDay: [HealthKitManager.DailyMetric],
                       calendar: Calendar = .current) -> Int {
        let activityDays = Set(allActivities().map { calendar.startOfDay(for: $0.startDate) })
        let goalDays = Set(
            stepsByDay
                .filter { Int($0.value) >= dailyStepGoal && dailyStepGoal > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let qualifying = activityDays.union(goalDays)
        guard !qualifying.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        // Today not yet qualifying should not break a streak that is otherwise
        // intact — the day is not over.
        if !qualifying.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        while qualifying.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Longest run of consecutive active days ever recorded.
    func longestStreak(calendar: Calendar = .current) -> Int {
        let days = Set(allActivities().map { calendar.startOfDay(for: $0.startDate) }).sorted()
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for index in 1..<days.count {
            let gap = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else if gap > 1 {
                current = 1
            }
        }
        return longest
    }

    // MARK: Personal records

    /// Recomputes every personal record from permanent summaries.
    ///
    /// Fastest 1K/5K/10K come from split data, which is stored on the activity
    /// itself rather than the purgeable detail — so these survive the 30-day
    /// route purge.
    func personalRecords(units: MeasurementUnits) -> [PersonalRecord] {
        let activities = allActivities()
        let runs = activities.filter { $0.type == .run }

        var records: [PersonalRecord] = []

        // Fastest 1K: best single complete split across all runs.
        if let best = runs.compactMap({ activity -> (Double, Activity)? in
            guard let pace = activity.bestSplitPaceSecondsPerKm(unitDistance: units.splitDistance) else { return nil }
            return (pace, activity)
        }).min(by: { $0.0 < $1.0 }) {
            records.append(PersonalRecord(
                kind: .fastest1K,
                formattedValue: PaceFormat.paceValue(secondsPerKm: best.0, units: units),
                achievedOn: best.1.startDate,
                activityID: best.1.id
            ))
        }

        // Fastest 5K and 10K: best rolling window across a run's splits.
        for (kind, target) in [(PersonalRecord.Kind.fastest5K, 5.0), (.fastest10K, 10.0)] {
            if let best = bestWindow(kilometres: target, in: runs, units: units) {
                records.append(PersonalRecord(
                    kind: kind,
                    formattedValue: PaceFormat.duration(best.duration),
                    achievedOn: best.activity.startDate,
                    activityID: best.activity.id
                ))
            }
        }

        if let longest = activities.max(by: { $0.distance < $1.distance }), longest.distance > 0 {
            records.append(PersonalRecord(
                kind: .longestDistance,
                formattedValue: PaceFormat.distance(longest.distance, units: units),
                achievedOn: longest.startDate,
                activityID: longest.id
            ))
        }

        if let longest = activities.max(by: { $0.movingDuration < $1.movingDuration }), longest.movingDuration > 0 {
            records.append(PersonalRecord(
                kind: .longestDuration,
                formattedValue: PaceFormat.duration(longest.movingDuration),
                achievedOn: longest.startDate,
                activityID: longest.id
            ))
        }

        // Steps per *day*, summed across every activity that day. Taking the
        // single largest activity would under-report anyone who splits their
        // walking into a morning and an evening.
        let stepsByDay = Dictionary(grouping: activities) {
            Calendar.current.startOfDay(for: $0.startDate)
        }.mapValues { $0.reduce(0) { $0 + $1.steps } }

        if let best = stepsByDay.max(by: { $0.value < $1.value }), best.value > 0 {
            records.append(PersonalRecord(
                kind: .mostStepsInADay,
                formattedValue: PaceFormat.steps(best.value),
                achievedOn: best.key,
                activityID: nil
            ))
        }

        let streak = longestStreak()
        if streak > 0 {
            records.append(PersonalRecord(
                kind: .longestStreak,
                formattedValue: String(localized: "\(streak) days"),
                achievedOn: nil,
                activityID: nil
            ))
        }

        if let climb = activities.max(by: { $0.elevationGain < $1.elevationGain }), climb.elevationGain > 5 {
            records.append(PersonalRecord(
                kind: .highestElevation,
                formattedValue: PaceFormat.elevation(climb.elevationGain, units: units),
                achievedOn: climb.startDate,
                activityID: climb.id
            ))
        }

        return records.sorted {
            (PersonalRecord.Kind.allCases.firstIndex(of: $0.kind) ?? 0)
                < (PersonalRecord.Kind.allCases.firstIndex(of: $1.kind) ?? 0)
        }
    }

    /// Fastest contiguous `kilometres` inside any single activity's splits.
    ///
    /// Two things this must not get wrong. First, the trailing partial split is
    /// excluded: counting a 950 m final split as a kilometre yields a "fastest
    /// 5K" the user never ran. Second, a split is one *unit*, not one
    /// kilometre — five splits for an imperial user is 8.05 km, so the window
    /// length is derived from the current unit and the record is skipped when
    /// the target does not land on a whole number of splits.
    private func bestWindow(kilometres: Double,
                            in activities: [Activity],
                            units: MeasurementUnits) -> (duration: TimeInterval, activity: Activity)? {
        var best: (TimeInterval, Activity)?

        let unitDistance = units.splitDistance
        let exactWindow = kilometres * 1000 / unitDistance
        let window = Int(exactWindow.rounded())
        guard window > 0, abs(exactWindow - Double(window)) < 0.02 else { return nil }

        for activity in activities {
            let splits = activity.splits.filter { !$0.isPartial(unitDistance: unitDistance) }
            guard splits.count >= window else { continue }

            for start in 0...(splits.count - window) {
                let slice = splits[start..<(start + window)]
                let duration = slice.reduce(0) { $0 + $1.duration }
                if duration > 0, best == nil || duration < best!.0 {
                    best = (duration, activity)
                }
            }
        }
        return best.map { (duration: $0.0, activity: $0.1) }
    }

    // MARK: Storage accounting

    /// Bytes used by purgeable detail, for the Data & Privacy screen.
    func purgeableByteCount() -> Int {
        let descriptor = FetchDescriptor<ActivityDetail>()
        let details = (try? context.fetch(descriptor)) ?? []
        return details.reduce(0) { $0 + $1.byteCount }
    }
}
