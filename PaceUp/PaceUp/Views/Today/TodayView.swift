//
//  TodayView.swift
//  Pace Up
//

import SwiftUI
import SwiftData
import CoreLocation

struct TodayView: View {

    @Environment(HealthKitManager.self) private var health
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query(sort: \Activity.startDate, order: .reverse)
    private var activities: [Activity]

    @State private var showsMap = false

    private var todaysActivities: [Activity] {
        activities.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    /// The route shown in the "Today's movement" card: the most recent activity
    /// today that still has a trace.
    private var featuredRoute: [CLLocationCoordinate2D] {
        todaysActivities.first(where: { $0.hasRoute })?.thumbnailCoordinates ?? []
    }

    private var remainingSteps: Int {
        max(0, settings.dailyStepGoal - health.todaySteps)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaceSpacing.l) {
                    greeting
                    ringCard
                    goalNudge
                    movementCard
                    if !todaysActivities.isEmpty {
                        todaysActivityList
                    }
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background(Color.paceInk.ignoresSafeArea())
            .navigationDestination(isPresented: $showsMap) {
                TodaysMapView(activities: todaysActivities)
            }
            .refreshable {
                await health.refreshToday()
            }
            .task {
                await health.refreshAuthorizationState()
                if health.authorizationState == .authorized {
                    await health.refreshToday()
                }
            }
        }
    }

    // MARK: Pieces

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greetingText)
                .font(.title2.bold())
            Text(PaceFormat.longDate(.now))
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PaceSpacing.s)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return String(localized: "Good morning")
        case 12..<18: return String(localized: "Good afternoon")
        default:      return String(localized: "Good evening")
        }
    }

    private var ringCard: some View {
        VStack(spacing: PaceSpacing.l) {
            ProgressRing(progress: goalProgress) {
                VStack(spacing: 0) {
                    Text(PaceFormat.steps(health.todaySteps))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("STEPS")
                        .font(.caption.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(.paceTextSecondary)
                    Text("\(Int(goalProgress * 100))% of \(PaceFormat.steps(settings.dailyStepGoal))")
                        .font(.caption2)
                        .foregroundStyle(.paceTextTertiary)
                        .padding(.top, 4)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.top, PaceSpacing.s)

            HStack(spacing: 0) {
                MetricColumn(
                    value: PaceFormat.distanceValue(health.todayDistance, units: settings.units),
                    caption: settings.units.distanceAbbreviation
                )
                MetricColumn(
                    value: PaceFormat.energy(health.todayActiveEnergy),
                    caption: String(localized: "kcal")
                )
                MetricColumn(
                    value: PaceFormat.duration(TimeInterval(health.todayActiveMinutes * 60)),
                    caption: String(localized: "active")
                )
            }
        }
        .padding(.vertical, PaceSpacing.l)
        .frame(maxWidth: .infinity)
        .paceGlassCard()
        .overlay(alignment: .top) {
            if health.authorizationState != .authorized {
                healthPrompt
            }
        }
    }

    private var goalProgress: Double {
        guard settings.dailyStepGoal > 0 else { return 0 }
        return min(Double(health.todaySteps) / Double(settings.dailyStepGoal), 1)
    }

    private var healthPrompt: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.text.square")
            Text("Connect Apple Health to see your steps")
                .font(.caption)
            Spacer(minLength: 0)
            Button(String(localized: "Connect")) {
                Task { await health.requestAuthorization() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.paceLime)
        }
        .padding(.horizontal, PaceSpacing.m)
        .padding(.vertical, 10)
        .background(Color.paceAmber.opacity(0.12), in: .rect(cornerRadius: 12))
        .padding(PaceSpacing.m)
    }

    @ViewBuilder
    private var goalNudge: some View {
        if health.authorizationState == .authorized {
            HStack(spacing: 10) {
                Image(systemName: remainingSteps > 0 ? "figure.walk" : "checkmark.seal.fill")
                    .foregroundStyle(.paceLime)
                Text(remainingSteps > 0
                     ? String(localized: "\(PaceFormat.steps(remainingSteps)) steps to your goal")
                     : String(localized: "Daily goal reached. Nice work."))
                    .font(.subheadline)
                Spacer()
                if remainingSteps > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.paceTextTertiary)
                }
            }
            .padding(PaceSpacing.l)
            .paceGlassCard(cornerRadius: PaceRadius.tile)
        }
    }

    private var movementCard: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            HStack {
                Text("Today's movement")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !featuredRoute.isEmpty {
                    Button {
                        showsMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.paceTextSecondary)
                }
            }

            if featuredRoute.count > 1 {
                RouteThumbnail(coordinates: featuredRoute, lineWidth: 3)
                    .frame(height: 120)
                    .contentShape(.rect)
                    .onTapGesture { showsMap = true }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.title3)
                            .foregroundStyle(.paceTextTertiary)
                        Text("No route recorded today")
                            .font(.caption)
                            .foregroundStyle(.paceTextTertiary)
                    }
                    Spacer()
                }
                .frame(height: 120)
            }
        }
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    private var todaysActivityList: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            SectionHeader(title: String(localized: "Today's activities"))
            ForEach(todaysActivities) { activity in
                NavigationLink {
                    ActivityDetailView(activity: activity)
                } label: {
                    ActivityRow(activity: activity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(AppSettings.shared)
        .environment(HealthKitManager.shared)
        .modelContainer(PaceUpStore.makePreviewContainer())
        .preferredColorScheme(.dark)
}
