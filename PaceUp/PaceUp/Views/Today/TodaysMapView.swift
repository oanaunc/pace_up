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

    private var coordinates: [CLLocationCoordinate2D] {
        activities.first(where: { $0.hasRoute })?.thumbnailCoordinates ?? []
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
                coordinates: coordinates,
                style: style,
                showsUserLocation: true,
                showsControls: true,
                followTrigger: followTrigger,
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
                Button {
                    followTrigger += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .paceGlassCircle()
            }

            HStack(spacing: 0) {
                MetricColumn(value: PaceFormat.clock(totalDuration), caption: String(localized: "Time"))
                MetricColumn(
                    value: PaceFormat.pace(secondsPerKm: averagePace, units: settings.units),
                    caption: String(localized: "Avg Pace")
                )
                MetricColumn(value: PaceFormat.steps(totalSteps), caption: String(localized: "Steps"))
            }

            HStack(spacing: PaceSpacing.m) {
                Button {
                    camera = .userLocation(fallback: .automatic)
                } label: {
                    Image(systemName: "location.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .paceGlassCircle()

                Button {
                    followTrigger += 1
                } label: {
                    Text("Recenter")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .paceGlassControl(cornerRadius: 22)

                Button {
                    showsList = true
                } label: {
                    Image(systemName: "list.bullet")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .paceGlassCircle()
            }
        }
        .padding(PaceSpacing.l)
        .paceGlassPanel()
    }
}
