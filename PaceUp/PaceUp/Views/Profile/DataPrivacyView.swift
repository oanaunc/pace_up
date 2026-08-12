//
//  DataPrivacyView.swift
//  Pace Up
//
//  Export, import, and the retention controls.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataPrivacyView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query private var activities: [Activity]

    @State private var exportURL: URL?
    @State private var showsImporter = false
    @State private var showsPurgeConfirmation = false
    @State private var showsDeleteOldConfirmation = false
    @State private var showsDeleteAllConfirmation = false
    @State private var alertMessage: String?
    @State private var purgePreview: RetentionService.Preview?

    private var retention: RetentionService { RetentionService(context: context) }
    private var stats: StatsService { StatsService(context: context) }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                LabeledContent(String(localized: "Activities"), value: "\(activities.count)")
                LabeledContent(
                    String(localized: "Route data"),
                    value: ByteCountFormatStyle(style: .file).format(Int64(stats.purgeableByteCount()))
                )
            } header: {
                Text("On this device")
            } footer: {
                Text("Everything Pace Up records is stored locally. Deleting the app removes this database, though your iCloud or encrypted device backup includes it, and any workouts written to Apple Health stay in Health.")
            }

            Section(String(localized: "Backup")) {
                Button {
                    exportBackup()
                } label: {
                    Label(String(localized: "Export All Activities"), systemImage: "square.and.arrow.up")
                }
                .disabled(activities.isEmpty)

                Button {
                    showsImporter = true
                } label: {
                    Label(String(localized: "Import Pace Up Backup"), systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("A backup is a readable JSON file containing your activities and routes. Importing merges it with what's already here; nothing is overwritten.")
            }

            Section {
                Stepper(value: $settings.retentionDays, in: 7...365, step: 1) {
                    HStack {
                        Text("Keep routes for")
                        Spacer()
                        Text("\(settings.retentionDays) days")
                            .foregroundStyle(.paceTextSecondary)
                            .monospacedDigit()
                    }
                }

                Button {
                    purgePreview = retention.preview(olderThan: settings.retentionDays)
                    showsPurgeConfirmation = true
                } label: {
                    Label(
                        String(localized: "Delete Routes Older Than \(settings.retentionDays) Days"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    .foregroundStyle(.paceOrange)
                }

                Toggle(isOn: $settings.autoPurgeEnabled) {
                    Text("Automatically Delete Old Routes")
                }

                if let last = settings.lastPurgeDate {
                    LabeledContent(String(localized: "Last cleanup"), value: last.formatted(.relative(presentation: .named)))
                }
            } header: {
                Text("Cleanup")
            } footer: {
                Text("This removes GPS traces and heart-rate detail from older activities. Distance, time, pace, splits, records, streaks and totals are kept — so your Progress and Personal Records screens stay complete.")
            }

            Section {
                Button(role: .destructive) {
                    showsDeleteOldConfirmation = true
                } label: {
                    Label(
                        String(localized: "Delete Activities Older Than \(settings.retentionDays) Days"),
                        systemImage: "calendar.badge.minus"
                    )
                }

                Button(role: .destructive) {
                    showsDeleteAllConfirmation = true
                } label: {
                    Label(String(localized: "Delete All Pace Up Data"), systemImage: "trash")
                }
            } header: {
                Text("Danger zone")
            } footer: {
                Text("Unlike the cleanup above, these remove entire activities. Lifetime totals, streaks and personal records for the deleted period will be lost. Neither touches Apple Health.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Data & Privacy"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(.paceLime)

        // MARK: Sheets and alerts

        .sheet(item: Binding(
            get: { exportURL.map { ShareItem(url: $0) } },
            set: { exportURL = $0?.url }
        )) { item in
            ShareLink(item: item.url) {
                Label(String(localized: "Share Backup"), systemImage: "square.and.arrow.up")
            }
            .presentationDetents([.height(160)])
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .confirmationDialog(
            String(localized: "Delete old Pace Up routes?"),
            isPresented: $showsPurgeConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Old Routes"), role: .destructive) {
                let count = retention.purgeDetail(olderThan: settings.retentionDays)
                alertMessage = count == 0
                    ? String(localized: "Nothing to clean up.")
                    : String(localized: "Cleaned up \(count) activities.")
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            if let preview = purgePreview, !preview.isEmpty {
                Text("This permanently deletes GPS routes and heart-rate detail from \(preview.activityCount) activities, freeing about \(preview.formattedSize). Their distance, time, pace and splits stay. Your recent \(settings.retentionDays) days are untouched.")
            } else {
                Text("There are no routes older than \(settings.retentionDays) days.")
            }
        }
        .confirmationDialog(
            String(localized: "Delete old activities entirely?"),
            isPresented: $showsDeleteOldConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Activities"), role: .destructive) {
                let count = retention.deleteEntireActivities(olderThan: settings.retentionDays)
                alertMessage = String(localized: "Deleted \(count) activities.")
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This removes whole activities older than \(settings.retentionDays) days, including their contribution to your lifetime totals and personal records. Apple Health is not affected.")
        }
        .confirmationDialog(
            String(localized: "Delete everything?"),
            isPresented: $showsDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete All Data"), role: .destructive) {
                ActivityStore(context: context).deleteAll()
                alertMessage = String(localized: "All Pace Up data deleted.")
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("Every activity, route, note and achievement in Pace Up will be permanently deleted. Workouts written to Apple Health remain in Health.")
        }
        .alert(String(localized: "Done"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: Actions

    private func exportBackup() {
        do {
            exportURL = try ExportService(context: context).exportBackup()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let outcome = try ImportService(context: context).importBackup(from: url)
                alertMessage = String(localized: "Imported \(outcome.imported) activities. \(outcome.skipped) were already here.")
            } catch {
                alertMessage = error.localizedDescription
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
        }
    }
}
