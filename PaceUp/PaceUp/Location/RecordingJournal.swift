//
//  RecordingJournal.swift
//  Pace Up
//
//  Crash-resilient recording.
//
//  iOS can terminate a backgrounded app at any time — memory pressure, a long
//  phone call, a thermal event. If the only copy of a run lives in memory until
//  the user taps Finish, a termination at kilometre nine loses the whole thing,
//  and that is the review a fitness app never recovers from.
//
//  So every accepted GPS fix is appended to a file the moment it arrives.
//  Appending 32 bytes to an open file descriptor costs microseconds and does
//  not touch SwiftData. On launch, a journal that was never marked finished is
//  offered back to the user as a recoverable activity.
//

import Foundation
import CoreLocation

/// Metadata written alongside the binary point stream.
struct JournalHeader: Codable, Equatable, Sendable {
    var sessionID: UUID
    var activityTypeRaw: String
    var startDate: Date
    /// Updated on every pause/resume so elapsed time survives a crash.
    var pausedIntervals: [PausedInterval]
    var lastUpdate: Date
    /// Set when the user finishes or discards normally. A journal without this
    /// is what triggers the recovery prompt.
    var isFinished: Bool

    struct PausedInterval: Codable, Equatable, Sendable {
        var start: Date
        var end: Date?

        /// An interval left open by a termination must be closed against the
        /// journal's last write, not against the moment of recovery. Measuring
        /// against `.now` makes an overnight relaunch report a thirteen-hour
        /// pause and a zero-length run.
        func duration(closingAt fallback: Date) -> TimeInterval {
            max(0, (end ?? fallback).timeIntervalSince(start))
        }
    }

    var activityType: ActivityType {
        ActivityType(rawValue: activityTypeRaw) ?? .other
    }

    var totalPausedDuration: TimeInterval {
        pausedIntervals.reduce(0) { $0 + $1.duration(closingAt: lastUpdate) }
    }
}

/// A recoverable session found on disk at launch.
struct RecoverableSession: Identifiable, Equatable {
    var header: JournalHeader
    var points: [RoutePoint]
    var id: UUID { header.sessionID }

    var estimatedDistance: Double {
        RouteMath.distance(of: points)
    }

    var estimatedDuration: TimeInterval {
        max(0, header.lastUpdate.timeIntervalSince(header.startDate) - header.totalPausedDuration)
    }
}

/// Serial, ordered, append-only writer.
///
/// Implemented on a serial `DispatchQueue` rather than as an `actor` on purpose.
/// Calls into an actor from separate `Task`s are not guaranteed to run in the
/// order they were made, which for an append-only file means GPS fixes could be
/// written out of sequence and a recovered route would zig-zag. A serial queue
/// is FIFO by construction.
final class RecordingJournal: @unchecked Sendable {

    static let shared = RecordingJournal()

    private let queue = DispatchQueue(label: "com.oanarinaldi.paceup.recording-journal", qos: .utility)
    private var handle: FileHandle?
    private var header: JournalHeader?
    private var pointCount = 0

    // MARK: Paths

    private static var directory: URL {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Recording", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var headerURL: URL { directory.appendingPathComponent("session.json") }
    private static var pointsURL: URL { directory.appendingPathComponent("session.points") }

    // MARK: Lifecycle

    func begin(sessionID: UUID, type: ActivityType, startDate: Date) {
        queue.async {
            self.closeHandle()
            try? FileManager.default.removeItem(at: Self.pointsURL)
            FileManager.default.createFile(atPath: Self.pointsURL.path, contents: nil)

            let header = JournalHeader(
                sessionID: sessionID,
                activityTypeRaw: type.rawValue,
                startDate: startDate,
                pausedIntervals: [],
                lastUpdate: startDate,
                isFinished: false
            )
            self.header = header
            self.pointCount = 0
            self.writeHeader(header)

            self.handle = try? FileHandle(forWritingTo: Self.pointsURL)
            try? self.handle?.seekToEnd()
        }
    }

    /// Appends one fix. Called for every accepted location update.
    func append(_ point: RoutePoint) {
        queue.async {
            guard let handle = self.handle else { return }
            var data = Data(capacity: 32)
            data.appendLE(point.latitude)
            data.appendLE(point.longitude)
            data.appendLE(Float(point.altitude))
            data.appendLE(Float(point.elapsed))
            data.appendLE(Float(point.speed))
            data.appendLE(Float(point.horizontalAccuracy))
            try? handle.write(contentsOf: data)
            self.pointCount += 1

            // Flush the header roughly every 15 points so `lastUpdate` is close
            // to reality if the app is killed. Rewriting it per point would be
            // wasteful for a field only used to estimate a recovered duration.
            if self.pointCount % 15 == 0, var header = self.header {
                header.lastUpdate = .now
                self.header = header
                self.writeHeader(header)
            }
        }
    }

    func recordPauseStarted(at date: Date) {
        queue.async {
            guard var header = self.header else { return }
            header.pausedIntervals.append(.init(start: date, end: nil))
            header.lastUpdate = date
            self.header = header
            self.writeHeader(header)
        }
    }

    func recordPauseEnded(at date: Date) {
        queue.async {
            guard var header = self.header, !header.pausedIntervals.isEmpty else { return }
            header.pausedIntervals[header.pausedIntervals.count - 1].end = date
            header.lastUpdate = date
            self.header = header
            self.writeHeader(header)
        }
    }

    /// Marks the session complete so it is not offered for recovery, and clears
    /// the files.
    func finish() {
        queue.async {
            if var header = self.header {
                header.isFinished = true
                header.lastUpdate = .now
                self.writeHeader(header)
            }
            self.closeHandle()
            try? FileManager.default.removeItem(at: Self.pointsURL)
            try? FileManager.default.removeItem(at: Self.headerURL)
            self.header = nil
            self.pointCount = 0
        }
    }

    private func closeHandle() {
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil
    }

    private func writeHeader(_ header: JournalHeader) {
        guard let data = try? JSONEncoder().encode(header) else { return }
        try? data.write(to: Self.headerURL, options: .atomic)
    }

    // MARK: Recovery

    /// Returns an unfinished session if one is on disk.
    ///
    /// Only sessions with enough points to be a real activity are offered back;
    /// a handful of fixes from a start the user immediately abandoned is noise.
    static func pendingRecovery(minimumPoints: Int = 20) -> RecoverableSession? {
        guard
            let headerData = try? Data(contentsOf: headerURL),
            let header = try? JSONDecoder().decode(JournalHeader.self, from: headerData),
            !header.isFinished,
            let pointData = try? Data(contentsOf: pointsURL)
        else { return nil }

        let points = decodeRaw(pointData)
        guard points.count >= minimumPoints else {
            discard()
            return nil
        }
        return RecoverableSession(header: header, points: points)
    }

    static func discard() {
        try? FileManager.default.removeItem(at: pointsURL)
        try? FileManager.default.removeItem(at: headerURL)
    }

    /// The journal stores bare 32-byte records with no header, so it can be
    /// appended to without rewriting a count.
    private static func decodeRaw(_ data: Data) -> [RoutePoint] {
        let bytes = [UInt8](data)
        let count = bytes.count / 32
        guard count > 0 else { return [] }

        var out = [RoutePoint]()
        out.reserveCapacity(count)
        for index in 0..<count {
            let base = index * 32
            out.append(RoutePoint(
                latitude: Double(bitPattern: bytes.readUInt64(at: base)),
                longitude: Double(bitPattern: bytes.readUInt64(at: base + 8)),
                altitude: Double(Float(bitPattern: bytes.readUInt32(at: base + 16))),
                elapsed: TimeInterval(Float(bitPattern: bytes.readUInt32(at: base + 20))),
                speed: Double(Float(bitPattern: bytes.readUInt32(at: base + 24))),
                horizontalAccuracy: Double(Float(bitPattern: bytes.readUInt32(at: base + 28)))
            ))
        }
        return out
    }
}

// MARK: - Byte helpers

private extension Data {
    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendLE(_ value: UInt64) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendLE(_ value: Double) { appendLE(value.bitPattern) }
    mutating func appendLE(_ value: Float) { appendLE(value.bitPattern) }
}

private extension Array where Element == UInt8 {
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }
    func readUInt64(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(self[offset + index]) << (8 * UInt64(index))
        }
        return value
    }
}
