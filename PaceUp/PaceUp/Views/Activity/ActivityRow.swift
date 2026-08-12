//
//  ActivityRow.swift
//  Pace Up
//

import SwiftUI

struct ActivityRow: View {

    var activity: Activity
    var showsChevron: Bool = true

    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: PaceSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.paceTextPrimary)
                    .lineLimit(1)

                Text(PaceFormat.activityTimestamp(activity.startDate))
                    .font(.caption)
                    .foregroundStyle(.paceTextTertiary)

                HStack(spacing: 6) {
                    Text(PaceFormat.distance(activity.distance, units: settings.units))
                    Text("•")
                    Text(PaceFormat.duration(activity.movingDuration))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.paceTextSecondary)
                .monospacedDigit()
            }

            Spacer(minLength: PaceSpacing.s)

            Group {
                if activity.hasRoute {
                    RouteThumbnail(coordinates: activity.thumbnailCoordinates, lineWidth: 2)
                } else {
                    RouteThumbnailPlaceholder(symbolName: activity.type.symbolName)
                }
            }
            .frame(width: 56, height: 46)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.paceTextTertiary)
            }
        }
        .padding(PaceSpacing.m)
        .paceGlassCard(cornerRadius: PaceRadius.tile)
        .accessibilityElement(children: .combine)
    }
}
