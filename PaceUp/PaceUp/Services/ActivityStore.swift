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

    /// Persists a finished recording.
    ///
    /// The HealthKit round trip matters: Pace Up's live energy figure is a
    /// MET estimate, and its step count comes from Core Motion. Both are
    /// replaced with HealthKit's own numbers once the workout has been written,
    /// so a saved activity agrees with the Health app.
    @discardableResult
    func save(_ finished: FinishedActivity,
              title: String? = nil,
              note: String? = nil,
              feeling: Int? = nil,
              units: MeasurementUnits,
              health: HealthKitManager) async -> Activity {

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
            source: finished.wasRecovered ? .paceUp : .paceUp
        )
        activity.splitsData = SampleCodec.encodeSplits(finished.splits)

        context.insert(activity)

        // Pull authoritative numbers from HealthKit where they exist.
        let healthSteps = await health.steps(from: finished.startDate, to: finished.endDate)
        if healthSteps > 0 { activity.steps = healthSteps }

        let healthEnergy = await health.activeEnergy(from: finished.startDate, to: finished.endDate)
        if healthEnergy > 0 { activity.activeEnergy = healthEnergy }

        var heartRates = finished.heartRates
        if heartRates.isEmpty {
            heartRates = await health.heartRateSamples(from: finished.startDate, to: finished.endDate)
        }
        if !heartRates.isEmpty {
            let values = heartRates.map(\.bpm)
            activity.averageHeartRate = values.reduce(0, +) / Double(values.count)
            activity.maxHeartRate = values.max()
        }

        activity.attachRoute(finished.points, heartRate: heartRates)

        // Write back to HealthKit so the workout and route survive Pace Up
        // being deleted.
        let workoutID = await health.saveWorkout(
            activity: finished.type,
            start: finished.startDate,
            end: finished.endDate,
            distance: finished.distance,
            energy: activity.activeEnergy,
            route: finished.locations
        )
        activity.healthKitWorkoutUUID = workoutID

        try? context.save()

        AchievementEngine.evaluate(context: context, triggeredBy: activity)
        await refreshWidgetSnapshot(health: health, units: units)

        return activity
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
            let distance = workout.statistics(for: PaceUpHealthTypes.walkingRunningDistance)?
                .sumQuantity()?.doubleValue(for: .meter()) ?? 0
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
