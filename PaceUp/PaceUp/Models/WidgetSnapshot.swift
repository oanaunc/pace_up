//
//  WidgetSnapshot.swift
//  Pace Up
//
//  The app writes this to shared defaults after every HealthKit refresh and
//  every finished activity; the widget reads it.
//
//  Rationale: a widget extension *can* query HealthKit, but HealthKit reads
//  from an extension are slow, subject to their own authorization prompts, and
//  frequently return nothing on first timeline generation. Rendering from a
//  snapshot the app already computed is faster and never shows an empty widget.
//

import Foundation
import WidgetKit

struct WidgetSnapshot: Codable, Equatable, Sendable {
    var steps: Int
    var goal: Int
    var distanceMeters: Double
    var activeEnergy: Double
    var activeMinutes: Int
    /// Steps for the last seven days, oldest first. Used by the medium and
    /// large widgets' bar chart.
    var weeklySteps: [Int]
    /// First letters of the weekday labels aligned with `weeklySteps`.
    var weekdayInitials: [String]
    var currentStreak: Int
    var updatedAt: Date
    var usesMetric: Bool

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    static let placeholder = WidgetSnapshot(
        steps: 7842,
        goal: 10000,
        distanceMeters: 5800,
        activeEnergy: 326,
        activeMinutes: 74,
        weeklySteps: [6200, 9100, 7400, 11200, 8300, 5600, 7842],
        weekdayInitials: ["M", "T", "W", "T", "F", "S", "S"],
        currentStreak: 8,
        updatedAt: .now,
        usesMetric: true
    )
}

enum WidgetBridge {

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: SharedDefaultsKey.widgetSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: SharedDefaultsKey.widgetSnapshot) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
