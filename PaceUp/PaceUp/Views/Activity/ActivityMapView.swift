//
//  ActivityMapView.swift
//  Pace Up
//
//  All routes on one map, with per-type counts. The comps show this as a set of
//  circular badges over the map; those are rendered as a legend rather than as
//  map annotations, because annotations positioned over arbitrary routes end up
//  overlapping and unreadable.
//

import SwiftUI
import MapKit
import CoreLocation

struct ActivityMapView: View {

    var activities: [Activity]

    @Environment(AppSettings.self) private var settings

    @State private var camera: MapCameraPosition = .automatic
    @State private var style: PaceMapStyle = .standard
    @State private var selectedType: ActivityType?

    private var visible: [Activity] {
        activities
            .filter { $0.hasRoute }
            .filter { selectedType == nil || $0.type == selectedType }
    }

    private var counts: [(type: ActivityType, count: Int)] {
        ActivityType.allCases.compactMap { type in
            let count = activities.filter { $0.type == type }.count
            return count > 0 ? (type, count) : nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                ForEach(visible) { activity in
                    let coordinates = activity.thumbnailCoordinates
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(
                                activity.type.tint.opacity(0.9),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .mapStyle(style.mapStyle)
            .ignoresSafeArea()

            VStack(spacing: PaceSpacing.m) {
                legend
                recentStrip
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, PaceSpacing.l)
        }
        .navigationTitle(String(localized: "Activity Map"))
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
        .onAppear(perform: frameAll)
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PaceSpacing.s) {
                LegendChip(
                    title: String(localized: "All"),
                    count: activities.count,
                    tint: .paceLime,
                    isSelected: selectedType == nil
                ) {
                    withAnimation(.snappy) { selectedType = nil }
                    frameAll()
                }

                ForEach(counts, id: \.type) { entry in
                    LegendChip(
                        title: entry.type.displayName,
                        count: entry.count,
                        tint: entry.type.tint,
                        isSelected: selectedType == entry.type
                    ) {
                        withAnimation(.snappy) { selectedType = entry.type }
                        frameAll()
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var recentStrip: some View {
        VStack(spacing: PaceSpacing.s) {
            ForEach(visible.prefix(2)) { activity in
                NavigationLink {
                    ActivityDetailView(activity: activity)
                } label: {
                    HStack(spacing: PaceSpacing.m) {
                        Circle()
                            .fill(activity.type.tint)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.paceTextPrimary)
                            Text(PaceFormat.activityTimestamp(activity.startDate))
                                .font(.caption2)
                                .foregroundStyle(.paceTextTertiary)
                        }
                        Spacer()
                        Text("\(PaceFormat.distance(activity.distance, units: settings.units)) • \(PaceFormat.duration(activity.movingDuration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.paceTextSecondary)
                    }
                    .padding(PaceSpacing.m)
                    .paceGlassPanel(cornerRadius: PaceRadius.tile)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func frameAll() {
        let coordinates = visible.flatMap(\.thumbnailCoordinates)
        guard let region = RouteMath.region(for: coordinates) else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            camera = .region(region)
        }
    }
}

private struct LegendChip: View {
    var title: String
    var count: Int
    var tint: Color
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("\(count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.paceInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint, in: .capsule)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.paceTextPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .paceGlassControl(cornerRadius: 18, tint: isSelected ? tint : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
