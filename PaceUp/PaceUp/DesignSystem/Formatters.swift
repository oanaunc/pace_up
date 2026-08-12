//
//  Formatters.swift
//  Pace Up
//
//  All user-facing number formatting lives here so that a unit change flips
//  every screen at once, and so pace formatting — the easiest thing in a
//  running app to get subtly wrong — has exactly one implementation.
//

import Foundation
import SwiftUI

enum PaceFormat {

    // MARK: Distance

    /// "5.24" — the numeric part only, so callers can style the unit separately.
    static func distanceValue(_ meters: Double, units: MeasurementUnits) -> String {
        let value = units == .metric ? meters / 1000 : meters / 1609.344
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    /// "5.24 km"
    static func distance(_ meters: Double, units: MeasurementUnits) -> String {
        "\(distanceValue(meters, units: units)) \(units.distanceAbbreviation)"
    }

    // MARK: Duration

    /// "34:07" under an hour, "1:02:11" over. Matches the comps.
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "00:31:42" — always hours, for the live activity readout.
    static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00:00" }
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    // MARK: Pace

    /// "6:31" — minutes and seconds per kilometre or mile.
    ///
    /// Input is always seconds per kilometre; conversion to per-mile happens
    /// here so callers never have to remember which unit they hold.
    static func paceValue(secondsPerKm: Double, units: MeasurementUnits) -> String {
        guard secondsPerKm.isFinite, secondsPerKm > 0, secondsPerKm < 7200 else { return "--:--" }
        let converted = units == .metric ? secondsPerKm : secondsPerKm * 1.609344
        let total = Int(converted.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// "6:31 /km"
    static func pace(secondsPerKm: Double, units: MeasurementUnits) -> String {
        "\(paceValue(secondsPerKm: secondsPerKm, units: units)) /\(units.distanceAbbreviation)"
    }

    static func paceUnitLabel(_ units: MeasurementUnits) -> String {
        "/\(units.distanceAbbreviation)"
    }

    /// "18.4 km/h" — used for cycling, where pace is the wrong metric.
    static func speed(metersPerSecond: Double, units: MeasurementUnits) -> String {
        guard metersPerSecond.isFinite, metersPerSecond > 0 else { return "--" }
        let value = units == .metric ? metersPerSecond * 3.6 : metersPerSecond * 2.236936
        let suffix = units == .metric ? "km/h" : "mph"
        return String(format: "%.1f %@", value, suffix)
    }

    // MARK: Elevation

    /// "+84 m"
    static func elevation(_ meters: Double, units: MeasurementUnits, signed: Bool = true) -> String {
        let value = units == .metric ? meters : meters * 3.28084
        let prefix = signed && value > 0 ? "+" : ""
        return "\(prefix)\(Int(value.rounded())) \(units.elevationAbbreviation)"
    }

    // MARK: Counts

    /// "6,824"
    static func steps(_ steps: Int) -> String {
        steps.formatted(.number.grouping(.automatic))
    }

    /// "1.8M" for the profile header, where space is tight.
    static func compactCount(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    /// "382" kcal
    static func energy(_ kcal: Double) -> String {
        "\(Int(kcal.rounded()))"
    }

    // MARK: Dates

    /// "May 15, 7:42 AM"
    static func activityTimestamp(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// "Wednesday, May 15"
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// Section headers in the activity list: "Today", "Yesterday", "May 12".
    static func relativeDay(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Splits

    /// Label for a split row: "1", "2" ... "0.24" for the trailing partial.
    static func splitLabel(_ split: Split, units: MeasurementUnits) -> String {
        if split.isPartial(unitDistance: units.splitDistance) {
            let fraction = split.distance / units.splitDistance
            return String(format: "%.2f", fraction)
        }
        return "\(split.index)"
    }
}
