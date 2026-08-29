//
//  ExplorationGrid.swift
//  Pace Up
//
//  The world, quantised into 100-metre squares.
//
//  Terra shows a dark map that only clears where the user has actually been.
//  Storing that as raw GPS would mean re-decoding every route on every pan, so
//  instead each route is folded once into a set of grid cells and only the set
//  is kept. A user with 500 recorded activities lands somewhere around 3,000
//  distinct cells — a 24 KB file, and a set membership test per cell rather
//  than a geometry test per point.
//
//  ── Why cells are built from `thumbnailRoute` ─────────────────────────────
//
//  `ActivityDetail` is purgeable; `Activity.thumbnailRoute` is not. Folding the
//  60-point thumbnail means the map a user has uncovered never shrinks when the
//  30-day cleanup runs. Losing the fine GPS trace costs a little precision at
//  the edges of a corridor and nothing at all in coverage. Building this on the
//  full trace instead would have made "explored area" silently shrink over
//  time, which is precisely the failure the split schema exists to avoid.
//

import Foundation
import CoreLocation

/// One quantised square of the world.
///
/// Latitude is divided into fixed bands; longitude is divided into steps that
/// widen towards the poles so a cell stays roughly square in metres rather than
/// collapsing into a sliver at high latitude.
struct ExplorationCell: Hashable, Sendable {
    var lat: Int32
    var lon: Int32
}

enum ExplorationGrid {

    /// Latitude span of one cell. 0.0009° ≈ 100 m everywhere.
    static let latStep: Double = 0.0009

    /// Cell edge in metres, used for the area statistic.
    static let cellEdgeMeters: Double = 100

    /// Distance between interpolated samples when walking a route.
    ///
    /// Must be comfortably below `cellEdgeMeters`, or a straight segment could
    /// step over a cell and leave a hole in the middle of a road the user
    /// definitely walked down. 25 m gives four samples per cell crossing.
    static let sampleStrideMeters: Double = 25

    /// Radius drawn per cell when rendering.
    ///
    /// Diagonally adjacent cell centres are 141 m apart, so discs must reach
    /// 71 m to close a diagonal seam. 75 m clears that with a little to spare
    /// and no more: every metre beyond it widens the cleared corridor on screen
    /// past the 100 m the area figure actually claims, and a map that looks
    /// more explored than the number underneath it is a map that lies.
    static let renderRadiusMeters: Double = 75

    /// Longitude step for a given latitude band.
    ///
    /// Clamped at 0.02 (≈ 88.9°) so the step stays finite at the poles; without
    /// the clamp `cos` reaches zero and the index calculation diverges.
    static func lonStep(forLatitudeIndex latIndex: Int32) -> Double {
        let latitude = Double(latIndex) * latStep
        let scale = max(cos(latitude * .pi / 180), 0.02)
        return latStep / scale
    }

    static func cell(for coordinate: CLLocationCoordinate2D) -> ExplorationCell {
        let latIndex = Int32((coordinate.latitude / latStep).rounded(.down))
        let step = lonStep(forLatitudeIndex: latIndex)
        let lonIndex = Int32((coordinate.longitude / step).rounded(.down))
        return ExplorationCell(lat: latIndex, lon: lonIndex)
    }

    static func center(of cell: ExplorationCell) -> CLLocationCoordinate2D {
        let latitude = (Double(cell.lat) + 0.5) * latStep
        let step = lonStep(forLatitudeIndex: cell.lat)
        let longitude = (Double(cell.lon) + 0.5) * step
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Square kilometres represented by a set of cells.
    static func areaSquareKilometres(cellCount: Int) -> Double {
        let squareMetres = Double(cellCount) * cellEdgeMeters * cellEdgeMeters
        return squareMetres / 1_000_000
    }

    // MARK: Level of detail

    /// Snaps a cell to the origin of a `factor × factor` block.
    ///
    /// Uses floored division rather than Swift's `/`, which truncates towards
    /// zero and would make blocks straddle the equator and prime meridian
    /// asymmetrically — a visible seam through Greenwich and the Gulf of
    /// Guinea, and a duplicated row of blocks either side of it.
    static func block(_ cell: ExplorationCell, factor: Int32) -> ExplorationCell {
        guard factor > 1 else { return cell }
        return ExplorationCell(lat: floorDiv(cell.lat, factor) * factor,
                               lon: floorDiv(cell.lon, factor) * factor)
    }

    /// Centre of a `factor × factor` block whose origin is `cell`.
    static func center(ofBlock cell: ExplorationCell, factor: Int32) -> CLLocationCoordinate2D {
        guard factor > 1 else { return center(of: cell) }
        let half = Double(factor) / 2
        let latitude = (Double(cell.lat) + half) * latStep
        let step = lonStep(forLatitudeIndex: cell.lat)
        let longitude = (Double(cell.lon) + half) * step
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func floorDiv(_ value: Int32, _ divisor: Int32) -> Int32 {
        let quotient = value / divisor
        return (value % divisor != 0 && (value < 0) != (divisor < 0)) ? quotient - 1 : quotient
    }

    // MARK: Folding a route into cells

    /// Every cell a polyline passes through, interpolating along each segment
    /// so no cell is skipped between two widely spaced points.
    ///
    /// Thumbnail routes are RDP-simplified to 60 points, which on a 10 km run
    /// puts roughly 170 m between neighbours. Walking the straight line between
    /// them is an approximation of the true path, but the error is bounded by
    /// the simplification epsilon and is invisible at any zoom where fog is
    /// legible.
    static func cells(along coordinates: [CLLocationCoordinate2D]) -> Set<ExplorationCell> {
        guard !coordinates.isEmpty else { return [] }

        var result = Set<ExplorationCell>()
        result.reserveCapacity(coordinates.count * 8)

        guard coordinates.count > 1 else {
            result.insert(cell(for: coordinates[0]))
            return result
        }

        for index in 0..<(coordinates.count - 1) {
            let start = coordinates[index]
            let end = coordinates[index + 1]

            result.insert(cell(for: start))

            let span = metres(from: start, to: end)
            guard span > sampleStrideMeters else { continue }

            // A GPS gap this large is a pause, a tunnel, or a bad fix rather
            // than a walk. Interpolating across it would draw a clear corridor
            // through streets nobody visited, so only the endpoints are kept.
            guard span < 2_000 else { continue }

            let steps = Int((span / sampleStrideMeters).rounded(.up))
            guard steps > 1 else { continue }

            for step in 1..<steps {
                let t = Double(step) / Double(steps)
                let interpolated = CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * t,
                    longitude: start.longitude + (end.longitude - start.longitude) * t
                )
                result.insert(cell(for: interpolated))
            }
        }

        if let last = coordinates.last {
            result.insert(cell(for: last))
        }
        return result
    }

    /// Great-circle distance in metres.
    ///
    /// `RouteMath.haversine` takes `RoutePoint`, and everything here works in
    /// bare coordinates, so this repeats the formula rather than allocating
    /// throwaway points for every interpolation step.
    static func metres(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, h.squareRoot()))
    }
}

// MARK: - Persistence format

/// Everything Terra persists.
struct ExplorationState {
    var cells: Set<ExplorationCell> = []
    var ingested: Set<UUID> = []
    /// Days on which new ground was uncovered, as days since the epoch.
    /// Drives the explorer streak.
    var explorerDays: Set<Int32> = []
    /// Steps taken on the activities folded into `cells`.
    var steps: UInt64 = 0
}

/// Binary codec for the explored state.
///
/// Layout (all little-endian):
///
///     Header : magic "PUX2" (4) | cellCount UInt32 (4) | idCount UInt32 (4)
///              | dayCount UInt32 (4) | steps UInt64 (8)             = 24 bytes
///     Cell   : lat Int32 (4) | lon Int32 (4)                        = 8 bytes
///     ID     : raw UUID bytes                                      = 16 bytes
///     Day    : Int32 days since epoch                               = 4 bytes
///
/// Cells are written in sorted order. Nothing depends on the ordering, but it
/// makes the file byte-stable between runs, which keeps iCloud backups from
/// re-uploading an unchanged blob every time the app is opened.
///
/// Steps and days live in the same file as the cells on purpose. Deriving the
/// step total from the database at display time would be simpler, but the two
/// numbers are shown as one sentence — "412,000 steps uncovered 3.8 km²" — and
/// deleting an activity would then drop the steps while the area, which is
/// never un-walked, stayed put. A pair that can contradict itself is worse than
/// a few extra bytes.
enum ExplorationCodec {

    static let magic: [UInt8] = [0x50, 0x55, 0x58, 0x32] // "PUX2"
    static let headerStride = 24
    static let cellStride = 8
    static let idStride = 16
    static let dayStride = 4

    static func encode(_ state: ExplorationState) -> Data {
        let sortedCells = state.cells.sorted {
            $0.lat == $1.lat ? $0.lon < $1.lon : $0.lat < $1.lat
        }
        let sortedIDs = state.ingested.sorted { $0.uuidString < $1.uuidString }
        let sortedDays = state.explorerDays.sorted()

        var data = Data(capacity: headerStride
                        + sortedCells.count * cellStride
                        + sortedIDs.count * idStride
                        + sortedDays.count * dayStride)
        data.append(contentsOf: magic)
        data.appendLE(UInt32(sortedCells.count))
        data.appendLE(UInt32(sortedIDs.count))
        data.appendLE(UInt32(sortedDays.count))
        data.appendLE(state.steps)

        for cell in sortedCells {
            data.appendLE(UInt32(bitPattern: cell.lat))
            data.appendLE(UInt32(bitPattern: cell.lon))
        }
        for id in sortedIDs {
            withUnsafeBytes(of: id.uuid) { data.append(contentsOf: $0) }
        }
        for day in sortedDays {
            data.appendLE(UInt32(bitPattern: day))
        }
        return data
    }

    static func decode(_ data: Data?) -> ExplorationState {
        guard let data, data.count >= headerStride else { return ExplorationState() }
        let bytes = [UInt8](data)
        guard Array(bytes[0..<4]) == magic else { return ExplorationState() }

        var state = ExplorationState()
        state.steps = bytes.readUInt64LE(at: 16)

        let declaredCells = Int(bytes.readUInt32LE(at: 4))
        let declaredIDs = Int(bytes.readUInt32LE(at: 8))
        let declaredDays = Int(bytes.readUInt32LE(at: 12))

        // Every section is clamped to what is actually present, and a section
        // is only read at all if every section before it was complete.
        //
        // The clamp alone is not enough: sections are laid out back to back, so
        // in a file truncated mid-cells the bytes where the days *would* start
        // are still cell data. Reading them yields a plausible-looking Int32
        // and invents an explorer day the user never had. Truncation must lose
        // the tail, not corrupt it.
        var cursor = headerStride
        let usableCells = min(declaredCells, max(0, bytes.count - cursor) / cellStride)
        let cellsComplete = usableCells == declaredCells
        state.cells.reserveCapacity(usableCells)
        for index in 0..<usableCells {
            let base = cursor + index * cellStride
            state.cells.insert(ExplorationCell(
                lat: Int32(bitPattern: bytes.readUInt32LE(at: base)),
                lon: Int32(bitPattern: bytes.readUInt32LE(at: base + 4))
            ))
        }
        cursor += usableCells * cellStride

        let usableIDs = cellsComplete
            ? min(declaredIDs, max(0, bytes.count - cursor) / idStride)
            : 0
        state.ingested.reserveCapacity(usableIDs)
        for index in 0..<usableIDs {
            let base = cursor + index * idStride
            var raw = uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            withUnsafeMutableBytes(of: &raw) { buffer in
                for offset in 0..<idStride {
                    buffer[offset] = bytes[base + offset]
                }
            }
            state.ingested.insert(UUID(uuid: raw))
        }
        cursor += usableIDs * idStride

        let idsComplete = cellsComplete && usableIDs == declaredIDs
        let usableDays = idsComplete
            ? min(declaredDays, max(0, bytes.count - cursor) / dayStride)
            : 0
        state.explorerDays.reserveCapacity(usableDays)
        for index in 0..<usableDays {
            state.explorerDays.insert(Int32(bitPattern: bytes.readUInt32LE(at: cursor + index * dayStride)))
        }

        return state
    }
}

// MARK: - Little-endian helpers

private extension Data {
    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendLE(_ value: UInt64) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}

private extension Array where Element == UInt8 {
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }

    func readUInt64LE(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(self[offset + index]) << (8 * UInt64(index))
        }
        return value
    }
}

// MARK: - Frontier

/// Somewhere worth going next.
struct FrontierSuggestion: Equatable {
    var coordinate: CLLocationCoordinate2D
    var distanceMeters: Double
    var bearingDegrees: Double
    /// Unexplored cells in the block around it, out of `Frontier.blockArea`.
    var openness: Int

    var compassPoint: String {
        let points = ["north", "north-east", "east", "south-east",
                      "south", "south-west", "west", "north-west"]
        let index = Int(((bearingDegrees + 22.5) / 45).rounded(.down)) % 8
        return points[(index + 8) % 8]
    }

    /// Rough area a loop out to this frontier and back would open up.
    /// Deliberately conservative: it assumes a single 100 m-wide corridor
    /// through the block rather than a thorough sweep of it.
    var estimatedNewSquareKilometres: Double {
        ExplorationGrid.areaSquareKilometres(cellCount: min(openness, Frontier.blockSide * 2))
    }

    static func == (a: FrontierSuggestion, b: FrontierSuggestion) -> Bool {
        a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
            && a.distanceMeters == b.distanceMeters
    }
}

enum Frontier {
    /// Side of the neighbourhood used to judge how much a frontier opens up.
    static let blockSide = 5
    static var blockArea: Int { blockSide * blockSide }
    /// A frontier this hemmed in is a gap in the middle of familiar streets,
    /// not new territory. Suggesting those would send people to fill in the
    /// one square they skipped behind the supermarket.
    static let minimumOpenness = 18
    /// Beyond this, a suggestion stops being something you can act on today.
    static let maximumDistanceMeters: Double = 8_000
    /// Below this, the frontier is effectively where you already are.
    static let minimumDistanceMeters: Double = 300
}

extension ExplorationGrid {

    /// The nearest unexplored ground that would actually open something up.
    ///
    /// A frontier cell is an unexplored cell orthogonally adjacent to an
    /// explored one — the edge of what the user knows. Most of those are
    /// uninteresting: the far side of a street they have walked, or a corner
    /// they cut. So each candidate is scored by how much of the 5 × 5 block
    /// around it is also unexplored, and only genuinely open ones are offered.
    ///
    /// Cost is O(explored cells × 4) to find candidates plus O(candidates × 25)
    /// to score them, with candidates bounded by distance first. At a realistic
    /// 12,000 cells that is tens of thousands of set lookups — fine to run when
    /// a view appears, not something to put in a pan gesture.
    static func nearestFrontier(from origin: CLLocationCoordinate2D,
                                cells: Set<ExplorationCell>) -> FrontierSuggestion? {
        guard cells.count > 4 else { return nil }

        var best: FrontierSuggestion?
        var considered = Set<ExplorationCell>()

        for cell in cells {
            for neighbour in [ExplorationCell(lat: cell.lat + 1, lon: cell.lon),
                              ExplorationCell(lat: cell.lat - 1, lon: cell.lon),
                              ExplorationCell(lat: cell.lat, lon: cell.lon + 1),
                              ExplorationCell(lat: cell.lat, lon: cell.lon - 1)] {

                guard !cells.contains(neighbour), considered.insert(neighbour).inserted else { continue }

                let coordinate = center(of: neighbour)
                let distance = metres(from: origin, to: coordinate)
                guard distance >= Frontier.minimumDistanceMeters,
                      distance <= Frontier.maximumDistanceMeters else { continue }
                // Nothing further away can win, so skip the scoring entirely.
                guard distance < (best?.distanceMeters ?? .greatestFiniteMagnitude) else { continue }

                let openness = self.openness(around: neighbour, cells: cells)
                guard openness >= Frontier.minimumOpenness else { continue }

                best = FrontierSuggestion(
                    coordinate: coordinate,
                    distanceMeters: distance,
                    bearingDegrees: bearing(from: origin, to: coordinate),
                    openness: openness
                )
            }
        }
        return best
    }

    /// How many cells in the block around `cell` are unexplored.
    static func openness(around cell: ExplorationCell, cells: Set<ExplorationCell>) -> Int {
        let reach = Int32(Frontier.blockSide / 2)
        var open = 0
        for dLat in -reach...reach {
            for dLon in -reach...reach {
                if !cells.contains(ExplorationCell(lat: cell.lat + dLat, lon: cell.lon + dLon)) {
                    open += 1
                }
            }
        }
        return open
    }

    /// Initial great-circle bearing in degrees, 0 = north, clockwise.
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}

// MARK: - Day keys

extension ExplorationGrid {

    /// Days since the epoch, in the user's own calendar.
    ///
    /// The streak is about the days a person experienced, so it uses their
    /// local midnight rather than UTC. Travelling across a date line can
    /// therefore lengthen or shorten a streak by a day; that is the same
    /// behaviour as every other streak in the app.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> Int32 {
        let start = calendar.startOfDay(for: date)
        return Int32(floor(start.timeIntervalSince1970 / 86_400))
    }

    /// Consecutive days of new ground, counting back from today.
    ///
    /// A streak stays alive on a day the user has not yet been out: it is
    /// counted from yesterday if today has nothing, and only breaks once a full
    /// day has passed with no new ground. Ending it at midnight would mean
    /// every user watches their streak die each morning.
    static func explorerStreak(from days: Set<Int32>, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard !days.isEmpty else { return 0 }
        let today = dayKey(for: now, calendar: calendar)

        var cursor: Int32
        if days.contains(today) {
            cursor = today
        } else if days.contains(today - 1) {
            cursor = today - 1
        } else {
            return 0
        }

        var length = 0
        while days.contains(cursor) {
            length += 1
            cursor -= 1
        }
        return length
    }
}
