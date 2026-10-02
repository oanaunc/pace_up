//
//  LiveActivityView.swift
//  Pace Up
//
//  The screen shown while recording. Deliberately a full-screen cover: losing
//  the pause control because the user wandered into another tab is the kind of
//  thing that ruins a run.
//

import SwiftUI
import SwiftData
import MapKit

struct LiveActivityView: View {

    @Environment(ActivityRecorder.self) private var recorder
    @Environment(AppSettings.self) private var settings
    @Environment(WaymarkMonitor.self) private var waymarks

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var isLocked = false
    @State private var showsDiscardConfirmation = false
    @State private var followTrigger = 0
    @State private var mapStyle: PaceMapStyle = .standard
    @State private var showsComposer = false
    @Query private var allWaymarks: [Waymark]

    private var isPaused: Bool { recorder.state == .paused }

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapView(
                coordinates: recorder.coordinates,
                style: mapStyle,
                showsUserLocation: true,
                showsEndpoints: recorder.coordinates.count > 1,
                interactionModes: isLocked ? [] : .all,
                followTrigger: followTrigger,
                cameraPosition: $camera
            )
            .withWaymarkPins(allWaymarks.prefix(200).map { WaymarkPinData($0) })
            .ignoresSafeArea()

            VStack(spacing: PaceSpacing.m) {
                topBar
                Spacer()
                if isPaused { pausedPanel } else { recordingPanel }
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, PaceSpacing.l)

            if isLocked {
                lockOverlay
            }

            // A waymark coming back takes the top of the screen, above the
            // lock overlay: it is worth reading even with the screen locked.
            if let encounter = waymarks.current {
                VStack {
                    WaymarkEncounterView(encounter: encounter) {
                        withAnimation(.snappy) { waymarks.dismissCurrent() }
                    }
                    .id(encounter.id)
                    .padding(.horizontal, PaceSpacing.l)
                    .padding(.top, PaceSpacing.xl)
                    Spacer()
                }
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.25), value: waymarks.current)
        .sheet(isPresented: $showsComposer) {
            if let location = recorder.lastLocation {
                WaymarkComposerView(
                    coordinate: location.coordinate,
                    sessionID: recorder.currentSessionID,
                    activityType: recorder.activityType
                ) { waymark in
                    waymarks.noteDropped(waymark)
                }
            }
        }
        .statusBarHidden(false)
        // No presentation here. Tapping Finish hands the run to
        // `recorder.pendingSummary`, and `RecordingFlowView` — the single
        // cover that owns this whole flow — swaps this screen for the summary.
        .confirmationDialog(
            String(localized: "Discard this activity?"),
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Discard"), role: .destructive) {
                recorder.discard()
            }
            Button(String(localized: "Keep Recording"), role: .cancel) {}
        } message: {
            Text("Everything recorded so far will be lost.")
        }
    }

    // MARK: Top

    private var topBar: some View {
        HStack {
            if !recorder.hasFullAccuracy || recorder.signalQuality == .none {
                Label(
                    recorder.signalQuality == .none
                        ? String(localized: "Searching for GPS")
                        : String(localized: "Low accuracy"),
                    systemImage: "antenna.radiowaves.left.and.right.slash"
                )
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .paceGlassControl(cornerRadius: 16, tint: .paceAmber)
            }

            Spacer()

            Button {
                showsComposer = true
            } label: {
                Label(String(localized: "Waymark"), systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.paceInk)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Color.paceLime, in: .capsule)
                    .overlay(alignment: .topTrailing) {
                        if !waymarks.droppedThisSession.isEmpty {
                            Text("\(waymarks.droppedThisSession.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.paceViolet, in: .circle)
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(recorder.lastLocation == nil)
            .accessibilityLabel(String(localized: "Leave a waymark here"))
            .accessibilityHint(String(localized: "Pins a note, photo, voice memo or time capsule to where you are standing"))

            Menu {
                Picker(String(localized: "Map Style"), selection: $mapStyle) {
                    ForEach(PaceMapStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.symbolName).tag(style)
                    }
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.subheadline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .paceGlassCircle()
        }
        .padding(.top, PaceSpacing.s)
    }

    // MARK: Recording

    private var recordingPanel: some View {
        PaceGlassGroup(spacing: 18) {
            VStack(spacing: PaceSpacing.l) {
                if let progress = recorder.goalProgress {
                    GoalProgressBar(progress: progress, label: goalLabel)
                }

                BigMetric(
                    value: PaceFormat.distanceValue(recorder.distance, units: settings.units),
                    unit: settings.units.distanceAbbreviation,
                    size: 58
                )

                HStack(spacing: 0) {
                    MetricColumn(value: PaceFormat.duration(recorder.movingDuration), caption: String(localized: "Time"))
                    MetricColumn(
                        value: recorder.activityType.prefersPaceOverSpeed
                            ? PaceFormat.paceValue(secondsPerKm: recorder.currentPaceSecondsPerKm, units: settings.units)
                            : PaceFormat.speed(metersPerSecond: recorder.distance / max(recorder.movingDuration, 1), units: settings.units),
                        caption: recorder.activityType.prefersPaceOverSpeed
                            ? String(localized: "Pace \(PaceFormat.paceUnitLabel(settings.units))")
                            : String(localized: "Speed")
                    )
                    MetricColumn(value: PaceFormat.steps(recorder.steps), caption: String(localized: "Steps"))
                }

                HStack(spacing: PaceSpacing.xl) {
                    // `contentShape` is load-bearing on every one of these: the
                    // glass is applied outside the Button, so the hit area is
                    // otherwise the glyph itself and a tap on the visible circle
                    // falls through to the map behind it. On this screen that
                    // means a runner jabbing at Lock or Recenter mid-run and
                    // getting nothing. Pause escapes it only because its own
                    // opaque `.background` gives it a real shape.
                    Button {
                        isLocked = true
                    } label: {
                        Image(systemName: "lock.fill")
                            .frame(width: 48, height: 48)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .paceGlassCircle()
                    .accessibilityLabel(String(localized: "Lock screen"))

                    Button {
                        recorder.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .foregroundStyle(Color.paceInk)
                            .frame(width: 68, height: 68)
                            .background(Color.paceLime, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Pause"))

                    Button {
                        followTrigger += 1
                        camera = .userLocation(fallback: .automatic)
                    } label: {
                        Image(systemName: "location.fill")
                            .frame(width: 48, height: 48)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .paceGlassCircle()
                    .accessibilityLabel(String(localized: "Recenter"))
                }
            }
            .padding(PaceSpacing.l)
            .paceGlassPanel()
        }
    }

    private var goalLabel: String {
        switch recorder.goal {
        case .none:
            return ""
        case .distance(let target):
            return String(localized: "Goal \(PaceFormat.distance(target, units: settings.units))")
        case .time(let target):
            return String(localized: "Goal \(PaceFormat.duration(target))")
        case .calories(let target):
            return String(localized: "Goal \(Int(target)) kcal")
        }
    }

    // MARK: Paused

    private var pausedPanel: some View {
        VStack(spacing: PaceSpacing.l) {
            Text(recorder.isAutoPaused
                 ? String(localized: "Auto-Paused")
                 : String(localized: "\(recorder.activityType.displayName) Paused"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.paceOrange)

            BigMetric(
                value: PaceFormat.distanceValue(recorder.distance, units: settings.units),
                unit: settings.units.distanceAbbreviation,
                size: 54
            )

            HStack(spacing: 0) {
                MetricColumn(value: PaceFormat.duration(recorder.movingDuration), caption: String(localized: "Time"))
                MetricColumn(
                    value: PaceFormat.paceValue(secondsPerKm: recorder.averagePaceSecondsPerKm, units: settings.units),
                    caption: String(localized: "Pace \(PaceFormat.paceUnitLabel(settings.units))")
                )
                MetricColumn(value: PaceFormat.steps(recorder.steps), caption: String(localized: "Steps"))
            }

            VStack(spacing: PaceSpacing.s) {
                PrimaryButton(title: String(localized: "Resume"), tint: .paceOrange, foreground: .white) {
                    recorder.resume()
                }

                Button {
                    finishActivity()
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .foregroundStyle(Color.paceRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        // Without this only the glyphs are tappable — the empty
                        // space either side of the word is not part of the
                        // label's hit region.
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .paceGlassControl(cornerRadius: 26)

                Button(String(localized: "Discard")) {
                    showsDiscardConfirmation = true
                }
                .font(.footnote)
                .foregroundStyle(.paceTextTertiary)
                .padding(.top, 2)
            }
        }
        .padding(PaceSpacing.l)
        .paceGlassPanel()
    }

    private func finishActivity() {
        recorder.finish()
    }

    // MARK: Lock

    /// Prevents pocket taps from pausing or ending a run. Slide to unlock,
    /// rather than a tap, for the same reason.
    private var lockOverlay: some View {
        VStack {
            Spacer()
            SlideToUnlock {
                isLocked = false
            }
            .padding(.horizontal, PaceSpacing.xl)
            .padding(.bottom, 60)
        }
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .transition(.opacity)
    }
}

struct GoalProgressBar: View {
    var progress: Double
    var label: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.paceLime)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(Color.paceLime)
                        .frame(width: max(4, geometry.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct SlideToUnlock: View {
    var onUnlock: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let travel = geometry.size.width - 62

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Text("Slide to unlock")
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(Color.paceLime)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "lock.open.fill")
                            .foregroundStyle(Color.paceInk)
                    }
                    .offset(x: offset + 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = min(max(0, value.translation.width), travel)
                            }
                            .onEnded { _ in
                                if offset > travel * 0.75 {
                                    onUnlock()
                                }
                                withAnimation(.snappy) { offset = 0 }
                            }
                    )
            }
        }
        .frame(height: 62)
    }
}
