//
//  Activity.swift
//  Pace Up
//
//  The schema is deliberately split in two.
//
//  `Activity` is the permanent summary. It holds every number that the
//  Progress, Personal Records, Achievements and Profile screens depend on, plus
//  a ~60 point simplified route used for list thumbnails. It is never deleted
//  by the retention policy. A year of daily activities costs a few hundred
//  kilobytes.
//
//  `ActivityDetail` is the heavy, purgeable payload: the full GPS trace and the
//  heart-rate series. This is what "Delete data older than 30 days" removes.
//  Deleting it costs the user a route map and detail charts on old activities;
//  it costs them nothing on lifetime totals, streaks or personal records.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Activity {

    // MARK: Identity

    #Index<Activity>([\.startDate], [\.typeRaw])

    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date

    /// Backing store for `type`. Stored as a string so new activity kinds do
    /// not invalidate existing rows.
    var typeRaw: String

    /// User-visible title, e.g. "Morning Run". Editable.
    var title: String
    var note: String?

    /// 1...5, matching the five faces on the post-activity screen. Nil if the
    /// user skipped the prompt.
    var feeling: Int?

    // MARK: Headline metrics (permanent)

    /// Wall-clock time from start to finish, including pauses.
    var elapsedDuration: TimeInterval
    /// Time excluding paused periods. This is what pace is calculated from.
    var movingDuration: TimeInterval
    /// Metres, measured from the GPS trace.
    var distance: Double
    /// Steps attributed to this activity.
    var steps: Int
    /// Active energy burned, in kilocalories.
    var activeEnergy: Double
    /// Cumulative ascent in metres.
    var elevationGain: Double
    /// Cumulative descent in metres.
    var elevationLoss: Double
    var averageHeartRate: Double?
    var maxHeartRate: Double?

    // MARK: Permanent lightweight derivatives

    /// Simplified route (max ~60 points) for list and grid thumbnails. Survives
    /// the retention purge.
    var thumbnailRoute: Data?
    /// Per-unit splits, JSON encoded. Survives the retention purge.
    var splitsData: Data?
    /// Bounding box of the route, so a map can frame an activity without
    /// decoding anything.
    var minLatitude: Double?
    var maxLatitude: Double?
    var minLongitude: Double?
    var maxLongitude: Double?

    // MARK: Provenance

    /// UUID of the HKWorkout Pace Up wrote for this activity, if any. Used to
    /// avoid re-importing our own workouts from HealthKit.
    var healthKitWorkoutUUID: UUID?
    /// Where the activity came from: recorded in Pace Up, or imported.
    var sourceRaw: String

    // MARK: Retention

    /// Set when the retention policy removes `detail`. Distinguishes "this run
    /// had no GPS" from "we deleted the GPS".
    var isDetailPurged: Bool
    var detailPurgedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ActivityDetail.activity)
    var detail: ActivityDetail?

    // MARK: Init

    init(id: UUID = UUID(),
         startDate: Date,
         endDate: Date,
         type: ActivityType,
         title: String? = nil,
         note: String? = nil,
         feeling: Int? = nil,
         elapsedDuration: TimeInterval,
         movingDuration: TimeInterval,
         distance: Double,
         steps: Int = 0,
         activeEnergy: Double = 0,
         elevationGain: Double = 0,
         elevationLoss: Double = 0,
         averageHeartRate: Double? = nil,
         maxHeartRate: Double? = nil,
         source: ActivitySource = .paceUp) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.typeRaw = type.rawValue
        self.title = title ?? Activity.generatedTitle(for: type, at: startDate)
        self.note = note
        self.feeling = feeling
        self.elapsedDuration = elapsedDuration
        self.movingDuration = movingDuration
        self.distance = distance
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.sourceRaw = source.rawValue
        self.isDetailPurged = false
    }

    // MARK: Derived

    var type: ActivityType {
        get { ActivityType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var source: ActivitySource {
        get { ActivitySource(rawValue: sourceRaw) ?? .paceUp }
        set { sourceRaw = newValue.rawValue }
    }

    /// Seconds per kilometre over the moving portion of the activity.
    /// Zero when the activity covered no distance.
    var averagePaceSecondsPerKm: Double {
        guard distance > 10, movingDuration > 0 else { return 0 }
        return movingDuration / (distance / 1000)
    }

    /// Metres per second over the moving portion.
    var averageSpeed: Double {
        guard movingDuration > 0 else { return 0 }
        return distance / movingDuration
    }

    var splits: [Split] {
        SampleCodec.decodeSplits(splitsData)
    }

    /// Fastest complete split, used for the "best pace" readout.
    ///
    /// The trailing partial split is excluded. A 950 m final split run hard
    /// would otherwise be reported as the fastest kilometre of the activity.
    func bestSplitPaceSecondsPerKm(unitDistance: Double) -> Double? {
        splits
            .filter { !$0.isPartial(unitDistance: unitDistance) }
            .map(\.paceSecondsPerKm)
            .filter { $0 > 0 }
            .min()
    }

    var thumbnailCoordinates: [CLLocationCoordinate2D] {
        RouteCodec.decode(thumbnailRoute).map(\.coordinate)
    }

    /// The full GPS trace, or an empty array if it was never recorded or has
    /// been purged. Decoding is lazy — only call this when a map is on screen.
    var routePoints: [RoutePoint] {
        RouteCodec.decode(detail?.routeData)
    }

    var heartRateSamples: [HeartRateSample] {
        SampleCodec.decodeHeartRate(detail?.heartRateData)
    }

    var hasRoute: Bool {
        (thumbnailRoute?.isEmpty == false) || RouteCodec.count(in: detail?.routeData) > 0
    }

    var hasFullRoute: Bool {
        RouteCodec.count(in: detail?.routeData) > 1
    }

    // MARK: Mutation helpers

    /// Attaches a freshly recorded trace, building the permanent thumbnail and
    /// bounding box at the same time.
    func attachRoute(_ points: [RoutePoint], heartRate: [HeartRateSample]) {
        guard !points.isEmpty else { return }

        let detail = self.detail ?? ActivityDetail()
        detail.routeData = RouteCodec.encode(points)
        detail.heartRateData = SampleCodec.encodeHeartRate(heartRate)
        self.detail = detail
        self.isDetailPurged = false
        self.detailPurgedAt = nil

        thumbnailRoute = RouteCodec.encode(RouteCodec.simplified(points, limit: 60))

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        minLatitude = latitudes.min()
        maxLatitude = latitudes.max()
        minLongitude = longitudes.min()
        maxLongitude = longitudes.max()
    }

    /// Recomputes the cached bounding box from whatever route data is present.
    /// Used on import, where the box is not carried in the backup file.
    func refreshBoundingBox() {
        let points = RouteCodec.decode(detail?.routeData).isEmpty
            ? RouteCodec.decode(thumbnailRoute)
            : RouteCodec.decode(detail?.routeData)
        guard !points.isEmpty else { return }
        minLatitude = points.map(\.latitude).min()
        maxLatitude = points.map(\.latitude).max()
        minLongitude = points.map(\.longitude).min()
        maxLongitude = points.map(\.longitude).max()
    }

    /// Removes the heavy payload while leaving every permanent field intact.
    func purgeDetail(on date: Date = .now) {
        guard detail != nil else { return }
        detail = nil
        isDetailPurged = true
        detailPurgedAt = date
    }

    // MARK: Titles

    static func generatedTitle(for type: ActivityType, at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let period: String
        switch hour {
        case 0..<5:   period = String(localized: "Night")
        case 5..<12:  period = String(localized: "Morning")
        case 12..<17: period = String(localized: "Afternoon")
        case 17..<21: period = String(localized: "Evening")
        default:      period = String(localized: "Night")
        }
        return "\(period) \(type.titleNoun)"
    }
}

/// Where an activity's numbers came from.
enum ActivitySource: String, Codable, Sendable {
    /// Recorded by Pace Up's own GPS recorder.
    case paceUp
    /// Imported from a HealthKit workout written by another app.
    case healthKit
    /// Restored from a Pace Up backup file.
    case imported
}

/// The purgeable half of an activity.
@Model
final class ActivityDetail {
    var id: UUID
    /// Full GPS trace, `RouteCodec` encoded.
    var routeData: Data?
    /// Heart-rate series, `SampleCodec` encoded.
    var heartRateData: Data?

    var activity: Activity?

    init(id: UUID = UUID(), routeData: Data? = nil, heartRateData: Data? = nil) {
        self.id = id
        self.routeData = routeData
        self.heartRateData = heartRateData
    }

    /// Approximate on-disk cost, used by the Data & Privacy screen.
    var byteCount: Int {
        (routeData?.count ?? 0) + (heartRateData?.count ?? 0)
    }
}
