//
//  HealthKitManager.swift
//  Pace Up
//
//  ── Why this file is more complicated than "sum the step samples" ───────────
//
//  HealthKit does not deduplicate across sources. If a user has an Apple Watch,
//  a naive `HKStatisticsQuery(.cumulativeSum)` over step count returns iPhone
//  steps *plus* Watch steps, and Pace Up would show roughly double what the
//  Health app shows. This is the single most common defect in step trackers.
//
//  Apple's Health app resolves the overlap with a time-sliced source priority.
//  We approximate it: statistics are collected in short buckets with
//  `.separateBySource`, and within each bucket exactly one source is counted —
//  the highest-priority source that has data for that bucket. Bucketing matters
//  because a user might wear the Watch only in the morning; a whole-day priority
//  choice would silently discard the afternoon's iPhone steps.
//
//  Priority order: Apple Watch, then this iPhone, then any other source.
//
//  Second source of double counting: Pace Up writes its own workouts back to
//  HealthKit. Any read that is scoped to an activity therefore excludes samples
//  whose source is Pace Up itself.
//

import Foundation
import HealthKit
import CoreLocation
import Observation

@MainActor
@Observable
final class HealthKitManager {

    enum AuthorizationState: Equatable {
        case unknown
        case unavailable
        case notDetermined
        case authorized
        case denied
    }

    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    // MARK: Observable state

    private(set) var authorizationState: AuthorizationState = .unknown
    private(set) var todaySteps: Int = 0
    private(set) var todayDistance: Double = 0        // metres
    private(set) var todayActiveEnergy: Double = 0    // kcal
    private(set) var todayActiveMinutes: Int = 0
    private(set) var weeklySteps: [DailyMetric] = []
    private(set) var lastRefresh: Date?
    private(set) var lastError: String?

    private var observerQueries: [HKObserverQuery] = []

    struct DailyMetric: Identifiable, Equatable, Sendable {
        var date: Date
        var value: Double
        var id: Date { date }
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    /// Refreshes `authorizationState` without prompting.
    ///
    /// Note the asymmetry in HealthKit's privacy model: an app can always learn
    /// whether it may *write* a type, but never whether it may *read* one.
    /// `authorizationStatus(for:)` on a read type returns `.sharingDenied` in
    /// cases that are indistinguishable from "granted", so read permission is
    /// inferred from whether a probe query returns data.
    func refreshAuthorizationState() async {
        guard isAvailable else {
            authorizationState = .unavailable
            return
        }
        do {
            let status = try await store.statusForAuthorizationRequest(
                toShare: PaceUpHealthTypes.shareTypes,
                read: PaceUpHealthTypes.readTypes
            )
            switch status {
            case .shouldRequest:
                authorizationState = .notDetermined
            case .unnecessary:
                authorizationState = .authorized
            @unknown default:
                authorizationState = .unknown
            }
        } catch {
            lastError = error.localizedDescription
            authorizationState = .unknown
        }
    }

    /// Presents the HealthKit permission sheet.
    ///
    /// The completion state is deliberately optimistic: iOS never tells an app
    /// which read permissions the user granted, so "the sheet was dismissed
    /// without error" is the strongest signal available. Screens should degrade
    /// to a zero state rather than showing an error when data does not arrive.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            authorizationState = .unavailable
            return false
        }
        do {
            try await store.requestAuthorization(
                toShare: PaceUpHealthTypes.shareTypes,
                read: PaceUpHealthTypes.readTypes
            )
            authorizationState = .authorized
            await refreshToday()
            return true
        } catch {
            lastError = error.localizedDescription
            authorizationState = .denied
            return false
        }
    }

    // MARK: - Today

    func refreshToday() async {
        guard isAvailable else { return }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let now = Date.now

        async let steps = deduplicatedSum(
            type: PaceUpHealthTypes.stepCount,
            unit: .count(),
            from: startOfToday,
            to: now
        )
        async let distance = deduplicatedSum(
            type: PaceUpHealthTypes.walkingRunningDistance,
            unit: .meter(),
            from: startOfToday,
            to: now
        )
        async let energy = deduplicatedSum(
            type: PaceUpHealthTypes.activeEnergy,
            unit: .kilocalorie(),
            from: startOfToday,
            to: now
        )
        async let exercise = deduplicatedSum(
            type: PaceUpHealthTypes.exerciseTime,
            unit: .minute(),
            from: startOfToday,
            to: now
        )

        let (s, d, e, x) = await (steps, distance, energy, exercise)

        todaySteps = Int(s.rounded())
        todayDistance = d
        todayActiveEnergy = e
        todayActiveMinutes = Int(x.rounded())
        lastRefresh = .now

        await refreshWeeklySteps()
    }

    func refreshWeeklySteps() async {
        guard isAvailable else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Not `+86_400`: a DST transition makes a 23- or 25-hour day, which
        // would truncate or overlap the final bucket.
        guard
            let end = calendar.date(byAdding: .day, value: 1, to: today),
            let start = calendar.date(byAdding: .day, value: -6, to: today)
        else { return }

        // Build the seven day windows first, then query them concurrently.
        //
        // This loop used to `await` inside itself, which made seven full-day
        // statistics queries strictly sequential. Each one is an XPC round trip
        // into healthd that computes per-source sums for every bucket in the
        // day, so the total was frequently multiple seconds — and it sat on the
        // critical path of saving an activity.
        var windows: [(start: Date, end: Date)] = []
        var cursor = start
        while cursor < end {
            let dayEnd = min(calendar.date(byAdding: .day, value: 1, to: cursor) ?? end, end)
            windows.append((cursor, dayEnd))
            cursor = dayEnd
        }

        let results = await withTaskGroup(of: (Int, Double).self) { group -> [DailyMetric] in
            for (index, window) in windows.enumerated() {
                group.addTask { [weak self] in
                    guard let self else { return (index, 0) }
                    let value = await self.deduplicatedSum(
                        type: PaceUpHealthTypes.stepCount,
                        unit: .count(),
                        from: window.start,
                        to: window.end,
                        // Coarser buckets for historical days. Ten-minute
                        // resolution matters for today, where the user can
                        // watch the number move; for a bar in a weekly chart a
                        // half-hour resolution is invisible and costs a sixth
                        // as much to compute.
                        bucket: Self.historicalBucketInterval
                    )
                    return (index, value)
                }
            }

            var byIndex = [Int: Double]()
            for await (index, value) in group { byIndex[index] = value }
            return windows.enumerated().map { index, window in
                DailyMetric(date: window.start, value: byIndex[index] ?? 0)
            }
        }

        weeklySteps = results
    }

    /// Steps for an arbitrary day. Used by the Progress screen when the user
    /// scrubs back through history.
    func steps(on day: Date) async -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let value = await deduplicatedSum(
            type: PaceUpHealthTypes.stepCount,
            unit: .count(),
            from: start,
            to: min(end, .now)
        )
        return Int(value.rounded())
    }

    // MARK: - Activity-scoped reads

    /// Steps recorded during a Pace Up activity, excluding anything Pace Up
    /// itself wrote for that activity.
    func steps(from start: Date, to end: Date) async -> Int {
        let value = await deduplicatedSum(
            type: PaceUpHealthTypes.stepCount,
            unit: .count(),
            from: start,
            to: end,
            excludingPaceUp: true
        )
        return Int(value.rounded())
    }

    func activeEnergy(from start: Date, to end: Date) async -> Double {
        await deduplicatedSum(
            type: PaceUpHealthTypes.activeEnergy,
            unit: .kilocalorie(),
            from: start,
            to: end,
            excludingPaceUp: true
        )
    }

    /// Heart-rate samples during an activity, oldest first.
    func heartRateSamples(from start: Date, to end: Date) async -> [HeartRateSample] {
        guard isAvailable, end > start else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: PaceUpHealthTypes.heartRate, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            let samples = try await descriptor.result(for: store)
            let unit = HKUnit.count().unitDivided(by: .minute())
            return samples.map {
                HeartRateSample(
                    elapsed: $0.startDate.timeIntervalSince(start),
                    bpm: $0.quantity.doubleValue(for: unit)
                )
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    // MARK: - Deduplicated statistics

    /// Bucket width used when resolving overlapping sources. Ten minutes keeps
    /// a week's worth of buckets to around a thousand — cheap to compute — while
    /// still being fine-grained enough to follow a user switching between
    /// carrying their phone and wearing their watch.
    private static let bucketInterval = DateComponents(minute: 10)

    /// Used for whole past days, where a half-hour resolution is indistinguishable
    /// in a bar chart but costs a sixth as much to compute.
    private static let historicalBucketInterval = DateComponents(minute: 30)

    private func deduplicatedSum(type: HKQuantityType,
                                 unit: HKUnit,
                                 from start: Date,
                                 to end: Date,
                                 excludingPaceUp: Bool = false,
                                 bucket: DateComponents? = nil) async -> Double {
        guard isAvailable, end > start else { return 0 }

        var predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        if excludingPaceUp {
            let notPaceUp = NSCompoundPredicate(
                notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default())
            )
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, notPaceUp])
        }

        // Anchor buckets to a clean boundary so repeated calls agree.
        let anchor = Calendar.current.startOfDay(for: start)

        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: [.cumulativeSum, .separateBySource],
            anchorDate: anchor,
            intervalComponents: bucket ?? Self.bucketInterval
        )

        do {
            let collection = try await query.result(for: store)
            var total = 0.0
            collection.enumerateStatistics(from: start, to: end) { statistics, _ in
                total += Self.resolveBucket(statistics, unit: unit)
            }
            return total
        } catch {
            lastError = error.localizedDescription
            return 0
        }
    }

    /// Picks one source's value out of a bucket that may contain several.
    private static func resolveBucket(_ statistics: HKStatistics, unit: HKUnit) -> Double {
        guard let sources = statistics.sources, !sources.isEmpty else {
            return statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        if sources.count == 1 {
            return statistics.sumQuantity(for: sources[0])?.doubleValue(for: unit) ?? 0
        }

        let ranked = sources.sorted { priority(of: $0) < priority(of: $1) }
        for source in ranked {
            if let quantity = statistics.sumQuantity(for: source) {
                let value = quantity.doubleValue(for: unit)
                if value > 0 { return value }
            }
        }
        // Every candidate was zero or missing; fall back to the largest reading
        // rather than the sum, which would double count.
        return sources
            .compactMap { statistics.sumQuantity(for: $0)?.doubleValue(for: unit) }
            .max() ?? 0
    }

    /// Lower is higher priority.
    private static func priority(of source: HKSource) -> Int {
        let bundle = source.bundleIdentifier.lowercased()
        let name = source.name.lowercased()

        // Apple's own health daemon on watchOS.
        if bundle.hasPrefix("com.apple.health") && name.contains("watch") { return 0 }
        if name.contains("watch") { return 0 }
        // Apple's own health daemon on iOS — the motion coprocessor.
        if bundle.hasPrefix("com.apple.health") { return 1 }
        if name.contains("iphone") { return 1 }
        // Pace Up's own writes rank below the system sensors so that a run we
        // recorded never displaces the phone's pedometer count for the same
        // window.
        if bundle == Bundle.main.bundleIdentifier?.lowercased() { return 3 }
        return 2
    }

    // MARK: - Background delivery

    /// Asks HealthKit to wake the app when step data changes so the widget
    /// snapshot stays fresh. Failures here are non-fatal.
    func startObservingSteps(onChange: @escaping @Sendable () -> Void) {
        guard isAvailable, observerQueries.isEmpty else { return }

        let type = PaceUpHealthTypes.stepCount
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
            onChange()
            completion()
        }
        store.execute(query)
        observerQueries.append(query)

        store.enableBackgroundDelivery(for: type, frequency: .hourly) { [weak self] _, error in
            if let error {
                Task { @MainActor in self?.lastError = error.localizedDescription }
            }
        }
    }

    func stopObserving() {
        observerQueries.forEach { store.stop($0) }
        observerQueries.removeAll()
    }

    // MARK: - Writing workouts

    /// Writes a finished Pace Up activity to HealthKit, including its GPS route.
    ///
    /// This is what makes the local-only design defensible: if the user deletes
    /// Pace Up, the workouts and routes remain in the Health database even
    /// though Pace Up's own notes, achievements and settings do not.
    @discardableResult
    func saveWorkout(activity: ActivityType,
                     start: Date,
                     end: Date,
                     distance: Double,
                     energy: Double,
                     route: [CLLocation]) async -> UUID? {
        guard isAvailable else { return nil }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity.hkWorkoutActivityType
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)

            var samples: [HKSample] = []
            if energy > 0 {
                samples.append(HKQuantitySample(
                    type: PaceUpHealthTypes.activeEnergy,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy),
                    start: start,
                    end: end
                ))
            }
            if distance > 0 {
                let distanceType = activity == .cycle
                    ? PaceUpHealthTypes.cyclingDistance
                    : PaceUpHealthTypes.walkingRunningDistance
                samples.append(HKQuantitySample(
                    type: distanceType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                    start: start,
                    end: end
                ))
            }
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }

            try await builder.endCollection(at: end)
            guard let workout = try await builder.finishWorkout() else { return nil }

            if route.count > 1 {
                let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
                try await routeBuilder.insertRouteData(route)
                _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
            }

            return workout.uuid
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Importing workouts recorded elsewhere

    /// Workouts in the Health database that Pace Up did not write, so a user
    /// arriving with existing history is not staring at an empty app.
    func importableWorkouts(since date: Date) async -> [HKWorkout] {
        guard isAvailable else { return [] }
        let timePredicate = HKQuery.predicateForSamples(withStart: date, end: .now, options: .strictStartDate)
        let notOurs = NSCompoundPredicate(
            notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default())
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, notOurs])

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 200
        )
        do {
            return try await descriptor.result(for: store)
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
}
