//
//  PersonalRecordsView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

struct PersonalRecordsView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Activity.startDate, order: .reverse)
    private var activities: [Activity]

    private var records: [PersonalRecord] {
        StatsService(context: context).personalRecords(units: settings.units)
    }

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    symbolName: "trophy",
                    title: String(localized: "No records yet"),
                    message: String(localized: "Record a few activities and your bests will show up here.")
                )
            } else {
                ScrollView {
                    VStack(spacing: PaceSpacing.s) {
                        ForEach(records) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.kind.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.paceTextPrimary)
                                    if let date = record.achievedOn {
                                        Text(PaceFormat.activityTimestamp(date))
                                            .font(.caption2)
                                            .foregroundStyle(.paceTextTertiary)
                                    }
                                }
                                Spacer()
                                Text(record.formattedValue)
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.paceLime)
                            }
                            .padding(PaceSpacing.l)
                            .paceGlassCard(cornerRadius: PaceRadius.tile)
                        }

                        Text("Records are recalculated from your saved activities, so they stay correct even after old routes are cleaned up.")
                            .font(.caption)
                            .foregroundStyle(.paceTextTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, PaceSpacing.l)
                            .padding(.horizontal, PaceSpacing.l)
                    }
                    .padding(.horizontal, PaceSpacing.l)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Personal Records"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
