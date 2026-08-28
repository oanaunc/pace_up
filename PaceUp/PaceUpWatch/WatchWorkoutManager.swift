import Foundation
import HealthKit

enum WatchActivity: String, CaseIterable, Identifiable {
    case walk, run, hike, cycle
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { switch self { case .walk: "figure.walk"; case .run: "figure.run"; case .hike: "figure.hiking"; case .cycle: "figure.outdoor.cycle" } }
    var healthType: HKWorkoutActivityType { switch self { case .walk: .walking; case .run: .running; case .hike: .hiking; case .cycle: .cycling } }
}

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var activity: WatchActivity?
    @Published var startedAt: Date?
    @Published var elapsed: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var energy: Double = 0
    @Published var heartRate: Double = 0
    @Published var isPaused = false
    @Published var errorMessage: String?

    func requestAccess() async {
        let types: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling)]
        do { try await healthStore.requestAuthorization(toShare: types, read: types) }
        catch { errorMessage = "Health access is needed to record workouts." }
    }

    func start(_ activity: WatchActivity) async {
        await requestAccess()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity.healthType
        configuration.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self; builder.delegate = self
            self.session = session; self.builder = builder; self.activity = activity
            let start = Date(); startedAt = start
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
        } catch { errorMessage = "The workout could not start. Please try again." }
    }

    func togglePause() {
        if isPaused { session?.resume() } else { session?.pause() }
        isPaused.toggle()
    }

    func finish() { session?.end() }

    func reset() {
        activity = nil; startedAt = nil; elapsed = 0; distance = 0; energy = 0; heartRate = 0; isPaused = false
        session = nil; builder = nil
    }

    private func update(_ statistics: HKStatistics) {
        let type = statistics.quantityType
        switch type {
        case HKQuantityType(.heartRate): heartRate = statistics.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
        case HKQuantityType(.activeEnergyBurned): energy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        case HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling): distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? distance
        default: break
        }
        if let startedAt { elapsed = Date().timeIntervalSince(startedAt) }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        Task { @MainActor in
            guard let builder else { return }
            do { try await builder.endCollection(at: date); _ = try await builder.finishWorkout() }
            catch { errorMessage = "Your workout ended but could not be saved." }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) { Task { @MainActor in errorMessage = error.localizedDescription } }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in collectedTypes.compactMap { $0 as? HKQuantityType }.forEach { if let stats = workoutBuilder.statistics(for: $0) { update(stats) } } }
    }
}
