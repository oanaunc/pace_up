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
                    PillPicker(options: Metric.allCases, title: \.title, selection: $metric)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    summaryCard
                    streakCard
                    weekCard
                    quickLinks
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background(Color.paceInk.ignoresSafeArea())
            .navigationTitle(String(localized: "Your Progress"))
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            Text(headlineValue)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(headlineCaption)
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)

            if let change = comparison.percentChange {
                Label(
                    String(localized: "\(change >= 0 ? "+" : "")\(Int(change.rounded()))% from last week"),
                    systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(change >= 0 ? Color.paceLime : Color.paceAmber)
            }

            WeeklyBarChart(
                bars: bars,
                goal: metric == .steps ? Double(settings.dailyStepGoal) : 0
            )
            .padding(.top, PaceSpacing.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
                Text("\(currentStreak) days 🔥")
                    .font(.title3.weight(.bold))
            }
            Spacer()
            MiniRing(progress: min(Double(currentStreak) / 30, 1), lineWidth: 5)
                .frame(width: 42, height: 42)
        }
        .padding(PaceSpacing.l)
        .paceGlassCard(cornerRadius: PaceRadius.tile)
    }

    private var weekCard: some View {
        HStack(spacing: PaceSpacing.m) {
            StatTile(
                value: PaceFormat.steps(weeklyStepTotal),
                caption: String(localized: "This Week"),
                tint: .paceLime
            )
            StatTile(
                value: PaceFormat.steps(dailyAverage),
                caption: String(localized: "Daily Average")
            )
        }
    }

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
