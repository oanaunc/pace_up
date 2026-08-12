//
//  RoutePoint.swift
//  Pace Up
//
//  Compact binary encoding for GPS traces.
//
//  A one-hour run sampled at 1 Hz is 3,600 points. Modelling those as SwiftData
//  relationship objects makes list loading and map rendering unusable within
//  weeks of real use, so routes are stored as a single opaque `Data` blob on
//  `ActivityDetail` and decoded only when a map or chart is actually shown.
//
//  Layout (all little-endian):
//
//      Header  : magic "PUR1" (4 bytes) | count UInt32 (4 bytes)
//      Point   : lat Double (8) | lon Double (8) | altitude Float (4)
//                | t Float (4) | speed Float (4) | hAcc Float (4)   = 32 bytes
//
//  `t` is seconds elapsed since the activity's start date, which keeps the
//  field inside Float precision for any realistic activity length.
//

import Foundation
import CoreLocation

struct RoutePoint: Equatable, Sendable {
    /// Degrees.
    var latitude: Double
    /// Degrees.
    var longitude: Double
    /// Metres above sea level.
    var altitude: Double
    /// Seconds since the activity started.
    var elapsed: TimeInterval
    /// Metres per second as reported by Core Location. Negative means unknown.
    var speed: Double
    /// Horizontal accuracy in metres. Negative means invalid.
    var horizontalAccuracy: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double,
         longitude: Double,
         altitude: Double,
         elapsed: TimeInterval,
         speed: Double,
         horizontalAccuracy: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.elapsed = elapsed
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }

    init(location: CLLocation, startDate: Date) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.elapsed = location.timestamp.timeIntervalSince(startDate)
        self.speed = location.speed
        self.horizontalAccuracy = location.horizontalAccuracy
    }
}

enum RouteCodec {

    static let magic: [UInt8] = [0x50, 0x55, 0x52, 0x31] // "PUR1"
    static let pointStride = 32
    static let headerStride = 8

    // MARK: Encoding

    static func encode(_ points: [RoutePoint]) -> Data {
        var data = Data(capacity: headerStride + points.count * pointStride)
        data.append(contentsOf: magic)
        data.appendLE(UInt32(points.count))
        for point in points {
            data.appendLE(point.latitude)
            data.appendLE(point.longitude)
            data.appendLE(Float(point.altitude))
            data.appendLE(Float(point.elapsed))
            data.appendLE(Float(point.speed))
            data.appendLE(Float(point.horizontalAccuracy))
        }
        return data
    }

    // MARK: Decoding

    static func decode(_ data: Data?) -> [RoutePoint] {
        guard let data, data.count >= headerStride else { return [] }
        let bytes = [UInt8](data)
        guard Array(bytes[0..<4]) == magic else { return [] }

        let count = Int(UInt32(littleEndian: bytes.readUInt32(at: 4)))
        let available = (bytes.count - headerStride) / pointStride
        let usable = min(count, available)
        guard usable > 0 else { return [] }

        var result = [RoutePoint]()
        result.reserveCapacity(usable)

        for index in 0..<usable {
            let base = headerStride + index * pointStride
            let lat = Double(bitPattern: bytes.readUInt64(at: base))
            let lon = Double(bitPattern: bytes.readUInt64(at: base + 8))
            let alt = Float(bitPattern: bytes.readUInt32(at: base + 16))
            let t = Float(bitPattern: bytes.readUInt32(at: base + 20))
            let spd = Float(bitPattern: bytes.readUInt32(at: base + 24))
            let acc = Float(bitPattern: bytes.readUInt32(at: base + 28))
            result.append(RoutePoint(latitude: lat,
                                     longitude: lon,
                                     altitude: Double(alt),
                                     elapsed: TimeInterval(t),
                                     speed: Double(spd),
                                     horizontalAccuracy: Double(acc)))
        }
        return result
    }

    /// Number of points in a blob without decoding it.
    static func count(in data: Data?) -> Int {
        guard let data, data.count >= headerStride else { return 0 }
        let bytes = [UInt8](data)
        guard Array(bytes[0..<4]) == magic else { return 0 }
        return Int(UInt32(littleEndian: bytes.readUInt32(at: 4)))
    }

    // MARK: Simplification

    /// Ramer–Douglas–Peucker simplification down to at most `limit` points.
    ///
    /// Used to build the permanent list thumbnail: a ~60 point trace is around
    /// 2 KB, small enough to survive the 30-day purge so the activity list keeps
    /// its route glyphs forever.
    static func simplified(_ points: [RoutePoint], limit: Int = 60) -> [RoutePoint] {
        guard points.count > limit, limit >= 2 else { return points }

        // Binary search an epsilon that lands near the target point count.
        var low = 0.0
        var high = 0.01 // ~1 km in degrees
        var best = decimate(points, every: max(1, points.count / limit))

        for _ in 0..<18 {
            let mid = (low + high) / 2
            let candidate = rdp(points, epsilon: mid)
            if candidate.count > limit {
                low = mid
            } else {
                best = candidate
                high = mid
            }
        }
        return best.count <= limit ? best : decimate(points, every: max(1, points.count / limit))
    }

    private static func decimate(_ points: [RoutePoint], every n: Int) -> [RoutePoint] {
        guard n > 1 else { return points }
        var out = [RoutePoint]()
        for (index, point) in points.enumerated() where index % n == 0 {
            out.append(point)
        }
        if let last = points.last, out.last != last { out.append(last) }
        return out
    }

    private static func rdp(_ points: [RoutePoint], epsilon: Double) -> [RoutePoint] {
        guard points.count > 2 else { return points }

        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true

        var stack: [(Int, Int)] = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }
            var maxDistance = 0.0
            var maxIndex = start
            for index in (start + 1)..<end {
                let distance = perpendicularDistance(points[index], points[start], points[end])
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = index
                }
            }
            if maxDistance > epsilon {
                keep[maxIndex] = true
                stack.append((start, maxIndex))
                stack.append((maxIndex, end))
            }
        }
        return points.enumerated().compactMap { keep[$0.offset] ? $0.element : nil }
    }

    private static func perpendicularDistance(_ point: RoutePoint,
                                              _ lineStart: RoutePoint,
                                              _ lineEnd: RoutePoint) -> Double {
        let x = point.longitude, y = point.latitude
        let x1 = lineStart.longitude, y1 = lineStart.latitude
        let x2 = lineEnd.longitude, y2 = lineEnd.latitude

        let dx = x2 - x1
        let dy = y2 - y1
        if dx == 0 && dy == 0 {
            return ((x - x1) * (x - x1) + (y - y1) * (y - y1)).squareRoot()
        }
        let numerator = abs(dy * x - dx * y + x2 * y1 - y2 * x1)
        let denominator = (dx * dx + dy * dy).squareRoot()
        return numerator / denominator
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
