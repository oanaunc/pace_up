//
//  ProfileView.swift
//  Pace Up
//
//  There is no account, so this is a summary of the user's own history rather
//  than a profile in the social sense: no name to sign in with, no avatar to
//  upload, nothing that leaves the device.
//

import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Activity.startDate, order: .reverse)
    private var activities: [Activity]

    private var totals: StatsService.LifetimeTotals {
        StatsService(context: context).lifetimeTotals()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaceSpacing.l) {
                    header
                    totalsRow
                    profileStoryCard
                    identityCard
                    links
                    privacyNote
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background { PacePageBackground(image: "ProfileHorizon", imageHeight: 470, opacity: 0.42) }
            .navigationTitle(String(localized: "Profile"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack(spacing: PaceSpacing.m) {
            ZStack { Circle().fill(Color.paceLime.opacity(0.16)); Circle().stroke(Color.paceLime.opacity(0.45)); Image(systemName: "figure.run").font(.title2).foregroundStyle(.paceLime) }.frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("MY PACE UP").font(.caption.bold()).tracking(1.8).foregroundStyle(.paceLime)
                Text(settings.primaryGoal?.title ?? "Your movement story").font(.title3.bold())
                Text(memberLine).font(.caption).foregroundStyle(.paceTextSecondary)
            }
            Spacer()
        }.padding(.top, PaceSpacing.s)
    }

    private var memberLine: String {
        guard let first = activities.last?.startDate else { return "Ready for your first activity" }
        return "Moving since \(first.formatted(.dateTime.month(.wide).year()))"
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            MetricColumn(
                value: PaceFormat.compactCount(totals.steps),
                caption: String(localized: "Steps"),
                valueSize: 22
            )
            MetricColumn(
                value: PaceFormat.distanceValue(totals.distance, units: settings.units),
                caption: settings.units.distanceAbbreviation,
                valueSize: 22
            )
            MetricColumn(
                value: "\(totals.activityCount)",
                caption: String(localized: "Activities"),
                valueSize: 22
            )
        }
        .padding(.vertical, PaceSpacing.l)
        .paceGlassCard()
    }

    private var links: some View {
        VStack(spacing: PaceSpacing.s) {
            NavigationLink {
                StepGoalView()
            } label: {
                LinkRow(
                    symbol: "target",
                    title: String(localized: "Goals"),
                    detail: PaceFormat.steps(settings.dailyStepGoal)
                )
            }
            .buttonStyle(.plain)

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

            NavigationLink {
                SettingsView()
            } label: {
                LinkRow(symbol: "gearshape", title: String(localized: "Settings"))
            }
            .buttonStyle(.plain)
        }
    }

    private var profileStoryCard: some View {
        EditorialImageCard(
            image: "ProfileStory",
            eyebrow: "Your story",
            title: totals.activityCount == 0 ? "The first chapter is ready" : "Built across \(totals.activityCount) moments",
            subtitle: "Your routes, milestones, and movement history belong to you."
        )
    }

    private var identityCard: some View {
        HStack(spacing: PaceSpacing.m) {
            Image(systemName: "leaf.fill").foregroundStyle(.paceMint).frame(width: 38, height: 38).background(Color.paceMint.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(movementIdentity).font(.headline)
                Text("Based on the activities you choose most often.").font(.caption).foregroundStyle(.paceTextSecondary)
            }
            Spacer()
        }.padding(PaceSpacing.l).paceGlassCard(cornerRadius: PaceRadius.tile)
    }

    private var movementIdentity: String {
        let mostCommon = Dictionary(grouping: activities, by: \.type).max { $0.value.count < $1.value.count }?.key
        guard let mostCommon else { return "Your movement identity will grow here" }
        switch mostCommon {
        case .run, .trailRun: return "You are a momentum builder"
        case .hike: return "You are an outdoor explorer"
        case .cycle: return "You are a distance seeker"
        case .wheelchair: return "You are a determined mover"
        default: return "You are a consistency builder"
        }
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "Private by design"), systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.paceLime)
            Text("Pace Up doesn't require an account. Your Pace Up data stays on your device.")
                .font(.caption)
                .foregroundStyle(.paceTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PaceSpacing.l)
        .background(Color.paceLime.opacity(0.08), in: .rect(cornerRadius: PaceRadius.tile))
    }
}

struct StepGoalView: View {

    @Environment(AppSettings.self) private var settings
    @State private var goal: Double = 10000
    @State private var isCustom = false

    private let presets = [5000, 7500, 10000, 12500, 15000]

    var body: some View {
        ScrollView {
            VStack(spacing: PaceSpacing.xl) {
                VStack(spacing: PaceSpacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.paceLime.opacity(0.15))
                            .frame(width: 76, height: 76)
                        Image(systemName: "shoeprints.fill")
                            .font(.title)
                            .foregroundStyle(.paceLime)
                    }
                    Text("Daily Goal")
                        .font(.subheadline)
                        .foregroundStyle(.paceTextSecondary)
                    Text("\(Int(goal).formatted()) steps")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.top, PaceSpacing.l)

                HStack(spacing: PaceSpacing.s) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            withAnimation(.snappy) {
                                goal = Double(preset)
                                isCustom = false
                            }
                        } label: {
                            Text(preset >= 1000 ? "\(preset / 1000)\(preset % 1000 == 0 ? "K" : ".5K")" : "\(preset)")
                                .font(.subheadline.weight(Int(goal) == preset ? .bold : .regular))
                                .foregroundStyle(Int(goal) == preset ? Color.paceInk : Color.paceTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    Int(goal) == preset ? Color.paceLime : Color.white.opacity(0.06),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: PaceSpacing.s) {
                    Slider(value: $goal, in: 1000...30000, step: 250)
                        .tint(.paceLime)
                    HStack {
                        Text("1K").font(.caption2).foregroundStyle(.paceTextTertiary)
                        Spacer()
                        Text("30K").font(.caption2).foregroundStyle(.paceTextTertiary)
                    }
                }
                .padding(PaceSpacing.l)
                .paceGlassCard()

                Text("A goal you hit most days beats one you hit occasionally. You can change it any time.")
                    .font(.caption)
                    .foregroundStyle(.paceTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, 100)
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Step Goal"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { goal = Double(settings.dailyStepGoal) }
        .onDisappear { settings.dailyStepGoal = Int(goal) }
    }
}
