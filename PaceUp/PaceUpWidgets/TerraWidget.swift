//
//  TerraWidget.swift
//  Pace Up Widgets
//
//  The shape of everywhere the user has walked, on their Home Screen.
//
//  Like `SharedSnapshot.swift`, this carries a deliberate self-contained copy of
//  the snapshot type rather than sharing source with the app target. If
//  `TerraSnapshot` changes in the app, change it here too — the decoder returns
//  nil on mismatch and the widget falls back to its placeholder, so drift
//  degrades to a sample image rather than to a crash.
//
//  No MapKit, no tiles, no coordinates: the app hands over a 1-bit bitmap of at
//  most 64 × 64 and this draws it. That keeps the extension well inside its
//  memory budget and means the widget cannot leak a location even in principle.
//

import WidgetKit
import SwiftUI

// MARK: - Snapshot (mirror of the app's TerraSnapshot)

struct TerraWidgetSnapshot: Codable, Equatable, Sendable {
    var width: Int
    var height: Int
    var bits: Data
    var squareKilometres: Double
    var steps: Int
    var explorerStreak: Int
    var updatedAt: Date

    static let key = "terraSnapshot"

    var isEmpty: Bool { width == 0 || height == 0 || bits.isEmpty }

    func isSet(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        let bytesPerRow = (width + 7) / 8
        let index = y * bytesPerRow + (x / 8)
        guard index < bits.count else { return false }
        return bits[bits.startIndex + index] & (0x80 >> UInt8(x % 8)) != 0
    }

    static func load() -> TerraWidgetSnapshot? {
        guard let data = WidgetAppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TerraWidgetSnapshot.self, from: data)
    }

    /// A recognisable blob so the widget gallery shows something meaningful.
    static let placeholder: TerraWidgetSnapshot = {
        let w = 40, h = 40
        let bytesPerRow = (w + 7) / 8
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * h)
        func set(_ x: Int, _ y: Int) {
            guard x >= 0, x < w, y >= 0, y < h else { return }
            bytes[y * bytesPerRow + x / 8] |= (0x80 >> UInt8(x % 8))
        }
        // A few crossing streets and a loop — the shape a month of walking
        // around one neighbourhood actually makes.
        for x in 6..<34 { set(x, 20); set(x, 21) }
        for y in 8..<32 { set(16, y); set(17, y) }
        for t in 0..<60 {
            let a = Double(t) / 60 * 2 * .pi
            set(24 + Int(7 * cos(a)), 14 + Int(5 * sin(a)))
        }
        for i in 0..<14 { set(8 + i, 28 + i / 4) }
        return TerraWidgetSnapshot(
            width: w, height: h, bits: Data(bytes),
            squareKilometres: 3.84, steps: 412_060,
            explorerStreak: 6, updatedAt: .now
        )
    }()
}

// MARK: - Timeline

struct TerraEntry: TimelineEntry {
    let date: Date
    let snapshot: TerraWidgetSnapshot
    let isPlaceholder: Bool
}

struct TerraProvider: TimelineProvider {

    func placeholder(in context: Context) -> TerraEntry {
        TerraEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TerraEntry) -> Void) {
        let loaded = TerraWidgetSnapshot.load()
        completion(TerraEntry(date: .now, snapshot: loaded ?? .placeholder, isPlaceholder: loaded == nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TerraEntry>) -> Void) {
        let loaded = TerraWidgetSnapshot.load()
        let entry = TerraEntry(date: .now, snapshot: loaded ?? .placeholder, isPlaceholder: loaded == nil)

        // Terra only changes when an activity is saved, and the app reloads
        // timelines when that happens. This interval exists solely so a widget
        // on a phone whose owner never opens the app still refreshes eventually.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Rendering

/// Draws the 1-bit bitmap, fitted to the space with its aspect preserved.
struct TerraShapeView: View {
    var snapshot: TerraWidgetSnapshot
    var tint: Color = .paceWidgetLime

    var body: some View {
        Canvas { context, size in
            guard !snapshot.isEmpty else { return }

            let scale = min(size.width / Double(snapshot.width),
                            size.height / Double(snapshot.height))
            let drawnWidth = Double(snapshot.width) * scale
            let drawnHeight = Double(snapshot.height) * scale
            let originX = (size.width - drawnWidth) / 2
            let originY = (size.height - drawnHeight) / 2

            // Squares rather than dots: at this scale a grid of filled cells
            // reads as territory, where circles read as scattered pins.
            // Slightly oversized so neighbours touch and a street becomes a
            // line instead of a dotted one.
            let side = scale * 1.35

            for y in 0..<snapshot.height {
                for x in 0..<snapshot.width where snapshot.isSet(x: x, y: y) {
                    let rect = CGRect(
                        x: originX + Double(x) * scale - (side - scale) / 2,
                        y: originY + Double(y) * scale - (side - scale) / 2,
                        width: side,
                        height: side
                    )
                    context.fill(Path(rect), with: .color(tint))
                }
            }
        }
    }
}

struct SmallTerraView: View {
    var entry: TerraEntry

    var body: some View {
        ZStack {
            TerraShapeView(snapshot: entry.snapshot)
                .padding(10)
                .opacity(entry.isPlaceholder ? 0.35 : 1)

            VStack {
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(areaValue(entry.snapshot.squareKilometres))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("km²")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct MediumTerraView: View {
    var entry: TerraEntry

    var body: some View {
        HStack(spacing: 14) {
            TerraShapeView(snapshot: entry.snapshot)
                .frame(maxWidth: .infinity)
                .opacity(entry.isPlaceholder ? 0.35 : 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("TERRA")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Color.paceWidgetLime)

                TerraStat(value: areaValue(entry.snapshot.squareKilometres) + " km²",
                          caption: "uncovered")
                TerraStat(value: stepsValue(entry.snapshot.steps),
                          caption: "steps that did it")
                if entry.snapshot.explorerStreak > 0 {
                    TerraStat(value: "\(entry.snapshot.explorerStreak) day\(entry.snapshot.explorerStreak == 1 ? "" : "s")",
                              caption: "finding new ground")
                }
            }
            .frame(width: 130, alignment: .leading)
        }
    }
}

struct TerraStat: View {
    var value: String
    var caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

private func areaValue(_ km2: Double) -> String {
    String(format: km2 < 10 ? "%.2f" : "%.1f", km2)
}

private func stepsValue(_ steps: Int) -> String {
    if steps >= 1_000_000 { return String(format: "%.1fM", Double(steps) / 1_000_000) }
    if steps >= 10_000 { return "\(steps / 1_000)k" }
    return "\(steps)"
}

struct TerraWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TerraEntry

    var body: some View {
        switch family {
        case .systemMedium: MediumTerraView(entry: entry)
        default:            SmallTerraView(entry: entry)
        }
    }
}

// MARK: - Registration

struct TerraWidget: Widget {
    let kind = "PaceUpTerraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TerraProvider()) { entry in
            TerraWidgetView(entry: entry)
        }
        .configurationDisplayName("Terra")
        .description("The shape of everywhere you have walked.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension Color {
    /// Mirror of `Color.paceLime` in the app target.
    static let paceWidgetLime = Color(red: 0.800, green: 0.929, blue: 0.192)
}
