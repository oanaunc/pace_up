//
//  AppSettings.swift
//  Pace Up
//
//  Preferences live in the shared App Group UserDefaults rather than SwiftData
//  so the widget extension can read the daily step goal without opening the
//  model container.
//

import Foundation
import SwiftUI
import Combine

enum MeasurementUnits: String, CaseIterable, Codable, Sendable {
    case metric
    case imperial

    var displayName: String {
        switch self {
        case .metric:   return String(localized: "Kilometres")
        case .imperial: return String(localized: "Miles")
        }
    }

    /// Length of one split, in metres.
    var splitDistance: Double {
        switch self {
        case .metric:   return 1000
        case .imperial: return 1609.344
        }
    }

    var distanceAbbreviation: String {
        switch self {
        case .metric:   return "km"
        case .imperial: return "mi"
        }
    }

    var elevationAbbreviation: String {
        switch self {
        case .metric:   return "m"
        case .imperial: return "ft"
        }
    }
}

/// The user's stated reason for using Pace Up, chosen during onboarding.
/// Purely used to pick sensible defaults and copy; it does not gate features.
enum PrimaryGoal: String, CaseIterable, Codable, Identifiable, Sendable {
    case walkMore
    case runMore
    case stayActive
    case improveFitness
    case trackAdventures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walkMore:        return String(localized: "Walk more")
        case .runMore:         return String(localized: "Run more")
        case .stayActive:      return String(localized: "Stay active")
        case .improveFitness:  return String(localized: "Improve my fitness")
        case .trackAdventures: return String(localized: "Track my adventures")
        }
    }

    var symbolName: String {
        switch self {
        case .walkMore:        return "figure.walk"
        case .runMore:         return "figure.run"
        case .stayActive:      return "figure.stand"
        case .improveFitness:  return "figure.strengthtraining.functional"
        case .trackAdventures: return "figure.hiking"
        }
    }

    var suggestedStepGoal: Int {
        switch self {
        case .walkMore:        return 12000
        case .runMore:         return 10000
        case .stayActive:      return 8000
        case .improveFitness:  return 10000
        case .trackAdventures: return 10000
        }
    }
}

/// Keys shared between the app and the widget extension.
enum SharedDefaultsKey {
    static let dailyStepGoal = "dailyStepGoal"
    static let units = "units"
    static let primaryGoal = "primaryGoal"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let autoPurgeEnabled = "autoPurgeEnabled"
    static let retentionDays = "retentionDays"
    static let lastPurgeDate = "lastPurgeDate"
    static let autoPauseEnabled = "autoPauseEnabled"
    static let voiceAnnouncementsEnabled = "voiceAnnouncementsEnabled"
    static let keepScreenAwake = "keepScreenAwake"
    static let mapStyle = "mapStyle"

    /// Snapshot written by the app for the widget to render.
    static let widgetSnapshot = "widgetSnapshot"
}

enum AppGroup {
    /// Must match the App Group capability on both the app and widget targets.
    static let identifier = "group.com.oanarinaldi.paceup"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

/// Observable wrapper over the shared defaults.
@MainActor
@Observable
final class AppSettings {

    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            SharedDefaultsKey.dailyStepGoal: 10000,
            SharedDefaultsKey.units: MeasurementUnits.metric.rawValue,
            SharedDefaultsKey.autoPurgeEnabled: false,
            SharedDefaultsKey.retentionDays: 30,
            SharedDefaultsKey.autoPauseEnabled: true,
            SharedDefaultsKey.voiceAnnouncementsEnabled: false,
            SharedDefaultsKey.keepScreenAwake: true,
            SharedDefaultsKey.hasCompletedOnboarding: false
        ])
    }

    var dailyStepGoal: Int {
        get { access(keyPath: \.dailyStepGoal); return defaults.integer(forKey: SharedDefaultsKey.dailyStepGoal) }
        set { withMutation(keyPath: \.dailyStepGoal) { defaults.set(newValue, forKey: SharedDefaultsKey.dailyStepGoal) } }
    }

    var units: MeasurementUnits {
        get {
            access(keyPath: \.units)
            let raw = defaults.string(forKey: SharedDefaultsKey.units) ?? ""
            return MeasurementUnits(rawValue: raw) ?? .metric
        }
        set { withMutation(keyPath: \.units) { defaults.set(newValue.rawValue, forKey: SharedDefaultsKey.units) } }
    }

    var primaryGoal: PrimaryGoal? {
        get {
            access(keyPath: \.primaryGoal)
            guard let raw = defaults.string(forKey: SharedDefaultsKey.primaryGoal) else { return nil }
            return PrimaryGoal(rawValue: raw)
        }
        set { withMutation(keyPath: \.primaryGoal) { defaults.set(newValue?.rawValue, forKey: SharedDefaultsKey.primaryGoal) } }
    }

    var hasCompletedOnboarding: Bool {
        get { access(keyPath: \.hasCompletedOnboarding); return defaults.bool(forKey: SharedDefaultsKey.hasCompletedOnboarding) }
        set { withMutation(keyPath: \.hasCompletedOnboarding) { defaults.set(newValue, forKey: SharedDefaultsKey.hasCompletedOnboarding) } }
    }

    var autoPurgeEnabled: Bool {
        get { access(keyPath: \.autoPurgeEnabled); return defaults.bool(forKey: SharedDefaultsKey.autoPurgeEnabled) }
        set { withMutation(keyPath: \.autoPurgeEnabled) { defaults.set(newValue, forKey: SharedDefaultsKey.autoPurgeEnabled) } }
    }

    var retentionDays: Int {
        get { access(keyPath: \.retentionDays); return max(1, defaults.integer(forKey: SharedDefaultsKey.retentionDays)) }
        set { withMutation(keyPath: \.retentionDays) { defaults.set(newValue, forKey: SharedDefaultsKey.retentionDays) } }
    }

    var autoPauseEnabled: Bool {
        get { access(keyPath: \.autoPauseEnabled); return defaults.bool(forKey: SharedDefaultsKey.autoPauseEnabled) }
        set { withMutation(keyPath: \.autoPauseEnabled) { defaults.set(newValue, forKey: SharedDefaultsKey.autoPauseEnabled) } }
    }

    var voiceAnnouncementsEnabled: Bool {
        get { access(keyPath: \.voiceAnnouncementsEnabled); return defaults.bool(forKey: SharedDefaultsKey.voiceAnnouncementsEnabled) }
        set { withMutation(keyPath: \.voiceAnnouncementsEnabled) { defaults.set(newValue, forKey: SharedDefaultsKey.voiceAnnouncementsEnabled) } }
    }

    var keepScreenAwake: Bool {
        get { access(keyPath: \.keepScreenAwake); return defaults.bool(forKey: SharedDefaultsKey.keepScreenAwake) }
        set { withMutation(keyPath: \.keepScreenAwake) { defaults.set(newValue, forKey: SharedDefaultsKey.keepScreenAwake) } }
    }

    var lastPurgeDate: Date? {
        get {
            access(keyPath: \.lastPurgeDate)
            let interval = defaults.double(forKey: SharedDefaultsKey.lastPurgeDate)
            return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
        set {
            withMutation(keyPath: \.lastPurgeDate) {
                defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: SharedDefaultsKey.lastPurgeDate)
            }
        }
    }
}
