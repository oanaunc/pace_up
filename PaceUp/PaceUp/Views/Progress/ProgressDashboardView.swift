//
//  ProgressDashboardView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

struct ProgressDashboardView: View {

    enum Metric: String, CaseIterable, Identifiable {
        case steps, distance, activeTime
        var id: String { rawValue }
        var title: String {
            switch self {
            case .steps:      return String(localized: "Steps")
            case .distance:   return String(localized: "Distance")
            case .activeTime: return String(localized: "Active Time")
            }
        }
    }

    @Environment(HealthKitManager.self) private var health
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query(sort: \Activity.startDate, order: .reverse)
    private var activities: [Activity]

    @State private var metric: Metric = .steps

    private var stats: StatsService { StatsService(context: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaceSpacing.l) {
                    pageIntro
                    PillPicker(options: Metric.allCases, title: \.title, selection: $metric)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    summaryCard
                    progressImageCard
                    streakCard
                    weekCard
                    quickLinks
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background { PacePageBackground(image: "ProgressSummit", imageHeight: 460, opacity: 0.40) }
            .navigationTitle(String(localized: "Progress"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task { await health.refreshToday() }
        }
    }

    // MARK: Cards

    private var pageIntro: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("YOUR MOMENTUM").font(.caption.bold()).tracking(1.8).foregroundStyle(.paceLime)
                Text(progressHeadline).font(.title2.bold())
                Text("A clear view of the work that is adding up.").font(.subheadline).foregroundStyle(.paceTextSecondary)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("\(currentStreak)").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.paceLime)
                Text("DAY STREAK").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(.paceTextTertiary)
            }
        }.padding(.top, PaceSpacing.s)
    }

    private var progressHeadline: String {
        if currentStreak >= 7 { return "Consistency is your advantage" }
        if currentStreak > 0 { return "Keep your rhythm alive" }
        return "A fresh week starts here"
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title.uppercased()).font(.caption2.bold()).tracking(1.4).foregroundStyle(.paceTextTertiary)
                    Text(headlineValue)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                    Text(headlineCaption).font(.caption).foregroundStyle(.paceTextSecondary)
                }
                Spacer()
                if let change = comparison.percentChange {
                Label(
                    String(localized: "\(change >= 0 ? "+" : "")\(Int(change.rounded()))%"),
                    systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right"
                )
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background((change >= 0 ? Color.paceLime : Color.paceAmber).opacity(0.12), in: .capsule)
                .foregroundStyle(change >= 0 ? Color.paceLime : Color.paceAmber)
                }
            }

            WeeklyBarChart(
                bars: bars,
                goal: metric == .steps ? Double(settings.dailyStepGoal) : 0,
                usesMomentumGradient: metric == .steps
            )
            .padding(.top, PaceSpacing.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    private var streakCard: some View {
        HStack(spacing: PaceSpacing.m) {
            ZStack { Circle().fill(Color.paceOrange.opacity(0.14)); Image(systemName: "flame.fill").foregroundStyle(.paceOrange) }.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(currentStreak == 0 ? "Start a streak today" : "\(currentStreak)-day movement streak").font(.headline)
                Text(streakMessage).font(.caption).foregroundStyle(.paceTextSecondary)
            }
            Spacer()
            MiniRing(progress: min(Double(currentStreak) / 7, 1), lineWidth: 5).frame(width: 42, height: 42)
        }.padding(PaceSpacing.l).paceGlassCard(cornerRadius: PaceRadius.tile)
    }

    private var progressImageCard: some View {
        EditorialImageCard(
            image: "ProgressTrail",
            eyebrow: "The long view",
            title: currentStreak > 0 ? "Your rhythm is becoming a trail" : "Every trail begins with one mark",
            subtitle: "Progress is the pattern you create, not a perfect number on one day."
        )
    }

    private var streakMessage: String { currentStreak >= 7 ? "A full week of showing up." : "\(max(0, 7 - currentStreak)) days to a full week." }

    private var weekCard: some View {
        HStack(spacing: PaceSpacing.s) {
            ProgressMetricTile(symbol: "shoeprints.fill", value: PaceFormat.steps(weeklyStepTotal), label: "week steps", tint: .paceLime)
            ProgressMetricTile(symbol: "chart.bar.fill", value: PaceFormat.steps(dailyAverage), label: "daily average", tint: .paceCyan)
            ProgressMetricTile(symbol: "figure.walk", value: "\(weekActivityCount)", label: "sessions", tint: .paceViolet)
        }
    }

    private var weekActivityCount: Int { activities.filter { Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.contains($0.startDate) ?? false }.count }

    private var quickLinks: some View {
        VStack(spacing: PaceSpacing.s) {
            NavigationLink {
                AchievementsView()
            } label: {
                LinkRow(symbol: "rosette", title: String(localized: "Achievements"))
            }
            .buttonStyle(.plain)

            NavigationLink {
                PersonalRecordsView()
            } label: {
                LinkRow(symbol: "trophy", title: String(localized: "Personal Records"))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Data

    private var bars: [WeeklyBarChart.Bar] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols

        return health.weeklySteps.enumerated().map { index, day in
            let weekdayIndex = calendar.component(.weekday, from: day.date) - 1
            let value: Double
            switch metric {
            case .steps:
                value = day.value
            case .distance:
                value = activities
                    .filter { calendar.isDate($0.startDate, inSameDayAs: day.date) }
                    .reduce(0) { $0 + $1.distance } / 1000
            case .activeTime:
                value = activities
                    .filter { calendar.isDate($0.startDate, inSameDayAs: day.date) }
                    .reduce(0) { $0 + $1.movingDuration } / 60
            }

            return WeeklyBarChart.Bar(
                id: index,
                label: symbols.indices.contains(weekdayIndex) ? symbols[weekdayIndex] : "",
                value: value,
                isToday: calendar.isDateInToday(day.date)
            )
        }
    }

    private var weeklyStepTotal: Int {
        Int(health.weeklySteps.reduce(0) { $0 + $1.value })
    }

    private var dailyAverage: Int {
        guard !health.weeklySteps.isEmpty else { return 0 }
        return weeklyStepTotal / health.weeklySteps.count
    }

    private var currentStreak: Int {
        stats.currentStreak(
            dailyStepGoal: settings.dailyStepGoal,
            stepsByDay: health.weeklySteps
        )
    }

    private var comparison: StatsService.WeeklyComparison {
        switch metric {
        case .distance, .activeTime:
            return stats.weeklyDistanceComparison()
        case .steps:
            // Only seven days of step history are loaded, so a week-over-week
            // step comparison would be comparing against nothing. Fall back to
            // the distance comparison, which comes from stored activities.
            return stats.weeklyDistanceComparison()
        }
    }

    private var headlineValue: String {
        switch metric {
        case .steps:
            return PaceFormat.steps(weeklyStepTotal)
        case .distance:
            return PaceFormat.distance(comparison.thisWeek, units: settings.units)
        case .activeTime:
            let seconds = activities
                .filter { Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.contains($0.startDate) ?? false }
                .reduce(0) { $0 + $1.movingDuration }
            return PaceFormat.duration(seconds)
        }
    }

    private var headlineCaption: String {
        switch metric {
        case .steps:      return String(localized: "steps this week")
        case .distance:   return String(localized: "covered this week")
        case .activeTime: return String(localized: "moving this week")
        }
    }
}

private struct ProgressMetricTile: View {
    let symbol: String; let value: String; let label: String; let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol).font(.caption).foregroundStyle(tint)
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.72)
            Text(label).font(.caption2).foregroundStyle(.paceTextTertiary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(PaceSpacing.m).paceGlassCard(cornerRadius: PaceRadius.tile)
    }
}

struct LinkRow: View {
    var symbol: String
    var title: String
    var detail: String?

    var body: some View {
        HStack(spacing: PaceSpacing.m) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(.paceLime)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.paceTextPrimary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.paceTextTertiary)
        }
        .padding(PaceSpacing.l)
        .paceGlassCard(cornerRadius: PaceRadius.tile)
    }
}
