//
//  Samples.swift
//  Pace Up
//
//  Small fixed-layout codecs for the scalar time series recorded alongside a
//  route: heart rate, and per-kilometre splits.
//

import Foundation

/// A single heart-rate reading.
struct HeartRateSample: Equatable, Sendable, Codable {
    /// Seconds since the activity started.
    var elapsed: TimeInterval
    /// Beats per minute.
    var bpm: Double
}

/// One completed distance split (a kilometre, or a mile when the user prefers
/// imperial units — the unit is recorded on the activity, not per split).
struct Split: Equatable, Sendable, Codable, Identifiable {
    /// 1-based index of the split.
    var index: Int
    /// Distance covered in this split, in metres. The final split is partial.
    var distance: Double
    /// Seconds spent in this split.
    var duration: TimeInterval
    /// Elevation change over the split, in metres.
    var elevationDelta: Double

    var id: Int { index }

    /// Seconds per kilometre for this split.
    var paceSecondsPerKm: Double {
        guard distance > 0 else { return 0 }
        return duration / (distance / 1000)
    }

    /// True when the split did not reach a full unit and should be labelled
    /// with its fractional distance instead of its index.
    func isPartial(unitDistance: Double) -> Bool {
        distance < unitDistance - 1
    }
}

enum SampleCodec {

    // MARK: Heart rate — "PUH1" | count UInt32 | (t Float, bpm Float) × count

    private static let heartMagic: [UInt8] = [0x50, 0x55, 0x48, 0x31]

    static func encodeHeartRate(_ samples: [HeartRateSample]) -> Data {
        var data = Data(capacity: 8 + samples.count * 8)
        data.append(contentsOf: heartMagic)
        data.appendLE(UInt32(samples.count))
        for sample in samples {
            data.appendLE(Float(sample.elapsed))
            data.appendLE(Float(sample.bpm))
        }
        return data
    }

    static func decodeHeartRate(_ data: Data?) -> [HeartRateSample] {
        guard let data, data.count >= 8 else { return [] }
        let bytes = [UInt8](data)
        guard Array(bytes[0..<4]) == heartMagic else { return [] }
        let declared = Int(bytes.readUInt32(at: 4))
        let usable = min(declared, (bytes.count - 8) / 8)
        guard usable > 0 else { return [] }

        var out = [HeartRateSample]()
        out.reserveCapacity(usable)
        for index in 0..<usable {
            let base = 8 + index * 8
            let t = Float(bitPattern: bytes.readUInt32(at: base))
            let bpm = Float(bitPattern: bytes.readUInt32(at: base + 4))
            out.append(HeartRateSample(elapsed: TimeInterval(t), bpm: Double(bpm)))
        }
        return out
    }

    // MARK: Splits — JSON

    /// Splits are tiny (a marathon is 42 entries) and are stored on the
    /// permanent activity summary rather than the purgeable detail, so the
    /// Splits tab keeps working after the 30-day route purge. JSON is used here
    /// deliberately: readability matters more than bytes at this size.
    static func encodeSplits(_ splits: [Split]) -> Data {
        (try? JSONEncoder().encode(splits)) ?? Data()
    }

    static func decodeSplits(_ data: Data?) -> [Split] {
        guard let data, !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([Split].self, from: data)) ?? []
    }
}

// MARK: - Little-endian helpers

private extension Data {
    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
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
}
