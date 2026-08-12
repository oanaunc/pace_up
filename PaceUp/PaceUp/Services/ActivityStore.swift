//
//  ActivityStore.swift
//  Pace Up
//
//  Write path for activities. Views read through @Query; anything that mutates
//  goes through here so the side effects — HealthKit write-back, achievement
//  evaluation, widget refresh — happen in exactly one place.
//

import Foundation
import SwiftData
import CoreLocation
import HealthKit

@MainActor
struct ActivityStore {

    let context: ModelContext

    // MARK: Create

    /// Commits a finished recording to the local database. Phase one of two.
    ///
    /// ── Why saving is split ────────────────────────────────────────────────
    ///
    /// This used to be one `async` method that awaited three HealthKit reads,
    /// a workout write, a route write, and then a widget refresh that fired
    /// eleven more HealthKit queries — all before the summary sheet dismissed.
    /// On a device with an Apple Watch and a few years of history that is
    /// several seconds of staring at a "Saving…" button, and it reads as a
    /// hang rather than as work.
    ///
    /// None of that work is needed to make the run safe. Writing to SwiftData
    /// is local and takes milliseconds. So phase one commits and returns, the
    /// UI moves on immediately, and `syncWithHealth` reconciles afterwards.
    ///
    /// The consequence to be aware of: for a second or two the saved activity
    /// carries Pace Up's own step count (Core Motion) and its MET-estimated
    /// energy rather than HealthKit's figures. Phase two overwrites both. The
    /// numbers are the same ones the summary screen was already showing, so
    /// nothing visibly jumps.
    @discardableResult
    func saveLocally(_ finished: FinishedActivity,
                     title: String? = nil,
                     note: String? = nil,
                     feeling: Int? = nil) -> Activity {

        let activity = Activity(
            id: finished.sessionID,
            startDate: finished.startDate,
            endDate: finished.endDate,
            type: finished.type,
            title: title,
            note: note,
            feeling: feeling,
            elapsedDuration: finished.elapsedDuration,
            movingDuration: finished.movingDuration,
            distance: finished.distance,
            steps: finished.steps,
            activeEnergy: finished.activeEnergy,
            elevationGain: finished.elevationGain,
            elevationLoss: finished.elevationLoss,
            source: .paceUp
        )
        activity.splitsData = SampleCodec.encodeSplits(finished.splits)

        if !finished.heartRates.isEmpty {
            let values = finished.heartRates.map(\.bpm)
            activity.averageHeartRate = values.reduce(0, +) / Double(values.count)
            activity.maxHeartRate = values.max()
        }

        activity.attachRoute(finished.points, heartRate: finished.heartRates)

        context.insert(activity)
        try? context.save()

        return activity
    }

    /// Reconciles a saved activity with HealthKit and refreshes the widget.
    /// Phase two — safe to run after the UI has moved on.
    ///
    /// Deliberately started as an unstructured `Task` from the summary screen's
    /// Save action rather than with `.task`, so dismissing the sheet does not
    /// cancel it. If the app is killed mid-way, the activity is already in the
    /// database; only the HealthKit workout would be missing, and the numbers
    /// stay at Pace Up's own estimates.
    func syncWithHealth(_ activity: Activity,
                        finished: FinishedActivity,
                        units: MeasurementUnits,
                        health: HealthKitManager) async {

        // The three activity-window reads are independent — run them together
        // rather than one after another.
        async let stepsTask = health.steps(from: finished.startDate, to: finished.endDate)
        async let energyTask = health.activeEnergy(from: finished.startDate, to: finished.endDate)
        async let heartTask = health.heartRateSamples(from: finished.startDate, to: finished.endDate)

        let (healthSteps, healthEnergy, healthHeartRates) = await (stepsTask, energyTask, heartTask)

        if healthSteps > 0 { activity.steps = healthSteps }
        if healthEnergy > 0 { activity.activeEnergy = healthEnergy }

        // Only replace the heart-rate series if the recorder captured none.
        if finished.heartRates.isEmpty, !healthHeartRates.isEmpty {
            let values = healthHeartRates.map(\.bpm)
            activity.averageHeartRate = values.reduce(0, +) / Double(values.count)
            activity.maxHeartRate = values.max()
            activity.attachRoute(finished.points, heartRate: healthHeartRates)
        }

        try? context.save()

        // Write back to HealthKit so the workout and route survive Pace Up
        // being deleted. This is the slowest single step — inserting a few
        // thousand CLLocations into an HKWorkoutRouteBuilder is not fast — and
        // it is precisely the sort of thing the user should not be made to
        // watch.
        let workoutID = await health.saveWorkout(
            activity: finished.type,
            start: finished.startDate,
            end: finished.endDate,
            distance: finished.distance,
            energy: activity.activeEnergy,
            route: finished.locations
        )
        if let workoutID {
            activity.healthKitWorkoutUUID = workoutID
            try? context.save()
        }

        await refreshWidgetSnapshot(health: health, units: units)
    }

    // MARK: Update

    func update(_ activity: Activity, title: String? = nil, note: String? = nil, feeling: Int? = nil) {
        if let title, !title.isEmpty { activity.title = title }
        if let note { activity.note = note.isEmpty ? nil : note }
        if let feeling { activity.feeling = feeling }
        try? context.save()
    }

    // MARK: Delete

    func delete(_ activity: Activity) {
        context.delete(activity)
        try? context.save()
    }

    /// Removes every Pace Up activity. Does not touch HealthKit — a user who
    /// clears Pace Up is clearing this app's records, not their Health history,
    /// and silently deleting Health data would be indefensible.
    func deleteAll() {
        try? context.delete(model: ActivityDetail.self)
        try? context.delete(model: Activity.self)
        try? context.delete(model: AchievementUnlock.self)
        try? context.save()
    }

    // MARK: Widget

    func refreshWidgetSnapshot(health: HealthKitManager, units: MeasurementUnits) async {
        await health.refreshToday()

        let stats = StatsService(context: context)
        let snapshot = WidgetSnapshot(
            steps: health.todaySteps,
            goal: AppSettings.shared.dailyStepGoal,
            distanceMeters: health.todayDistance,
            activeEnergy: health.todayActiveEnergy,
            activeMinutes: health.todayActiveMinutes,
            weeklySteps: health.weeklySteps.map { Int($0.value.rounded()) },
            weekdayInitials: health.weeklySteps.map { weekdayInitial(for: $0.date) },
            currentStreak: stats.currentStreak(dailyStepGoal: AppSettings.shared.dailyStepGoal,
                                               stepsByDay: health.weeklySteps),
            updatedAt: .now,
            usesMetric: units == .metric
        )
        WidgetBridge.write(snapshot)
    }

    private func weekdayInitial(for date: Date) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let index = Calendar.current.component(.weekday, from: date) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    // MARK: Import from HealthKit

    /// Brings in workouts recorded by other apps so a new user is not looking
    /// at an empty history. Routes are not imported: reading another app's
    /// `HKWorkoutRoute` is possible but slow, and Pace Up would be presenting
    /// data it did not record as if it had.
    func importHealthKitWorkouts(since date: Date, health: HealthKitManager) async -> Int {
        let workouts = await health.importableWorkouts(since: date)
        guard !workouts.isEmpty else { return 0 }

        let existing = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let existingIDs = Set(existing.compactMap(\.healthKitWorkoutUUID))

        var inserted = 0
        for workout in workouts where !existingIDs.contains(workout.uuid) {
            let type = ActivityType(hkWorkoutActivityType: workout.workoutActivityType)
            // Cycling distance lives under a different quantity type; reading
            // only walking/running would import every ride as zero kilometres.
            let distanceType = type == .cycle
                ? PaceUpHealthTypes.cyclingDistance
                : PaceUpHealthTypes.walkingRunningDistance
            let distance = workout.statistics(for: distanceType)?
                .sumQuantity()?.doubleValue(for: .meter())
                ?? workout.statistics(for: PaceUpHealthTypes.walkingRunningDistance)?
                    .sumQuantity()?.doubleValue(for: .meter())
                ?? 0
            let energy = workout.statistics(for: PaceUpHealthTypes.activeEnergy)?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

            let activity = Activity(
                startDate: workout.startDate,
                endDate: workout.endDate,
                type: type,
                elapsedDuration: workout.duration,
                movingDuration: workout.duration,
                distance: distance,
                activeEnergy: energy,
                source: .healthKit
            )
            activity.healthKitWorkoutUUID = workout.uuid
            context.insert(activity)
            inserted += 1
        }

        if inserted > 0 { try? context.save() }
        return inserted
    }
}
