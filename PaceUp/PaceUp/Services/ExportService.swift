//
//  ExportService.swift
//  Pace Up
//
//  Backup and GPX export.
//
//  Worth being precise about what this is for. Deleting Pace Up removes its
//  local database, but the app container is included in iCloud and encrypted
//  device backups, so restoring a new phone from backup restores Pace Up's data
//  too. Export is not the user's only safety net — it is the escape hatch that
//  lets them leave, move to another app, or keep a copy outside Apple's
//  ecosystem. The Settings copy should say so rather than implying the data is
//  otherwise at risk.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import CoreLocation

@MainActor
struct ExportService {

    let context: ModelContext

    enum ExportError: LocalizedError {
        case encodingFailed
        case writeFailed(String)
        case nothingToExport

        var errorDescription: String? {
            switch self {
            case .encodingFailed:      return String(localized: "Pace Up could not encode your data.")
            case .writeFailed(let m):  return m
            case .nothingToExport:     return String(localized: "There are no activities to export yet.")
            }
        }
    }

    // MARK: Full backup

    /// Writes a `.paceup.json` backup into the temporary directory and returns
    /// its URL, ready for a share sheet.
    func exportBackup() throws -> URL {
        let stats = StatsService(context: context)
        let activities = stats.allActivities()
        guard !activities.isEmpty else { throw ExportError.nothingToExport }

        let unlocks = (try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? []

        let backup = PaceUpBackup(
            formatVersion: PaceUpBackup.currentVersion,
            exportedAt: .now,
            appVersion: Bundle.main.shortVersionString,
            units: AppSettings.shared.units.rawValue,
            dailyStepGoal: AppSettings.shared.dailyStepGoal,
            activities: activities.map(PaceUpBackup.ActivityRecord.init),
            achievements: unlocks.map {
                PaceUpBackup.AchievementRecord(
                    kind: $0.kindRaw,
                    unlockedAt: $0.unlockedAt,
                    activityID: $0.activityID
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(backup) else { throw ExportError.encodingFailed }

        let filename = "PaceUp-Backup-\(Self.filenameDateFormatter.string(from: .now)).paceup.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        return url
    }

    // MARK: GPX

    /// Standard GPX 1.1 for a single activity, so the route opens in anything.
    func exportGPX(for activity: Activity) throws -> URL {
        let points = activity.routePoints
        guard !points.isEmpty else { throw ExportError.nothingToExport }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Pace Up" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(activity.title.xmlEscaped)</name>
            <time>\(iso.string(from: activity.startDate))</time>
          </metadata>
          <trk>
            <name>\(activity.title.xmlEscaped)</name>
            <type>\(activity.typeRaw)</type>
            <trkseg>

        """

        for point in points {
            let timestamp = iso.string(from: activity.startDate.addingTimeInterval(point.elapsed))
            xml += """
                  <trkpt lat="\(String(format: "%.7f", point.latitude))" lon="\(String(format: "%.7f", point.longitude))">
                    <ele>\(String(format: "%.1f", point.altitude))</ele>
                    <time>\(timestamp)</time>
                  </trkpt>

            """
        }

        xml += """
            </trkseg>
          </trk>
        </gpx>
        """

        let safeTitle = activity.title.replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeTitle) \(Self.filenameDateFormatter.string(from: activity.startDate)).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try xml.data(using: .utf8)?.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        return url
    }

    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Import

@MainActor
struct ImportService {

    let context: ModelContext

    struct Result: Equatable {
        var imported: Int
        var skipped: Int
    }

    enum ImportError: LocalizedError {
        case unreadable
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return String(localized: "That file isn't a Pace Up backup.")
            case .unsupportedVersion(let version):
                return String(localized: "This backup was made by a newer version of Pace Up (format \(version)).")
            }
        }
    }

    /// Restores a backup, skipping activities that already exist.
    ///
    /// Merging rather than replacing is the safer default: a user restoring an
    /// old backup onto a phone with recent activity should not lose the recent
    /// activity.
    func importBackup(from url: URL) throws -> Result {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(PaceUpBackup.self, from: data) else {
            throw ImportError.unreadable
        }
        guard backup.formatVersion <= PaceUpBackup.currentVersion else {
            throw ImportError.unsupportedVersion(backup.formatVersion)
        }

        let existing = Set(
            (((try? context.fetch(FetchDescriptor<Activity>())) ?? []).map(\.id))
        )

        var imported = 0
        var skipped = 0

        for record in backup.activities {
            guard !existing.contains(record.id) else {
                skipped += 1
                continue
            }

            let activity = Activity(
                id: record.id,
                startDate: record.startDate,
                endDate: record.endDate,
                type: ActivityType(rawValue: record.type) ?? .other,
                title: record.title,
                note: record.note,
                feeling: record.feeling,
                elapsedDuration: record.elapsedDuration,
                movingDuration: record.movingDuration,
                distance: record.distance,
                steps: record.steps,
                activeEnergy: record.activeEnergy,
                elevationGain: record.elevationGain,
                elevationLoss: record.elevationLoss,
                averageHeartRate: record.averageHeartRate,
                maxHeartRate: record.maxHeartRate,
                source: .imported
            )
            activity.splitsData = SampleCodec.encodeSplits(record.splits)
            activity.thumbnailRoute = record.thumbnailBase64.flatMap { Data(base64Encoded: $0) }
            activity.healthKitWorkoutUUID = record.healthKitWorkoutUUID
            activity.isDetailPurged = record.isDetailPurged

            if let routeBase64 = record.routeBase64, let routeData = Data(base64Encoded: routeBase64) {
                let detail = ActivityDetail(
                    routeData: routeData,
                    heartRateData: record.heartRateBase64.flatMap { Data(base64Encoded: $0) }
                )
                activity.detail = detail
                activity.isDetailPurged = false
            }

            activity.refreshBoundingBox()
            context.insert(activity)
            imported += 1
        }

        let existingUnlocks = Set(
            (((try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? []).map(\.kindRaw))
        )
        for record in backup.achievements where !existingUnlocks.contains(record.kind) {
            guard let kind = AchievementKind(rawValue: record.kind) else { continue }
            context.insert(AchievementUnlock(
                kind: kind,
                unlockedAt: record.unlockedAt,
                activityID: record.activityID
            ))
        }

        try? context.save()
        return Result(imported: imported, skipped: skipped)
    }
}

// MARK: - Helpers

extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
