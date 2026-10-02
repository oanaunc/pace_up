//
//  MemoryLaneWidget.swift
//  Pace Up Widgets
//
//  Sealed capsules counting down, capsules waiting to be walked back to, and
//  "on this day" memories — on the Home Screen.
//

import WidgetKit
import SwiftUI

/// Mirror of `WaymarkWidgetSnapshot` in the app. Keep field names identical.
struct MemoryLaneSnapshot: Codable {
    static let key = "waymarkWidgetSnapshot"

    var totalWaymarks: Int
    var sealedCapsules: Int
    var capsulesWaiting: Int
    var nextCapsuleTitle: String?
    var nextCapsuleOpens: Date?
    var onThisDayTitle: String?
    var onThisDayYear: Int?
    var updatedAt: Date

    static func load() -> MemoryLaneSnapshot? {
        guard let data = WidgetAppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MemoryLaneSnapshot.self, from: data)
    }

    static let placeholder = MemoryLaneSnapshot(
        totalWaymarks: 23, sealedCapsules: 3, capsulesWaiting: 0,
        nextCapsuleTitle: "To me, next summer",
        nextCapsuleOpens: Calendar.current.date(byAdding: .day, value: 94, to: .now),
        onThisDayTitle: nil, onThisDayYear: nil, updatedAt: .now)
}

struct MemoryLaneEntry: TimelineEntry {
    var date: Date
    var snapshot: MemoryLaneSnapshot
}

struct MemoryLaneProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoryLaneEntry {
        MemoryLaneEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryLaneEntry) -> Void) {
        completion(MemoryLaneEntry(date: .now, snapshot: MemoryLaneSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryLaneEntry>) -> Void) {
        let snapshot = MemoryLaneSnapshot.load() ?? .placeholder
        // Countdowns are day-granular; refresh shortly after midnight.
        let tomorrow = Calendar.current.date(byAdding: .minute, value: 5,
                                             to: Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [MemoryLaneEntry(date: .now, snapshot: snapshot)], policy: .after(tomorrow)))
    }
}

struct MemoryLaneWidgetView: View {
    var entry: MemoryLaneEntry
    @Environment(\.widgetFamily) private var family

    private let lime = Color(red: 0.800, green: 0.929, blue: 0.192)
    private let violet = Color(red: 0.655, green: 0.545, blue: 0.980)
    private let amber = Color(red: 0.984, green: 0.749, blue: 0.141)

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(eyebrow, systemImage: icon)
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(headline)
                    .font(.system(size: family == .systemSmall ? 30 : 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            if family == .systemMedium {
                Image("WidgetCapsule")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110)
                    .frame(maxHeight: .infinity)
                    .clipShape(.rect(cornerRadius: 14))
            }
        }
        .containerBackground(for: .widget) { Color(red: 0.043, green: 0.051, blue: 0.043) }
    }

    private var s: MemoryLaneSnapshot { entry.snapshot }

    private var accent: Color {
        if s.onThisDayTitle != nil { return lime }
        if s.capsulesWaiting > 0 { return amber }
        return s.nextCapsuleOpens != nil ? violet : lime
    }

    private var icon: String {
        if s.onThisDayTitle != nil { return "sparkles" }
        if s.capsulesWaiting > 0 { return "envelope.open.fill" }
        return s.nextCapsuleOpens != nil ? "lock.fill" : "mappin.and.ellipse"
    }

    private var eyebrow: String {
        if let year = s.onThisDayYear, s.onThisDayTitle != nil { return "ON THIS DAY · \(String(year))" }
        if s.capsulesWaiting > 0 { return "READY TO OPEN" }
        return s.nextCapsuleOpens != nil ? "NEXT CAPSULE" : "WAYMARKS"
    }

    private var headline: String {
        if s.onThisDayTitle != nil { return "\(s.totalWaymarks)" }
        if s.capsulesWaiting > 0 { return "\(s.capsulesWaiting)" }
        if let opens = s.nextCapsuleOpens {
            let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date), to: Calendar.current.startOfDay(for: opens)).day ?? 0)
            return "\(days) days"
        }
        return "\(s.totalWaymarks)"
    }

    private var detail: String {
        if let title = s.onThisDayTitle { return title }
        if s.capsulesWaiting > 0 { return "Walk back to where you sealed \(s.capsulesWaiting == 1 ? "it" : "them")." }
        if s.nextCapsuleOpens != nil { return s.nextCapsuleTitle ?? "Sealed capsule" }
        return s.totalWaymarks == 0 ? "Leave a memory on your next walk." : "memories pinned to places"
    }
}

struct MemoryLaneWidget: Widget {
    let kind = "PaceUpMemoryLaneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoryLaneProvider()) { entry in
            MemoryLaneWidgetView(entry: entry)
        }
        .configurationDisplayName("Memory Lane")
        .description("Time capsules counting down, and memories from this day in past years.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
