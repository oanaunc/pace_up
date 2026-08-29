//
//  TodaysMapView.swift
//  Pace Up
//

import SwiftUI
import MapKit
import CoreLocation

struct TodaysMapView: View {

    var activities: [Activity]

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var style: PaceMapStyle = .standard
    @State private var camera: MapCameraPosition = .automatic
    @State private var followTrigger = 0
    @State private var showsList = false
    @State private var currentRegion: MKCoordinateRegion?

    /// Every route recorded today, not just the first one found.
    ///
    /// This screen is called Today's Map. Showing one of three walks — which is
    /// what `first(where:)` did — is a bug the user can only notice by knowing
    /// what is missing.
    private var routes: [[CLLocationCoordinate2D]] {
        activities
            .filter(\.hasRoute)
            .map(\.thumbnailCoordinates)
            .filter { !$0.isEmpty }
    }

    private var coordinates: [CLLocationCoordinate2D] {
        routes.flatMap { $0 }
    }

    /// Halves the visible span, with a floor so repeated taps cannot zoom past
    /// what MapKit will render.
    private func zoomIn() {
        guard let region = currentRegion else { return }
        let span = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta / 2, 0.0005),
            longitudeDelta: max(region.span.longitudeDelta / 2, 0.0005)
        )
        withAnimation(.easeInOut(duration: 0.4)) {
            camera = .region(MKCoordinateRegion(center: region.center, span: span))
        }
    }

    private var totalDistance: Double {
        activities.reduce(0) { $0 + $1.distance }
    }

    private var totalDuration: TimeInterval {
        activities.reduce(0) { $0 + $1.movingDuration }
    }

    private var totalSteps: Int {
        activities.reduce(0) { $0 + $1.steps }
    }

    private var averagePace: Double {
        guard totalDistance > 10, totalDuration > 0 else { return 0 }
        return totalDuration / (totalDistance / 1000)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapView(
                routes: routes,
                style: style,
                showsUserLocation: true,
                showsControls: true,
                followTrigger: followTrigger,
                onRegionChange: { currentRegion = $0 },
                cameraPosition: $camera
            )
            .ignoresSafeArea()

            summaryPanel
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, PaceSpacing.l)
        }
        .navigationTitle(String(localized: "Today's Map"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(String(localized: "Map Style"), selection: $style) {
                        ForEach(PaceMapStyle.allCases) { option in
                            Label(option.displayName, systemImage: option.symbolName).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "square.3.layers.3d")
                }
            }
        }
        .sheet(isPresented: $showsList) {
            NavigationStack {
                List(activities) { activity in
                    NavigationLink {
                        ActivityDetailView(activity: activity)
                    } label: {
                        ActivityRow(activity: activity, showsChevron: false)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .background(Color.paceInk)
                .navigationTitle(String(localized: "Today"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var summaryPanel: some View {
        VStack(spacing: PaceSpacing.m) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)

            HStack(alignment: .firstTextBaseline) {
                BigMetric(
                    value: PaceFormat.distanceValue(totalDistance, units: settings.units),
                    unit: settings.units.distanceAbbreviation,
                    size: 40
                )
                Spacer()
                // Was a second Recenter wearing a zoom icon: it incremented the
                // same `followTrigger` as the button below, so pressing it after
                // the map was already framed did nothing at all. A plus on a map
                // means zoom in, so it now zooms in — and "Fit Route" is the way
                // back out.
                Button(action: zoomIn) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .paceGlassCircle()
                .disabled(currentRegion == nil)
                .opacity(currentRegion == nil ? 0.4 : 1)
            }

            HStack(spacing: 0) {
                MetricColumn(value: PaceFormat.clock(totalDuration), caption: String(localized: "Time"))
                MetricColumn(
                    value: PaceFormat.pace(secondsPerKm: averagePace, units: settings.units),
                    caption: String(localized: "Avg Pace")
                )
                MetricColumn(value: PaceFormat.steps(totalSteps), caption: String(localized: "Steps"))
            }

            // Every label carries an explicit `contentShape`. The glass is
            // applied by a modifier *outside* the Button, so without one the
            // hit area is the SF Symbol's own glyph — a tap anywhere on the
            // visible circle lands on the map instead, and the control reads
            // as dead. The same fix is already present on the glass controls
            // in LiveActivityView and TodayView.
            HStack(spacing: PaceSpacing.m) {
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        camera = .userLocation(fallback: .automatic)
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .paceGlassCircle()

                Button {
                    followTrigger += 1
                } label: {
                    Text(coordinates.isEmpty ? "My Location" : "Fit Route")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .paceGlassControl(cornerRadius: 22)

                Button {
                    showsList = true
                } label: {
                    Image(systemName: "list.bullet")
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .paceGlassCircle()
                .disabled(activities.isEmpty)
                .opacity(activities.isEmpty ? 0.4 : 1)
            }
        }
        .padding(PaceSpacing.l)
        .paceGlassPanel()
    }
}
