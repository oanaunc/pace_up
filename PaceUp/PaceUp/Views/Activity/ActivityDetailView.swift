//
//  ActivityDetailView.swift
//  Pace Up
//

import SwiftUI
import SwiftData
import MapKit

struct ActivityDetailView: View {

    @Bindable var activity: Activity

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case overview, splits, charts
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return String(localized: "Overview")
            case .splits:   return String(localized: "Splits")
            case .charts:   return String(localized: "Charts")
            }
        }
    }

    @State private var tab: Tab = .overview
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftNote = ""
    @State private var shareURL: URL?
    @State private var showsDeleteConfirmation = false
    @State private var exportError: String?

    private var routePoints: [RoutePoint] { activity.routePoints }

    var body: some View {
        ScrollView {
            VStack(spacing: PaceSpacing.l) {
                mapHeader
                headline
                PillPicker(options: Tab.allCases, title: \.title, selection: $tab)

                switch tab {
                case .overview: overview
                case .splits:   splitsSection
                case .charts:   chartsSection
                }
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, 100)
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(activity.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        draftTitle = activity.title
                        draftNote = activity.note ?? ""
                        isEditing = true
                    } label: {
                        Label(String(localized: "Edit"), systemImage: "pencil")
                    }

                    Button {
                        exportGPX()
                    } label: {
                        Label(String(localized: "Export GPX"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(!activity.hasFullRoute)

                    Divider()

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "Delete Activity"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) { editSheet }
        .sheet(item: Binding(
            get: { shareURL.map { ShareItem(url: $0) } },
            set: { shareURL = $0?.url }
        )) { item in
            ShareLink(item: item.url) {
                Label(String(localized: "Share GPX"), systemImage: "square.and.arrow.up")
            }
            .presentationDetents([.height(160)])
        }
        .alert(String(localized: "Export failed"), isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .confirmationDialog(
            String(localized: "Delete this activity?"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                ActivityStore(context: context).delete(activity)
                dismiss()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This removes it from Pace Up. Any workout written to Apple Health stays there.")
        }
    }

    // MARK: Header

    @ViewBuilder
    private var mapHeader: some View {
        if activity.hasFullRoute {
            StaticRouteMap(coordinates: routePoints.map(\.coordinate))
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: PaceRadius.card))
        } else if activity.hasRoute {
            // Route was purged: the permanent thumbnail is all that remains.
            VStack(spacing: PaceSpacing.s) {
                RouteThumbnail(coordinates: activity.thumbnailCoordinates, lineWidth: 3)
                    .frame(height: 150)
                Label(
                    String(localized: "Full route removed by your 30-day cleanup"),
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.caption)
                .foregroundStyle(.paceTextTertiary)
            }
            .padding(PaceSpacing.l)
            .paceGlassCard()
        }
    }

    private var headline: some View {
        VStack(spacing: PaceSpacing.m) {
            BigMetric(
                value: PaceFormat.distanceValue(activity.distance, units: settings.units),
                unit: settings.units.distanceAbbreviation,
                size: 48
            )

            HStack(spacing: 0) {
                MetricColumn(value: PaceFormat.duration(activity.movingDuration), caption: String(localized: "Duration"))
                MetricColumn(
                    value: PaceFormat.pace(secondsPerKm: activity.averagePaceSecondsPerKm, units: settings.units),
                    caption: String(localized: "Avg Pace")
                )
                MetricColumn(
                    value: "\(PaceFormat.energy(activity.activeEnergy)) kcal",
                    caption: String(localized: "Calories")
                )
            }
        }
        .padding(.vertical, PaceSpacing.s)
    }

    // MARK: Overview

    private var overview: some View {
        VStack(spacing: PaceSpacing.l) {
            VStack(spacing: 14) {
                MetricRowItem(
                    caption: String(localized: "Elevation gain"),
                    value: PaceFormat.elevation(activity.elevationGain, units: settings.units)
                )
                Divider().overlay(Color.paceHairline)
                MetricRowItem(caption: String(localized: "Steps"), value: PaceFormat.steps(activity.steps))
                Divider().overlay(Color.paceHairline)
                MetricRowItem(
                    caption: String(localized: "Elapsed"),
                    value: PaceFormat.duration(activity.elapsedDuration)
                )
                if let average = activity.averageHeartRate {
                    Divider().overlay(Color.paceHairline)
                    MetricRowItem(
                        caption: String(localized: "Avg heart rate"),
                        value: "\(Int(average)) bpm"
                    )
                }
                if let best = activity.bestSplitPaceSecondsPerKm {
                    Divider().overlay(Color.paceHairline)
                    MetricRowItem(
                        caption: String(localized: "Best split"),
                        value: PaceFormat.pace(secondsPerKm: best, units: settings.units)
                    )
                }
            }
            .padding(PaceSpacing.l)
            .paceGlassCard()

            if let note = activity.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.paceTextTertiary)
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.paceTextPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PaceSpacing.l)
                .paceGlassCard()
            }
        }
    }

    // MARK: Splits

    @ViewBuilder
    private var splitsSection: some View {
        let splits = activity.splits
        if splits.isEmpty {
            EmptyStateView(
                symbolName: "chart.bar",
                title: String(localized: "No splits"),
                message: String(localized: "Splits appear once an activity covers at least one \(settings.units.distanceAbbreviation).")
            )
        } else {
            VStack(spacing: PaceSpacing.l) {
                SplitBars(splits: splits, units: settings.units)
                    .padding(PaceSpacing.l)
                    .paceGlassCard()

                if activity.isDetailPurged {
                    Label(
                        String(localized: "Splits are kept permanently, even after routes are cleaned up."),
                        systemImage: "checkmark.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(.paceTextTertiary)
                }
            }
        }
    }

    // MARK: Charts

    @ViewBuilder
    private var chartsSection: some View {
        if activity.isDetailPurged {
            EmptyStateView(
                symbolName: "clock.arrow.circlepath",
                title: String(localized: "Detailed charts removed"),
                message: String(localized: "This activity is older than your cleanup window, so its second-by-second data was deleted. Distance, time, pace and splits are still here.")
            )
        } else if routePoints.count < 3 {
            EmptyStateView(
                symbolName: "chart.xyaxis.line",
                title: String(localized: "Not enough data"),
                message: String(localized: "Charts need a recorded GPS route.")
            )
        } else {
            VStack(alignment: .leading, spacing: PaceSpacing.l) {
                chartCard(title: String(localized: "Pace")) {
                    PaceChart(
                        series: RouteMath.paceSeries(from: routePoints),
                        units: settings.units
                    )
                }

                chartCard(
                    title: String(localized: "Elevation"),
                    trailing: PaceFormat.elevation(activity.elevationGain, units: settings.units)
                ) {
                    ElevationChart(
                        series: RouteMath.elevationSeries(from: routePoints),
                        units: settings.units
                    )
                }

                let heartRates = activity.heartRateSamples
                if !heartRates.isEmpty {
                    chartCard(
                        title: String(localized: "Heart Rate"),
                        trailing: activity.averageHeartRate.map { "\(Int($0)) avg" }
                    ) {
                        HeartRateChart(samples: heartRates)
                    }
                }
            }
        }
    }

    private func chartCard<Content: View>(title: String,
                                          trailing: String? = nil,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption)
                        .foregroundStyle(.paceTextSecondary)
                }
            }
            content()
        }
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    // MARK: Edit

    private var editSheet: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Name")) {
                    TextField(String(localized: "Activity name"), text: $draftTitle)
                }
                Section(String(localized: "Note")) {
                    TextField(String(localized: "How was it?"), text: $draftNote, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paceInk)
            .navigationTitle(String(localized: "Edit Activity"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { isEditing = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        ActivityStore(context: context).update(
                            activity,
                            title: draftTitle,
                            note: draftNote
                        )
                        isEditing = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func exportGPX() {
        do {
            shareURL = try ExportService(context: context).exportGPX(for: activity)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

/// Wrapper so a URL can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
