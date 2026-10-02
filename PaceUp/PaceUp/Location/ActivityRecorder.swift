//
//  ActivityRecorder.swift
//  Pace Up
//
//  The live recording engine: Core Location for the route, Core Motion for
//  steps, and a write-ahead journal so a termination mid-run is recoverable.
//

import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import UIKit
import Observation

@MainActor
@Observable
final class ActivityRecorder {

    // MARK: Types

    enum State: Equatable {
        case idle
        /// Location permission granted, waiting for a usable fix.
        case acquiring
        case ready
        case recording
        case paused
        case saving
    }

    enum SignalQuality: Int, Comparable {
        case none = 0
        case poor = 1
        case fair = 2
        case good = 3

        static func < (lhs: SignalQuality, rhs: SignalQuality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var label: String {
            switch self {
            case .none: return String(localized: "SEARCHING")
            case .poor: return String(localized: "WEAK")
            case .fair: return String(localized: "OK")
            case .good: return String(localized: "READY")
            }
        }

        var bars: Int { rawValue }
    }

    /// Optional target the user picked on the setup screen.
    enum Goal: Equatable {
        case none
        /// Metres.
        case distance(Double)
        /// Seconds.
        case time(TimeInterval)
        /// Kilocalories.
        case calories(Double)

        var isSet: Bool { self != .none }
    }

    // MARK: Observable state

    private(set) var state: State = .idle
    private(set) var activityType: ActivityType = .run
    var goal: Goal = .none

    private(set) var signalQuality: SignalQuality = .none
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var hasFullAccuracy = true

    /// Metres covered so far.
    private(set) var distance: Double = 0
    /// Wall-clock seconds since start, including pauses.
    private(set) var elapsed: TimeInterval = 0
    /// Seconds excluding pauses. Pace is derived from this.
    private(set) var movingDuration: TimeInterval = 0
    private(set) var steps: Int = 0
    private(set) var activeEnergy: Double = 0
    private(set) var elevationGain: Double = 0
    private(set) var elevationLoss: Double = 0
    private(set) var currentHeartRate: Double?

    /// Coordinates accumulated so far, for the live polyline.
    private(set) var coordinates: [CLLocationCoordinate2D] = []
    private(set) var lastLocation: CLLocation?
    private(set) var completedSplits: [Split] = []

    /// True while auto-pause is holding the recording, as opposed to the user
    /// having tapped pause. Shown differently in the UI.
    private(set) var isAutoPaused = false

    /// Set when a previous run was found on disk at launch.
    var recoverableSession: RecoverableSession?

    /// A run that has stopped recording and is waiting for the user to save or
    /// discard it.
    ///
    /// This lives on the recorder rather than in the live screen's `@State` so
    /// that a single presentation can swap between the live UI and the summary.
    /// Presenting the summary as a `fullScreenCover` *from inside* the live
    /// cover meant two nested presentations being updated in the same
    /// transaction, and SwiftUI drops the inner one often enough that Finish
    /// looked like it did nothing at all.
    private(set) var pendingSummary: FinishedActivity?

    // MARK: Hooks

    /// Called when a new recording starts. Waymarks use it to reset their
    /// per-session state.
    @ObservationIgnored var onSessionStart: ((UUID) -> Void)?
    /// Called with every accepted fix, foreground or background. Waymarks use
    /// it to notice when the user walks back past one.
    @ObservationIgnored var onAcceptedLocation: ((CLLocation) -> Void)?

    /// The ID the activity will be saved under. Waymarks dropped mid-run are
    /// linked to it.
    var currentSessionID: UUID { sessionID }

    // MARK: Private

    private let provider = LocationProvider()
    private let pedometer = CMPedometer()
    private var altimeter: CMAltimeter?

    private var sessionID = UUID()
    private var startDate: Date?
    private var pauseStartedAt: Date?
    private var accumulatedPause: TimeInterval = 0
    private var points: [RoutePoint] = []
    private var heartRates: [HeartRateSample] = []
    private var ticker: Timer?
    private var lastAcceptedPoint: RoutePoint?
    private var slowSince: Date?
    private var pointsSinceElevationUpdate = 0
    private var splitUnitDistance: Double = 1000
    private var distanceAtLastSplit: Double = 0
    private var elapsedAtLastSplit: TimeInterval = 0
    private var altitudeAtLastSplit: Double = 0

    // MARK: Tunables
    //
    // These thresholds are the difference between a clean 5.24 km and a run
    // that reads 5.9 km because the phone wandered while the user waited at a
    // traffic light.

    /// Fixes worse than this are dropped entirely.
    private let maximumAcceptableAccuracy: CLLocationAccuracy = 30
    /// Movement below this between two fixes is treated as GPS jitter.
    private let minimumDisplacement: Double = 2.0
    /// A fix implying a speed above this is a glitch, not an athlete.
    private var maximumPlausibleSpeed: Double { activityType == .cycle ? 25 : 12 }
    /// Auto-pause triggers after this long below `autoPauseSpeed`.
    private let autoPauseDelay: TimeInterval = 12
    private let autoPauseSpeed: Double = 0.5
    private let autoResumeSpeed: Double = 1.2

    // MARK: Init

    init() {
        provider.onLocations = { [weak self] locations in
            self?.handle(locations: locations)
        }
        provider.onAuthorizationChange = { [weak self] status, accuracy in
            self?.authorizationStatus = status
            self?.hasFullAccuracy = accuracy == .fullAccuracy
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if accuracy != .fullAccuracy { self?.provider.requestFullAccuracy() }
                self?.provider.startPreview()
            }
        }
        authorizationStatus = provider.authorizationStatus
        hasFullAccuracy = provider.accuracyAuthorization == .fullAccuracy
    }

    // MARK: - Permissions and preview

    func requestLocationPermission() {
        provider.requestWhenInUseAuthorization()
    }

    /// Called when the Start tab appears: warms up the GPS so the "READY"
    /// indicator is truthful by the time the user taps Start.
    func beginPreview(for type: ActivityType) {
        activityType = type
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        if state == .idle { state = .acquiring }
        provider.startPreview()
    }

    func endPreview() {
        guard state == .idle || state == .acquiring || state == .ready else { return }
        provider.stop()
        state = .idle
        signalQuality = .none
    }

    // MARK: - Recording lifecycle

    func start(type: ActivityType, goal: Goal = .none, units: MeasurementUnits) {
        guard state == .idle || state == .acquiring || state == .ready else { return }

        activityType = type
        self.goal = goal
        splitUnitDistance = units.splitDistance

        sessionID = UUID()
        let now = Date.now
        startDate = now
        accumulatedPause = 0
        pauseStartedAt = nil
        distance = 0
        elapsed = 0
        movingDuration = 0
        steps = 0
        activeEnergy = 0
        elevationGain = 0
        elevationLoss = 0
        points = []
        heartRates = []
        coordinates = []
        completedSplits = []
        lastAcceptedPoint = nil
        slowSince = nil
        pointsSinceElevationUpdate = 0
        distanceAtLastSplit = 0
        elapsedAtLastSplit = 0
        altitudeAtLastSplit = 0
        isAutoPaused = false

        RecordingJournal.shared.begin(sessionID: sessionID, type: type, startDate: now)

        provider.startRecording()
        startPedometer(from: now)
        startTicker()
        UIApplication.shared.isIdleTimerDisabled = AppSettings.shared.keepScreenAwake

        state = .recording
        onSessionStart?(sessionID)
    }

    func pause(automatic: Bool = false) {
        guard state == .recording else { return }
        state = .paused
        isAutoPaused = automatic
        let now = Date.now
        pauseStartedAt = now
        RecordingJournal.shared.recordPauseStarted(at: now)
    }

    func resume() {
        guard state == .paused else { return }
        if let pauseStartedAt {
            accumulatedPause += Date.now.timeIntervalSince(pauseStartedAt)
        }
        pauseStartedAt = nil
        isAutoPaused = false
        slowSince = nil
        let now = Date.now
        RecordingJournal.shared.recordPauseEnded(at: now)
        state = .recording
    }

    /// Stops recording and hands an unsaved snapshot to `pendingSummary`.
    /// Nothing is written to SwiftData until the user taps Save Activity.
    @discardableResult
    func finish() -> FinishedActivity? {
        guard let startDate, state == .recording || state == .paused else { return nil }

        if let pauseStartedAt {
            accumulatedPause += Date.now.timeIntervalSince(pauseStartedAt)
        }
        state = .saving
        stopHardware()

        let end = Date.now
        let elapsedTotal = end.timeIntervalSince(startDate)
        let moving = max(0, elapsedTotal - accumulatedPause)

        // Distance and elevation are recomputed from the full trace so a saved
        // activity always agrees with its own route.
        let finalDistance = RouteMath.distance(of: points)
        let elevation = RouteMath.elevationChange(of: points)

        // Splits, however, come from the live tally rather than from
        // `RouteMath.splits`. A RoutePoint's `elapsed` is wall-clock, so the
        // first point after a resume carries the whole pause with it, and a
        // recomputed split containing a five-minute traffic light would read
        // 10:00/km. `completedSplits` is accumulated against `movingDuration`.
        var splits = completedSplits
        let remainder = distance - distanceAtLastSplit
        if remainder > 20 {
            splits.append(Split(
                index: splits.count + 1,
                distance: remainder,
                duration: max(0, moving - elapsedAtLastSplit),
                elevationDelta: (points.last?.altitude ?? altitudeAtLastSplit) - altitudeAtLastSplit
            ))
        }

        let result = FinishedActivity(
            sessionID: sessionID,
            type: activityType,
            startDate: startDate,
            endDate: end,
            elapsedDuration: elapsedTotal,
            movingDuration: moving,
            distance: finalDistance,
            steps: steps,
            activeEnergy: activeEnergy,
            elevationGain: elevation.gain,
            elevationLoss: elevation.loss,
            points: points,
            heartRates: heartRates,
            splits: splits
        )
        pendingSummary = result
        return result
    }

    /// True while either a recording or an unsaved summary is on screen.
    var hasActiveSession: Bool {
        state == .recording || state == .paused || pendingSummary != nil
    }

    /// The user backed out of the summary without saving.
    func cancelPendingSummary() {
        let wasRecovered = pendingSummary?.wasRecovered ?? false
        pendingSummary = nil

        if wasRecovered {
            // A recovered run that was not saved stays on disk, so the next
            // launch offers it again. Only an explicit Discard removes it.
            reset()
        } else {
            discard()
        }
    }

    /// Abandons the current recording without saving.
    func discard() {
        stopHardware()
        RecordingJournal.shared.finish()
        reset()
    }

    /// Called after the summary screen has persisted the activity.
    func completeSave() {
        pendingSummary = nil
        RecordingJournal.shared.finish()
        reset()
    }

    private func reset() {
        state = .idle
        pendingSummary = nil
        startDate = nil
        pauseStartedAt = nil
        accumulatedPause = 0
        points = []
        heartRates = []
        coordinates = []
        completedSplits = []
        distance = 0
        elapsed = 0
        movingDuration = 0
        steps = 0
        activeEnergy = 0
        elevationGain = 0
        elevationLoss = 0
        isAutoPaused = false
        goal = .none
    }

    private func stopHardware() {
        provider.stop()
        pedometer.stopUpdates()
        altimeter?.stopRelativeAltitudeUpdates()
        altimeter = nil
        ticker?.invalidate()
        ticker = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Recovery

    /// Looks for an unfinished journal from a previous launch.
    func checkForRecoverableSession() {
        guard state == .idle else { return }
        recoverableSession = RecordingJournal.pendingRecovery()
    }

    /// Turns a recovered journal into a finished activity the user can save.
    ///
    /// The journal is deliberately *not* deleted here. It is discarded only
    /// once the activity has actually been written, via `completeSave()`. If
    /// the user swipes the summary away, or the app dies again while it is on
    /// screen, the run is still on disk and is re-offered on the next launch.
    /// The return value is a convenience for callers that want the activity
    /// immediately; the summary is presented via `pendingSummary` either way,
    /// so ignoring it is correct.
    @discardableResult
    func recover(_ session: RecoverableSession, units: MeasurementUnits) -> FinishedActivity {
        let elevation = RouteMath.elevationChange(of: session.points)
        let end = session.header.lastUpdate
        let elapsedTotal = end.timeIntervalSince(session.header.startDate)
        let moving = max(0, elapsedTotal - session.header.totalPausedDuration)

        // Split length comes from current preferences: after a relaunch the
        // recorder's own `splitUnitDistance` is still at its 1 km default.
        splitUnitDistance = units.splitDistance
        recoverableSession = nil

        let result = FinishedActivity(
            sessionID: session.header.sessionID,
            type: session.header.activityType,
            startDate: session.header.startDate,
            endDate: end,
            elapsedDuration: elapsedTotal,
            movingDuration: moving,
            distance: RouteMath.distance(of: session.points),
            steps: 0,
            activeEnergy: 0,
            elevationGain: elevation.gain,
            elevationLoss: elevation.loss,
            points: session.points,
            heartRates: [],
            // No live tally survives a termination, so these are recomputed
            // from wall-clock point times and will absorb any pause that
            // happened mid-split. Acceptable for a best-effort recovery.
            splits: RouteMath.splits(from: session.points, unitDistance: splitUnitDistance),
            wasRecovered: true
        )

        // Route it through the same presentation channel as a live finish, so
        // there is exactly one place that shows a summary.
        state = .saving
        pendingSummary = result
        return result
    }

    func dismissRecovery() {
        RecordingJournal.discard()
        recoverableSession = nil
    }

    // MARK: - Location handling

    private func handle(locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        lastLocation = latest
        signalQuality = Self.quality(for: latest.horizontalAccuracy)

        if state == .acquiring, signalQuality >= .fair {
            state = .ready
        }

        // Auto-pause is evaluated *before* the recording guard. Doing it inside
        // the point loop below would make it a one-way trap: once auto-pause
        // sets `state = .paused`, the guard rejects every later update and the
        // auto-resume branch becomes unreachable, silently truncating the rest
        // of the run.
        evaluateAutoPause(speed: latest.speed)

        guard state == .recording, let startDate else { return }

        for location in locations {
            guard accept(location, startDate: startDate) else { continue }
            let point = RoutePoint(location: location, startDate: startDate)

            if let previous = lastAcceptedPoint {
                distance += RouteMath.haversine(previous, point)
            }
            points.append(point)
            coordinates.append(point.coordinate)
            lastAcceptedPoint = point

            RecordingJournal.shared.append(point)
            onAcceptedLocation?(location)

            emitSplitsIfNeeded()
        }

        // Elevation is recomputed over the whole trace, which is O(n). Doing
        // that on every fix makes the cost of a run quadratic in its length and
        // leaves the live screen visibly sluggish in the last kilometres.
        // Throttling to every eighth accepted point is imperceptible — ascent
        // moves by centimetres between fixes — and `finish()` recomputes from
        // the full trace anyway.
        pointsSinceElevationUpdate += 1
        if pointsSinceElevationUpdate >= 8 {
            pointsSinceElevationUpdate = 0
            let elevation = RouteMath.elevationChange(of: points)
            elevationGain = elevation.gain
            elevationLoss = elevation.loss
        }
    }

    /// Decides whether a fix is trustworthy enough to extend the route.
    private func accept(_ location: CLLocation, startDate: Date) -> Bool {
        // Reject unusable accuracy outright.
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= maximumAcceptableAccuracy else { return false }

        // Reject cached fixes Core Location replays on start-up.
        guard location.timestamp >= startDate,
              location.timestamp.timeIntervalSinceNow > -10 else { return false }

        guard let previous = lastAcceptedPoint else { return true }

        let candidate = RoutePoint(location: location, startDate: startDate)
        let step = RouteMath.haversine(previous, candidate)

        // Standing still: GPS wander would otherwise add tens of metres a
        // minute to the total.
        guard step >= minimumDisplacement else { return false }

        // Teleports: a jump that implies an impossible speed is a bad fix.
        // Two fixes sharing a timestamp are rejected outright rather than
        // skipping the check, which would let a jump of any size through.
        let interval = candidate.elapsed - previous.elapsed
        guard interval > 0 else { return false }
        if step / interval > maximumPlausibleSpeed { return false }

        return true
    }

    private static func quality(for accuracy: CLLocationAccuracy) -> SignalQuality {
        switch accuracy {
        case ..<0:   return .none
        case 0..<10: return .good
        case 10..<25: return .fair
        case 25..<60: return .poor
        default:     return .none
        }
    }

    // MARK: - Auto-pause

    private func evaluateAutoPause(speed: CLLocationSpeed) {
        guard AppSettings.shared.autoPauseEnabled, activityType != .cycle else { return }
        guard speed >= 0 else { return }
        // Only act while recording, or while *we* are the reason it is paused.
        // A user-initiated pause must never be undone by movement.
        guard state == .recording || (state == .paused && isAutoPaused) else { return }

        if speed < autoPauseSpeed {
            if let since = slowSince {
                if Date.now.timeIntervalSince(since) >= autoPauseDelay, state == .recording {
                    pause(automatic: true)
                }
            } else {
                slowSince = .now
            }
        } else {
            slowSince = nil
            if state == .paused, isAutoPaused, speed > autoResumeSpeed {
                resume()
            }
        }
    }

    // MARK: - Splits

    private func emitSplitsIfNeeded() {
        while distance - distanceAtLastSplit >= splitUnitDistance {
            let index = completedSplits.count + 1
            let currentAltitude = lastAcceptedPoint?.altitude ?? altitudeAtLastSplit
            completedSplits.append(Split(
                index: index,
                distance: splitUnitDistance,
                duration: movingDuration - elapsedAtLastSplit,
                elevationDelta: currentAltitude - altitudeAtLastSplit
            ))
            distanceAtLastSplit += splitUnitDistance
            elapsedAtLastSplit = movingDuration
            altitudeAtLastSplit = currentAltitude
        }
    }

    // MARK: - Timers and motion

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let startDate else { return }
        elapsed = Date.now.timeIntervalSince(startDate)
        let pausedSoFar = accumulatedPause + (pauseStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0)
        movingDuration = max(0, elapsed - pausedSoFar)
        activeEnergy = estimatedEnergy()
    }

    private func startPedometer(from date: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: date) { [weak self] data, _ in
            guard let data else { return }
            let count = data.numberOfSteps.intValue
            Task { @MainActor in self?.steps = count }
        }
    }

    /// Rough MET-based estimate shown during the activity.
    ///
    /// HealthKit's own active-energy figure is authoritative and is read back
    /// when the activity is saved; this exists only so the live screen is not
    /// showing a zero for the first ten minutes.
    private func estimatedEnergy() -> Double {
        let hours = movingDuration / 3600
        guard hours > 0 else { return 0 }
        let speed = movingDuration > 0 ? distance / movingDuration : 0
        let kmh = speed * 3.6

        let met: Double
        switch activityType {
        case .run, .trailRun: met = max(6, min(16, 1.0 + kmh * 1.0))
        case .walk, .nordicWalk, .wheelchair: met = max(2.5, min(7, 1.5 + kmh * 0.6))
        case .hike:  met = 6.0
        case .cycle: met = max(4, min(14, kmh * 0.5))
        case .other: met = 4.0
        }

        // 70 kg reference. Reading body mass from HealthKit would need another
        // permission for a number that is replaced at save time anyway.
        let referenceWeight = 70.0
        return met * referenceWeight * hours
    }

    // MARK: - Goal progress

    /// 0...1, or nil when no goal was set.
    var goalProgress: Double? {
        switch goal {
        case .none:
            return nil
        case .distance(let target):
            guard target > 0 else { return nil }
            return min(distance / target, 1)
        case .time(let target):
            guard target > 0 else { return nil }
            return min(movingDuration / target, 1)
        case .calories(let target):
            guard target > 0 else { return nil }
            return min(activeEnergy / target, 1)
        }
    }

    /// Seconds per kilometre over the whole activity so far.
    var averagePaceSecondsPerKm: Double {
        guard distance > 20, movingDuration > 0 else { return 0 }
        return movingDuration / (distance / 1000)
    }

    /// Seconds per kilometre over roughly the last 400 m, which is what runners
    /// mean by "current pace".
    var currentPaceSecondsPerKm: Double {
        guard points.count > 2 else { return 0 }

        var covered = 0.0
        var index = points.count - 1
        while index > 0, covered < 400 {
            covered += RouteMath.haversine(points[index - 1], points[index])
            index -= 1
        }
        guard covered > 50 else { return averagePaceSecondsPerKm }

        let interval = points[points.count - 1].elapsed - points[index].elapsed
        guard interval > 0 else { return averagePaceSecondsPerKm }
        let pace = interval / (covered / 1000)
        let floorPace: Double = activityType == .cycle ? 45 : 120
        return pace > floorPace && pace < 3600 ? pace : averagePaceSecondsPerKm
    }
}

/// An activity that has stopped recording but has not yet been saved.
struct FinishedActivity: Identifiable, Equatable {
    var sessionID: UUID
    var type: ActivityType
    var startDate: Date
    var endDate: Date
    var elapsedDuration: TimeInterval
    var movingDuration: TimeInterval
    var distance: Double
    var steps: Int
    var activeEnergy: Double
    var elevationGain: Double
    var elevationLoss: Double
    var points: [RoutePoint]
    var heartRates: [HeartRateSample]
    var splits: [Split]
    var wasRecovered: Bool = false

    var id: UUID { sessionID }

    var averagePaceSecondsPerKm: Double {
        guard distance > 10, movingDuration > 0 else { return 0 }
        return movingDuration / (distance / 1000)
    }

    var locations: [CLLocation] {
        points.map {
            CLLocation(
                coordinate: $0.coordinate,
                altitude: $0.altitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                verticalAccuracy: 10,
                timestamp: startDate.addingTimeInterval($0.elapsed)
            )
        }
    }
}
