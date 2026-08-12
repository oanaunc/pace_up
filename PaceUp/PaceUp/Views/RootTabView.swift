//
//  RootTabView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today
    case activity
    case start
    case progress
    case profile
}

struct RootTabView: View {

    @Environment(ActivityRecorder.self) private var recorder
    @Environment(AppSettings.self) private var settings
    @Environment(HealthKitManager.self) private var health
    @Environment(\.modelContext) private var context

    @State private var selection: AppTab = .today
    @State private var recoveryCandidate: RecoverableSession?
    @State private var pendingRecovered: FinishedActivity?

    /// Read-only: the cover is driven entirely by the recorder's state, and
    /// `.saving` is included so the cover does not tear itself down — taking the
    /// summary sheet with it — the moment the user taps Finish.
    private var isRecordingBinding: Binding<Bool> {
        Binding(
            get: { [ActivityRecorder.State.recording, .paused, .saving].contains(recorder.state) },
            set: { _ in }
        )
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(String(localized: "Today"), systemImage: "sun.max.fill", value: AppTab.today) {
                TodayView()
            }
            Tab(String(localized: "Activity"), systemImage: "chart.bar.fill", value: AppTab.activity) {
                ActivityListView()
            }
            Tab(String(localized: "Start"), systemImage: "record.circle", value: AppTab.start) {
                StartActivityView()
            }
            Tab(String(localized: "Progress"), systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressDashboardView()
            }
            Tab(String(localized: "Profile"), systemImage: "person.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
        // A recording in progress takes over the whole screen. Letting the user
        // wander into Settings mid-run and lose the pause button would be a
        // worse trade than a modal.
        .fullScreenCover(isPresented: isRecordingBinding) {
            LiveActivityView()
        }
        .sheet(item: $recoveryCandidate) { session in
            RecoverySheet(session: session) { recovered in
                recoveryCandidate = nil
                if let recovered { pendingRecovered = recovered }
            }
            .presentationDetents([.height(360)])
            .presentationBackground(.regularMaterial)
        }
        .sheet(item: $pendingRecovered) { finished in
            ActivitySummaryView(finished: finished) {
                pendingRecovered = nil
            }
        }
        .onChange(of: recorder.recoverableSession) { _, session in
            recoveryCandidate = session
        }
        .task {
            recorder.checkForRecoverableSession()
        }
    }
}

/// Offered at launch when a previous recording was cut short by a termination.
struct RecoverySheet: View {

    var session: RecoverableSession
    var completion: (FinishedActivity?) -> Void

    @Environment(ActivityRecorder.self) private var recorder
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: PaceSpacing.l) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.paceLime)
                .padding(.top, PaceSpacing.xl)

            Text("Unfinished activity")
                .font(.title3.bold())

            Text("Pace Up was interrupted during a \(session.header.activityType.displayName.lowercased()). The route up to that point was saved.")
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PaceSpacing.xl)

            HStack(spacing: PaceSpacing.xl) {
                MetricColumn(
                    value: PaceFormat.distanceValue(session.estimatedDistance, units: settings.units),
                    caption: settings.units.distanceAbbreviation
                )
                MetricColumn(
                    value: PaceFormat.duration(session.estimatedDuration),
                    caption: String(localized: "Time")
                )
            }
            .padding(.vertical, PaceSpacing.s)

            VStack(spacing: PaceSpacing.s) {
                PrimaryButton(title: String(localized: "Recover Activity")) {
                    completion(recorder.recover(session))
                }
                Button(String(localized: "Discard")) {
                    recorder.dismissRecovery()
                    completion(nil)
                }
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
            }
            .padding(.horizontal, PaceSpacing.xl)
            .padding(.bottom, PaceSpacing.xl)
        }
        .frame(maxWidth: .infinity)
    }
}
