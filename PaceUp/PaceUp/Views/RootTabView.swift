//
//  RootTabView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today
    case journal
    case journey
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

    /// One presentation covers the entire record-and-save flow.
    ///
    /// It stays up from the moment recording starts until the summary is either
    /// saved or dismissed. `RecordingFlowView` decides which screen to show
    /// inside it, so there is never a cover presented from within a cover.
    private var isSessionActive: Binding<Bool> {
        Binding(
            get: { recorder.hasActiveSession },
            set: { _ in }
        )
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(String(localized: "Today"), systemImage: "sun.max.fill", value: AppTab.today) {
                TodayView()
            }
            // Journal sits next to Today on purpose: waymarks are what Pace Up
            // is for, and the tracker exists to bring you back to them.
            Tab(String(localized: "Journal"), systemImage: "mappin.and.ellipse", value: AppTab.journal) {
                JournalTab()
            }
            Tab(String(localized: "Start"), systemImage: "record.circle", value: AppTab.start) {
                StartActivityView()
            }
            Tab(String(localized: "Journey"), systemImage: "map.fill", value: AppTab.journey) {
                JourneyView()
            }
            Tab(String(localized: "Profile"), systemImage: "person.fill", value: AppTab.profile) {
                ProfileView()
            }
        }
        // A recording in progress takes over the whole screen. Letting the user
        // wander into Settings mid-run and lose the pause button would be a
        // worse trade than a modal.
        .fullScreenCover(isPresented: isSessionActive) {
            RecordingFlowView()
        }
        .sheet(item: $recoveryCandidate) { session in
            // Recovering hands the run to `recorder.pendingSummary`, which
            // brings up the same flow cover as a live finish.
            RecoverySheet(session: session) {
                recoveryCandidate = nil
            }
            .presentationDetents([.height(360)])
            .presentationBackground(.regularMaterial)
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
    var completion: () -> Void

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
                    recorder.recover(session, units: settings.units)
                    completion()
                }
                Button(String(localized: "Discard")) {
                    recorder.dismissRecovery()
                    completion()
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
