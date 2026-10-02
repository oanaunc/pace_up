//
//  PaceUpApp.swift
//  Pace Up
//
//  Every step moves you forward.
//

import SwiftUI
import SwiftData

@main
struct PaceUpApp: App {

    @State private var settings = AppSettings.shared
    @State private var health = HealthKitManager.shared
    @State private var recorder = ActivityRecorder()
    @State private var waymarks = WaymarkMonitor.shared

    private let container = PaceUpStore.makeContainer()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environment(settings)
                .environment(health)
                .environment(recorder)
                .environment(waymarks)
                .task { connectWaymarks() }
                // The comps are dark throughout, and the map, route gradient
                // and glass materials are all tuned for a dark backdrop.
                .preferredColorScheme(.dark)
                .tint(.paceLime)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await onForeground() }
        }
    }

    /// Waymarks ride on the recorder: every accepted fix is checked against
    /// them, in the foreground or with the phone in a pocket.
    @MainActor
    private func connectWaymarks() {
        let context = container.mainContext
        waymarks.configure(context: context)
        WaymarkSync.shared.activate(context: context)
        let monitor = waymarks
        recorder.onSessionStart = { id in monitor.beginSession(id) }
        recorder.onAcceptedLocation = { location in monitor.evaluate(location) }
        #if DEBUG
        WaymarkDemoSeed.seedIfRequested(context: context)
        #endif
        WaymarkStore(context: context).didChange()
    }

    @MainActor
    private func onForeground() async {
        await health.refreshAuthorizationState()
        if health.authorizationState == .authorized {
            await health.refreshToday()
        }

        let context = container.mainContext
        RetentionService(context: context).runAutomaticPurgeIfNeeded()
        recorder.checkForRecoverableSession()

        await ActivityStore(context: context)
            .refreshWidgetSnapshot(health: health, units: settings.units)
    }
}

/// Chooses between onboarding and the main app, and hosts the modals that can
/// appear over either.
struct RootContainerView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ActivityRecorder.self) private var recorder

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: settings.hasCompletedOnboarding)
        .background(Color.paceInk.ignoresSafeArea())
    }
}
