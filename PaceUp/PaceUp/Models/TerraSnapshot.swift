//
//  TerraSnapshot.swift
//  Pace Up
//
//  What the widget gets to see of Terra.
//
//  The explored set can run to tens of thousands of cells and hundreds of
//  kilobytes. Handing that to a widget extension would be wrong twice over:
//  shared defaults are not a database, and a widget has a hard memory budget it
//  would spend decoding a set it only wants the silhouette of.
//
//  So the app rasterises the set once, on ingest, into a small 1-bit bitmap —
//  at most 64 × 64, so at most 512 bytes — and the widget draws that. The
//  result is the *shape* of where the user has been rather than a map of it:
//  no tiles, no MapKit in the extension, no coordinates leaving the app group.
//  At widget size that abstraction is not a compromise; a real map rendered at
//  158 points is unreadable, and the silhouette is the recognisable part.
//

import Foundation
import WidgetKit

struct TerraSnapshot: Codable, Equatable, Sendable {

    /// Bitmap columns (longitude) and rows (latitude), at most `maxDimension`.
    var width: Int
    var height: Int
    /// Row-major, one bit per pixel, each row padded to a whole byte.
    /// Row 0 is the northernmost.
    var bits: Data
    var squareKilometres: Double
    var steps: Int
    var explorerStreak: Int
    var updatedAt: Date

    static let maxDimension = 64
    static let key = "terraSnapshot"
    /// Must match `TerraWidget.kind` in the widget target.
    static let widgetKind = "PaceUpTerraWidget"

    var isEmpty: Bool { width == 0 || height == 0 || bits.isEmpty }

    /// Equality on everything the widget draws, ignoring `updatedAt`.
    func sameContent(as other: TerraSnapshot) -> Bool {
        width == other.width
            && height == other.height
            && bits == other.bits
            && steps == other.steps
            && explorerStreak == other.explorerStreak
            && abs(squareKilometres - other.squareKilometres) < 0.0001
    }

    func isSet(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        let bytesPerRow = (width + 7) / 8
        let index = y * bytesPerRow + (x / 8)
        guard index < bits.count else { return false }
        return bits[bits.startIndex + index] & (0x80 >> UInt8(x % 8)) != 0
    }

    // MARK: Writing

    @MainActor
    static func write(from state: ExplorationState) {
        guard let snapshot = make(from: state) else {
            clear()
            return
        }
        // Only rewrite and reload when the bitmap or the numbers actually
        // moved. Ingest runs on every appearance of the Journey tab and almost
        // always finds nothing new; asking WidgetKit to reload each time spends
        // the extension's refresh budget redrawing an identical image.
        //
        // The comparison has to ignore `updatedAt`, or every write differs from
        // the last by construction and the guard never fires.
        if let existing = AppGroup.defaults.data(forKey: key),
           let previous = try? JSONDecoder().decode(TerraSnapshot.self, from: existing),
           previous.sameContent(as: snapshot) {
            return
        }

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    @MainActor
    static func clear() {
        guard AppGroup.defaults.data(forKey: key) != nil else { return }
        AppGroup.defaults.removeObject(forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    static func make(from state: ExplorationState) -> TerraSnapshot? {
        guard !state.cells.isEmpty else { return nil }

        var minLat = Int32.max, maxLat = Int32.min
        var minLon = Int32.max, maxLon = Int32.min
        for cell in state.cells {
            minLat = min(minLat, cell.lat); maxLat = max(maxLat, cell.lat)
            minLon = min(minLon, cell.lon); maxLon = max(maxLon, cell.lon)
        }

        let latExtent = Int(maxLat - minLat) + 1
        let lonExtent = Int(maxLon - minLon) + 1

        // One scale for both axes, so a long thin city stays long and thin.
        // Within any one city the longitude step is effectively constant, so
        // treating the two index axes as square is accurate; it only skews for
        // someone whose history spans continents, where the silhouette is
        // impressionistic anyway.
        let scale = max(1, Int(ceil(Double(max(latExtent, lonExtent)) / Double(maxDimension))))
        let width = max(1, Int(ceil(Double(lonExtent) / Double(scale))))
        let height = max(1, Int(ceil(Double(latExtent) / Double(scale))))

        let bytesPerRow = (width + 7) / 8
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)

        for cell in state.cells {
            let column = Int(cell.lon - minLon) / scale
            // Flip: latitude increases north, bitmap rows increase downward.
            let row = height - 1 - Int(cell.lat - minLat) / scale
            guard column >= 0, column < width, row >= 0, row < height else { continue }
            bytes[row * bytesPerRow + (column / 8)] |= (0x80 >> UInt8(column % 8))
        }

        return TerraSnapshot(
            width: width,
            height: height,
            bits: Data(bytes),
            squareKilometres: ExplorationGrid.areaSquareKilometres(cellCount: state.cells.count),
            steps: Int(state.steps),
            explorerStreak: ExplorationGrid.explorerStreak(from: state.explorerDays),
            updatedAt: .now
        )
    }
}
