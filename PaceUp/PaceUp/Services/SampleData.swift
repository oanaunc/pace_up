//
//  SampleData.swift
//  Pace Up
//
//  Synthetic activities so SwiftUI previews and the simulator show something
//  resembling a real user. Never referenced from a release code path other than
//  previews.
//

import Foundation
import SwiftData

enum SampleData {

    @MainActor
    static func populate(_ context: ModelContext) {
        let calendar = Calendar.current
        let now = Date.now

        let specs: [(offsetDays: Int, hour: Int, type: ActivityType, distance: Double, duration: TimeInterval, title: String)] = [
            (0,  7,  .run,  5_240, 34 * 60 + 7,   "Morning Run"),
            (1,  18, .run,  4_010, 24 * 60 + 38,  "Evening Run"),
            (3,  8,  .run,  3_220, 19 * 60 + 35,  "Park Run"),
            (5,  7,  .run,  10_210, 62 * 60 + 11, "Long Run"),
            (7,  9,  .hike, 7_320, 48 * 60,       "Trail Run"),
            (9,  12, .walk, 3_900, 44 * 60,       "Lunch Walk"),
            (12, 7,  .run,  8_050, 47 * 60 + 22,  "Morning Run"),
            (15, 19, .walk, 2_400, 28 * 60,       "Evening Walk"),
            (20, 8,  .run,  16_400, 98 * 60,      "Long Run"),
            (26, 17, .cycle, 22_600, 62 * 60,     "Afternoon Ride"),
            (34, 7,  .run,  5_030, 33 * 60 + 12,  "Morning Run"),
            (41, 10, .hike, 11_800, 3 * 3600,     "Ridge Hike")
        ]

        for spec in specs {
            guard
                let day = calendar.date(byAdding: .day, value: -spec.offsetDays, to: now),
                let start = calendar.date(bySettingHour: spec.hour, minute: 12, second: 0, of: day)
            else { continue }

            let end = start.addingTimeInterval(spec.duration)
            let points = syntheticRoute(
                distance: spec.distance,
                duration: spec.duration,
                seed: spec.offsetDays
            )
            let elevation = RouteMath.elevationChange(of: points)

            let activity = Activity(
                startDate: start,
                endDate: end,
                type: spec.type,
                title: spec.title,
                elapsedDuration: spec.duration,
                movingDuration: spec.duration,
                distance: spec.distance,
                steps: Int(spec.distance / 0.78),
                activeEnergy: spec.distance / 1000 * 68,
                elevationGain: elevation.gain,
                elevationLoss: elevation.loss,
                averageHeartRate: 148,
                maxHeartRate: 171
            )
            activity.splitsData = SampleCodec.encodeSplits(
                RouteMath.splits(from: points, unitDistance: 1000)
            )
            activity.attachRoute(points, heartRate: syntheticHeartRate(duration: spec.duration))

            // Older activities model the post-purge state, so previews exercise
            // the "route no longer available" path.
            if spec.offsetDays > 30 {
                activity.purgeDetail(on: now)
            }

            context.insert(activity)
        }

        for kind in [AchievementKind.first5K, .streak7, .steps100KTotal, .tenActivities] {
            context.insert(AchievementUnlock(kind: kind, unlockedAt: now.addingTimeInterval(-86_400 * 4)))
        }

        try? context.save()
    }

    /// A meandering loop around a fixed origin. Not a real place — just enough
    /// shape that polylines, splits and elevation charts have something to draw.
    static func syntheticRoute(distance: Double,
                               duration: TimeInterval,
                               seed: Int,
                               origin: (lat: Double, lon: Double) = (37.3349, -122.0090)) -> [RoutePoint] {
        let sampleCount = max(60, Int(duration / 3))
        var points: [RoutePoint] = []
        points.reserveCapacity(sampleCount)

        // Rough degrees-per-metre at this latitude.
        let metresPerDegreeLat = 111_320.0
        let metresPerDegreeLon = 111_320.0 * cos(origin.lat * .pi / 180)
        let radius = distance / (2 * .pi)
        let wobble = Double(seed % 7) * 0.12 + 0.35

        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleCount - 1)
            let angle = t * 2 * .pi
            let r = radius * (1 + wobble * sin(angle * 3 + Double(seed)))

            let dx = cos(angle) * r
            let dy = sin(angle) * r * 0.72

            points.append(RoutePoint(
                latitude: origin.lat + dy / metresPerDegreeLat,
                longitude: origin.lon + dx / metresPerDegreeLon,
                altitude: 42 + 28 * sin(angle * 2 + Double(seed)) + 6 * sin(angle * 9),
                elapsed: t * duration,
                speed: distance / duration,
                horizontalAccuracy: 5
            ))
        }
        return points
    }

    static func syntheticHeartRate(duration: TimeInterval) -> [HeartRateSample] {
        stride(from: 0.0, to: duration, by: 15).map { t in
            let progress = t / max(duration, 1)
            let base = 132 + 26 * progress
            return HeartRateSample(elapsed: t, bpm: base + 6 * sin(t / 40))
        }
    }
}
