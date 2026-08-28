//
//  PaceUpWidgets.swift
//  Pace Up Widgets
//
//  Widgets render from the snapshot the app writes to shared defaults rather
//  than querying HealthKit themselves. HealthKit reads from an extension are
//  slow and often return nothing on the first timeline pass, which produces the
//  worst possible widget: a blank one.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StepEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isPlaceholder: Bool
}

struct StepProvider: TimelineProvider {

    func placeholder(in context: Context) -> StepEntry {
        StepEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? .placeholder
        completion(StepEntry(date: .now, snapshot: snapshot, isPlaceholder: WidgetSnapshot.load() == nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? .placeholder
        let entry = StepEntry(date: .now, snapshot: snapshot, isPlaceholder: false)

        // The app reloads timelines whenever it refreshes, so this interval is
        // only a floor for the case where the app is never opened.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct StepWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StepEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallStepView(snapshot: entry.snapshot)
        case .systemMedium: MediumStepView(snapshot: entry.snapshot)
        case .systemLarge:  LargeStepView(snapshot: entry.snapshot)
        default:            SmallStepView(snapshot: entry.snapshot)
        }
    }
}

struct SmallStepView: View {
    var snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("PACE UP", systemImage: "figure.walk")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.widgetLime)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.steps.formatted())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("steps")
                    .font(.caption2)
                    .foregroundStyle(.widgetSecondary)
            }

            ProgressView(value: snapshot.progress)
                .tint(.widgetLime)

            Spacer(minLength: 0)

            MiniBars(values: snapshot.weeklySteps, tint: .widgetLime)
                .frame(height: 22)
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetBackdrop() }
    }
}

struct MediumStepView: View {
    var snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(snapshot.steps.formatted()) / \(snapshot.goal.formatted())")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("\(snapshot.formattedDistance) · \(Int(snapshot.activeEnergy)) kcal")
                    .font(.caption)
                    .foregroundStyle(.widgetSecondary)

                ProgressView(value: snapshot.progress)
                    .tint(.widgetLime)

                if snapshot.currentStreak > 0 {
                    Label("\(snapshot.currentStreak) day streak", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.widgetLime)
                }
            }

            MiniBars(values: snapshot.weeklySteps, tint: .widgetLime)
                .frame(width: 110)
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetBackdrop() }
    }
}

struct LargeStepView: View {
    var snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("TODAY · PACE UP", systemImage: "figure.walk")
                .font(.caption2.bold())
                .tracking(1.1)
                .foregroundStyle(.widgetLime)
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.steps.formatted())
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("/ \(snapshot.goal.formatted())")
                    .font(.subheadline)
                    .foregroundStyle(.widgetSecondary)
                Spacer()
                if snapshot.currentStreak > 0 {
                    Label("\(snapshot.currentStreak)", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.widgetLime)
                }
            }

            ProgressView(value: snapshot.progress)
                .tint(.widgetLime)

            HStack(spacing: 18) {
                WidgetStat(value: snapshot.formattedDistance, caption: "distance")
                WidgetStat(value: "\(Int(snapshot.activeEnergy))", caption: "kcal")
                WidgetStat(value: formattedActive, caption: "active")
            }

            LabelledBars(
                values: snapshot.weeklySteps,
                labels: snapshot.weekdayInitials,
                goal: snapshot.goal
            )
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetBackdrop() }
    }

    private var formattedActive: String {
        let hours = snapshot.activeMinutes / 60
        let minutes = snapshot.activeMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

// MARK: - Pieces

struct WidgetBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("WidgetTrail")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                LinearGradient(
                    colors: [Color.black.opacity(0.72), Color.black.opacity(0.48), Color.black.opacity(0.28)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    colors: [Color.black.opacity(0.15), Color.black.opacity(0.52)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

struct WidgetStat: View {
    var value: String
    var caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(.widgetTertiary)
        }
    }
}

struct MiniBars: View {
    var values: [Int]
    var tint: Color

    private var maximum: Double { Double(max(values.max() ?? 1, 1)) }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Capsule()
                        .fill(index == values.count - 1 ? tint : tint.opacity(0.45))
                        .frame(height: max(3, geometry.size.height * (Double(value) / maximum)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct LabelledBars: View {
    var values: [Int]
    var labels: [String]
    var goal: Int

    private var maximum: Double { Double(max(values.max() ?? 1, goal, 1)) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        VStack {
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(Double(value) >= Double(goal) ? Color.widgetLime : Color.widgetLime.opacity(0.4))
                                .frame(height: max(3, geometry.size.height * (Double(value) / maximum)))
                        }
                    }
                    Text(labels.indices.contains(index) ? labels[index] : "")
                        .font(.system(size: 9))
                        .foregroundStyle(.widgetTertiary)
                }
            }
        }
        .frame(height: 64)
    }
}

// MARK: - Registration

struct StepWidget: Widget {
    let kind = "PaceUpStepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepProvider()) { entry in
            StepWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Your step count and progress toward today's goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct PaceUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepWidget()
    }
}
