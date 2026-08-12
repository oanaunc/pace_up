//
//  BackupFormat.swift
//  Pace Up
//
//  On-disk shape of a Pace Up backup.
//
//  The format is plain JSON with base64 route blobs rather than something more
//  compact, because the point of an export is that it remains readable without
//  Pace Up. A user should be able to open the file in any text editor, or feed
//  it to a script, years after the app is gone.
//

import Foundation

struct PaceUpBackup: Codable {
    /// Bumped whenever the shape changes incompatibly.
    var formatVersion: Int
    var exportedAt: Date
    var appVersion: String
    var units: String
    var dailyStepGoal: Int
    var activities: [ActivityRecord]
    var achievements: [AchievementRecord]

    static let currentVersion = 1

    struct ActivityRecord: Codable {
        var id: UUID
        var startDate: Date
        var endDate: Date
        var type: String
        var title: String
        var note: String?
        var feeling: Int?
        var elapsedDuration: TimeInterval
        var movingDuration: TimeInterval
        var distance: Double
        var steps: Int
        var activeEnergy: Double
        var elevationGain: Double
        var elevationLoss: Double
        var averageHeartRate: Double?
        var maxHeartRate: Double?
        var splits: [Split]
        /// Base64 `RouteCodec` blob. Nil when the route was purged.
        var routeBase64: String?
        /// Base64 `RouteCodec` blob of the simplified thumbnail.
        var thumbnailBase64: String?
        /// Base64 `SampleCodec` heart-rate blob.
        var heartRateBase64: String?
        var isDetailPurged: Bool
        var healthKitWorkoutUUID: UUID?
    }

    struct AchievementRecord: Codable {
        var kind: String
        var unlockedAt: Date
        var activityID: UUID?
    }
}

extension PaceUpBackup.ActivityRecord {
    init(_ activity: Activity) {
        self.id = activity.id
        self.startDate = activity.startDate
        self.endDate = activity.endDate
        self.type = activity.typeRaw
        self.title = activity.title
        self.note = activity.note
        self.feeling = activity.feeling
        self.elapsedDuration = activity.elapsedDuration
        self.movingDuration = activity.movingDuration
        self.distance = activity.distance
        self.steps = activity.steps
        self.activeEnergy = activity.activeEnergy
        self.elevationGain = activity.elevationGain
        self.elevationLoss = activity.elevationLoss
        self.averageHeartRate = activity.averageHeartRate
        self.maxHeartRate = activity.maxHeartRate
        self.splits = activity.splits
        self.routeBase64 = activity.detail?.routeData?.base64EncodedString()
        self.thumbnailBase64 = activity.thumbnailRoute?.base64EncodedString()
        self.heartRateBase64 = activity.detail?.heartRateData?.base64EncodedString()
        self.isDetailPurged = activity.isDetailPurged
        self.healthKitWorkoutUUID = activity.healthKitWorkoutUUID
    }
}
