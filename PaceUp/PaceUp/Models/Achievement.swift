//
//  Achievement.swift
//  Pace Up
//

import Foundation
import SwiftData
import SwiftUI

/// The catalogue of badges Pace Up can award.
///
/// Definitions live in code; only *unlocks* are persisted. That means the
/// catalogue can grow in a later release without a schema migration, and a
/// user who already qualifies for a new badge earns it on next launch.
enum AchievementKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case first5K
    case first10K
    case firstHalfMarathon
    case firstMarathon
    case streak7
    case streak30
    case steps10KDay
    case steps20KDay
    case steps100KTotal
    case steps1MTotal
    case distance100KTotal
    case earlyBird
    case nightOwl
    case elevation500
    case tenActivities
    case fiftyActivities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .first5K:            return String(localized: "First 5K")
        case .first10K:           return String(localized: "First 10K")
        case .firstHalfMarathon:  return String(localized: "Half Marathon")
        case .firstMarathon:      return String(localized: "Marathon")
        case .streak7:            return String(localized: "7 Day Streak")
        case .streak30:           return String(localized: "30 Day Streak")
        case .steps10KDay:        return String(localized: "10,000 Steps")
        case .steps20KDay:        return String(localized: "20,000 Steps")
        case .steps100KTotal:     return String(localized: "100,000 Steps")
        case .steps1MTotal:       return String(localized: "One Million Steps")
        case .distance100KTotal:  return String(localized: "100 Kilometres")
        case .earlyBird:          return String(localized: "Early Bird")
        case .nightOwl:           return String(localized: "Night Owl")
        case .elevation500:       return String(localized: "Climber")
        case .tenActivities:      return String(localized: "Getting Going")
        case .fiftyActivities:    return String(localized: "Fifty Up")
        }
    }

    var detail: String {
        switch self {
        case .first5K:            return String(localized: "Run 5 kilometres")
        case .first10K:           return String(localized: "Run 10 kilometres")
        case .firstHalfMarathon:  return String(localized: "Run 21.1 kilometres")
        case .firstMarathon:      return String(localized: "Run 42.2 kilometres")
        case .streak7:            return String(localized: "Be active 7 days in a row")
        case .streak30:           return String(localized: "Be active 30 days in a row")
        case .steps10KDay:        return String(localized: "Walk 10,000 steps in a day")
        case .steps20KDay:        return String(localized: "Walk 20,000 steps in a day")
        case .steps100KTotal:     return String(localized: "Walk 100,000 steps in total")
        case .steps1MTotal:       return String(localized: "Walk 1,000,000 steps in total")
        case .distance100KTotal:  return String(localized: "Cover 100 kilometres in total")
        case .earlyBird:          return String(localized: "Finish an activity before 7am")
        case .nightOwl:           return String(localized: "Finish an activity after 10pm")
        case .elevation500:       return String(localized: "Climb 500 metres in one activity")
        case .tenActivities:      return String(localized: "Complete 10 activities")
        case .fiftyActivities:    return String(localized: "Complete 50 activities")
        }
    }

    var symbolName: String {
        switch self {
        case .first5K, .first10K, .firstHalfMarathon, .firstMarathon:
            return "medal.fill"
        case .streak7, .streak30:
            return "flame.fill"
        case .steps10KDay, .steps20KDay, .steps100KTotal, .steps1MTotal:
            return "shoeprints.fill"
        case .distance100KTotal:
            return "map.fill"
        case .earlyBird:
            return "sunrise.fill"
        case .nightOwl:
            return "moon.stars.fill"
        case .elevation500:
            return "mountain.2.fill"
        case .tenActivities, .fiftyActivities:
            return "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .first5K, .first10K, .firstHalfMarathon, .firstMarathon: return .paceLime
        case .streak7, .streak30:                                      return .paceAmber
        case .steps10KDay, .steps20KDay:                               return .paceMint
        case .steps100KTotal, .steps1MTotal:                           return .paceCyan
        case .distance100KTotal:                                       return .paceViolet
        case .earlyBird:                                               return .paceAmber
        case .nightOwl:                                                return .paceViolet
        case .elevation500:                                            return .paceMint
        case .tenActivities, .fiftyActivities:                         return .paceLime
        }
    }

    /// Display order in the Achievements grid.
    var sortIndex: Int { AchievementKind.allCases.firstIndex(of: self) ?? 0 }
}

@Model
final class AchievementUnlock {
    @Attribute(.unique) var kindRaw: String
    var unlockedAt: Date
    /// The activity that triggered the unlock, when there was one.
    var activityID: UUID?

    init(kind: AchievementKind, unlockedAt: Date = .now, activityID: UUID? = nil) {
        self.kindRaw = kind.rawValue
        self.unlockedAt = unlockedAt
        self.activityID = activityID
    }

    var kind: AchievementKind? { AchievementKind(rawValue: kindRaw) }
}

/// A personal record, recomputed from permanent activity summaries.
///
/// Not persisted: records are always derivable from `Activity`, and deriving
/// them avoids the class of bug where a deleted activity leaves a stale record
/// behind.
struct PersonalRecord: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case fastest1K
        case fastest5K
        case fastest10K
        case longestDistance
        case longestDuration
        case mostStepsInADay
        case longestStreak
        case highestElevation

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fastest1K:        return String(localized: "Fastest 1K")
            case .fastest5K:        return String(localized: "Fastest 5K")
            case .fastest10K:       return String(localized: "Fastest 10K")
            case .longestDistance:  return String(localized: "Longest Run")
            case .longestDuration:  return String(localized: "Longest Duration")
            case .mostStepsInADay:  return String(localized: "Most Steps / Day")
            case .longestStreak:    return String(localized: "Longest Streak")
            case .highestElevation: return String(localized: "Biggest Climb")
            }
        }
    }

    var kind: Kind
    /// Preformatted value, e.g. "4:52" or "16.4 km".
    var formattedValue: String
    var achievedOn: Date?
    var activityID: UUID?

    var id: String { kind.rawValue }
}
