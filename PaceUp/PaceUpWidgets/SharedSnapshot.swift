//
//  SharedSnapshot.swift
//  Pace Up Widgets
//
//  A deliberate, self-contained copy of the snapshot type and App Group
//  constants.
//
//  The alternative — sharing source files between the app and the extension —
//  means either a framework target or per-file target membership, both of which
//  add project complexity for forty lines of plain data. If the shape of
//  `WidgetSnapshot` changes in the app, change it here too; `formatVersion`-style
//  drift is guarded against by the decoder simply returning nil and the widget
//  falling back to its placeholder.
//

import Foundation
import SwiftUI

enum WidgetAppGroup {
    /// Must match `AppGroup.identifier` in the app target.
    static let identifier = "group.com.paceup.shared"
    static let snapshotKey = "widgetSnapshot"
    static let stepGoalKey = "dailyStepGoal"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

struct WidgetSnapshot: Codable, Equatable, Sendable {
    var steps: Int
    var goal: Int
    var distanceMeters: Double
    var activeEnergy: Double
    var activeMinutes: Int
    var weeklySteps: [Int]
    var weekdayInitials: [String]
    var currentStreak: Int
    var updatedAt: Date
    var usesMetric: Bool

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    var formattedDistance: String {
        let value = usesMetric ? distanceMeters / 1000 : distanceMeters / 1609.344
        let unit = usesMetric ? "km" : "mi"
        return String(format: "%.1f %@", value, unit)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = WidgetAppGroup.defaults.data(forKey: WidgetAppGroup.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
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

extension Color {
    static let widgetLime = Color(red: 0.800, green: 0.929, blue: 0.192)
    static let widgetInk = Color(red: 0.043, green: 0.051, blue: 0.043)
    static let widgetSecondary = Color.white.opacity(0.62)
    static let widgetTertiary = Color.white.opacity(0.38)
}

/// Leading-dot lookup in `foregroundStyle(_:)` resolves against `ShapeStyle`.
extension ShapeStyle where Self == Color {
    static var widgetLime: Color { .widgetLime }
    static var widgetInk: Color { .widgetInk }
    static var widgetSecondary: Color { .widgetSecondary }
    static var widgetTertiary: Color { .widgetTertiary }
}
