//
//  ActivityType.swift
//  Pace Up
//

import Foundation
import SwiftUI

/// The kinds of activity Pace Up can record.
///
/// Raw values are persisted in SwiftData and in export files, so they must
/// never change once shipped. Add new cases; do not rename existing ones.
enum ActivityType: String, CaseIterable, Codable, Identifiable, Sendable {
    case walk
    case run
    case trailRun
    case hike
    case nordicWalk
    case cycle
    case wheelchair
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .walk:  return String(localized: "Walk")
        case .run:   return String(localized: "Run")
        case .trailRun: return String(localized: "Trail Run")
        case .hike:  return String(localized: "Hike")
        case .nordicWalk: return String(localized: "Nordic Walk")
        case .cycle: return String(localized: "Cycle")
        case .wheelchair: return String(localized: "Wheelchair")
        case .other: return String(localized: "Other")
        }
    }

    /// Noun used in generated activity titles, e.g. "Morning Run".
    var titleNoun: String { displayName }

    var symbolName: String {
        switch self {
        case .walk:  return "figure.walk"
        case .run:   return "figure.run"
        case .trailRun: return "figure.run.square.stack"
        case .hike:  return "figure.hiking"
        case .nordicWalk: return "figure.walk.motion"
        case .cycle: return "figure.outdoor.cycle"
        case .wheelchair: return "figure.roll"
        case .other: return "figure.mixed.cardio"
        }
    }

    var tint: Color {
        switch self {
        case .walk:  return .paceMint
        case .run:   return .paceLime
        case .trailRun: return .paceOrange
        case .hike:  return .paceViolet
        case .nordicWalk: return .paceAmber
        case .cycle: return .paceCyan
        case .wheelchair: return .paceMint
        case .other: return .paceAmber
        }
    }

    var artworkName: String {
        switch self {
        case .walk, .nordicWalk: return "ActivityWalk"
        case .run, .trailRun: return "ActivityRun"
        case .hike: return "ActivityExplore"
        case .cycle: return "ActivityCycle"
        case .wheelchair: return "ActivityWheelchair"
        case .other: return "StartTrails"
        }
    }

    /// Whether pace (time per distance) is the headline metric, versus speed.
    var prefersPaceOverSpeed: Bool {
        switch self {
        case .cycle: return false
        default:     return true
        }
    }

    /// Activities that are recorded with GPS by default.
    var usesGPS: Bool { true }
}
