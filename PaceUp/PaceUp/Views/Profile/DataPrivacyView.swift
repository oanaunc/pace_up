//
//  DataPrivacyView.swift
//  Pace Up
//
//  Export, import, and the retention controls.
//
//  ── A note on why this file is chopped up the way it is ────────────────────
//
//  SwiftUI type-checks a `body` as one expression. A Form with four Sections
//  and a chain of a dozen modifiers — several of which take trailing closures
//  containing interpolated Text, and three of which build `Binding(get:set:)`
//  inline — exceeds the solver's budget and fails with "unable to type-check
//  this expression in reasonable time". The error is reported at an arbitrary
//  point inside the expression, which makes it look like an innocent line is
//  at fault.
//
//  So: every Section is its own View with an explicit type, every Binding and
//  every dialog message is a named property with an explicit annotation, and
//  the modifier chain is split across two ViewModifiers. Each piece is then
//  solved independently and cheaply. Keep it this way when adding to it.
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
        form
            .modifier(Chrome())
            .modifier(makeFileTransfers())
            .modifier(makeDestructiveDialogs())
    }

    // MARK: - Form

    private var form: some View {
        Form {
            StorageSection(
                activityCount: activities.count,
                routeDataSize: formattedRouteDataSize
            )
            BackupSection(
                canExport: !activities.isEmpty,
                onExport: exportBackup,
                onImport: { showsImporter = true }
            )
            CleanupSection(
                settings: settings,
                onPurgeTapped: {
                    purgePreview = retention.preview(olderThan: settings.retentionDays)
                    showsPurgeConfirmation = true
                }
            )
            DangerSection(
                retentionDays: settings.retentionDays,
                onDeleteOld: { showsDeleteOldConfirmation = true },
                onDeleteAll: { showsDeleteAllConfirmation = true }
            )
        }
    }

    private var formattedRouteDataSize: String {
        let bytes = Int64(stats.purgeableByteCount())
        return ByteCountFormatStyle(style: .file).format(bytes)
    }

    // MARK: - Modifier groups

    private func makeFileTransfers() -> FileTransfers {
        FileTransfers(
            shareItem: shareItemBinding,
            showsImporter: $showsImporter,
            onImportResult: handleImport
        )
    }

    private func makeDestructiveDialogs() -> DestructiveDialogs {
        DestructiveDialogs(
            retentionDays: settings.retentionDays,
            purgePreview: purgePreview,
            showsPurge: $showsPurgeConfirmation,
            showsDeleteOld: $showsDeleteOldConfirmation,
            showsDeleteAll: $showsDeleteAllConfirmation,
            alertMessage: alertMessageBinding,
            onPurge: performPurge,
            onDeleteOld: performDeleteOld,
            onDeleteAll: performDeleteAll
        )
    }

    // MARK: - Bindings
    //
    // Named and explicitly typed. Built inline inside the modifier chain, these
    // were a large share of the solver's work.

    private var shareItemBinding: Binding<ShareItem?> {
        Binding<ShareItem?>(
            get: { exportURL.map { ShareItem(url: $0) } },
            set: { exportURL = $0?.url }
        )
    }

    private var alertMessageBinding: Binding<String?> {
        Binding<String?>(
            get: { alertMessage },
            set: { alertMessage = $0 }
        )
    }

    // MARK: - Actions

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
                let imported = outcome.imported
                let skipped = outcome.skipped
                alertMessage = String(localized: "Imported \(imported) activities. \(skipped) were already here.")
            } catch {
                alertMessage = error.localizedDescription
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
        }
    }

    private func performPurge() {
        let count = retention.purgeDetail(olderThan: settings.retentionDays)
        alertMessage = count == 0
            ? String(localized: "Nothing to clean up.")
            : String(localized: "Cleaned up \(count) activities.")
    }

    private func performDeleteOld() {
        let count = retention.deleteEntireActivities(olderThan: settings.retentionDays)
        alertMessage = String(localized: "Deleted \(count) activities.")
    }

    private func performDeleteAll() {
        ActivityStore(context: context).deleteAll()
        alertMessage = String(localized: "All Pace Up data deleted.")
    }
}

// MARK: - Sections

private struct StorageSection: View {
    var activityCount: Int
    var routeDataSize: String

    var body: some View {
        Section {
            LabeledRow(title: String(localized: "Activities"), value: String(activityCount))
            LabeledRow(title: String(localized: "Route data"), value: routeDataSize)
        } header: {
            Text("On this device")
        } footer: {
            Text("Everything Pace Up records is stored locally. Deleting the app removes this database, though your iCloud or encrypted device backup includes it, and any workouts written to Apple Health stay in Health.")
        }
    }
}

private struct BackupSection: View {
    var canExport: Bool
    var onExport: () -> Void
    var onImport: () -> Void

    var body: some View {
        Section {
            Button(action: onExport) {
                Label(String(localized: "Export All Activities"), systemImage: "square.and.arrow.up")
            }
            .disabled(!canExport)

            Button(action: onImport) {
                Label(String(localized: "Import Pace Up Backup"), systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("A backup is a readable JSON file containing your activities and routes. Importing merges it with what's already here; nothing is overwritten.")
        }
    }
}

private struct CleanupSection: View {
    @Bindable var settings: AppSettings
    var onPurgeTapped: () -> Void

    private var purgeButtonTitle: String {
        let days = settings.retentionDays
        return String(localized: "Delete Routes Older Than \(days) Days")
    }

    private var retentionLabel: String {
        let days = settings.retentionDays
        return String(localized: "\(days) days")
    }

    var body: some View {
        Section {
            Stepper(value: $settings.retentionDays, in: 7...365, step: 1) {
                HStack {
                    Text("Keep routes for")
                    Spacer()
                    Text(retentionLabel)
                        .foregroundStyle(.paceTextSecondary)
                        .monospacedDigit()
                }
            }

            Button(action: onPurgeTapped) {
                Label(purgeButtonTitle, systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.paceOrange)
            }

            Toggle(isOn: $settings.autoPurgeEnabled) {
                Text("Automatically Delete Old Routes")
            }

            if let last = settings.lastPurgeDate {
                LabeledRow(
                    title: String(localized: "Last cleanup"),
                    value: last.formatted(.relative(presentation: .named))
                )
            }
        } header: {
            Text("Cleanup")
        } footer: {
            Text("This removes GPS traces and heart-rate detail from older activities. Distance, time, pace, splits, records, streaks and totals are kept — so your Progress and Personal Records screens stay complete.")
        }
    }
}

private struct DangerSection: View {
    var retentionDays: Int
    var onDeleteOld: () -> Void
    var onDeleteAll: () -> Void

    private var deleteOldTitle: String {
        String(localized: "Delete Activities Older Than \(retentionDays) Days")
    }

    var body: some View {
        Section {
            Button(role: .destructive, action: onDeleteOld) {
                Label(deleteOldTitle, systemImage: "calendar.badge.minus")
            }

            Button(role: .destructive, action: onDeleteAll) {
                Label(String(localized: "Delete All Pace Up Data"), systemImage: "trash")
            }
        } header: {
            Text("Danger zone")
        } footer: {
            Text("Unlike the cleanup above, these remove entire activities. Lifetime totals, streaks and personal records for the deleted period will be lost. Neither touches Apple Health.")
        }
    }
}

// MARK: - Shared row

/// Plain replacement for `LabeledContent(_:value:)`.
///
/// The generic `LabeledContent` overload takes two independent `StringProtocol`
/// parameters, and resolving both inside a large `Form` is a meaningful chunk
/// of solver time for a row that is two `Text`s and a `Spacer`.
struct LabeledRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.paceTextSecondary)
        }
    }
}

// MARK: - Modifier groups

private struct Chrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.paceInk.ignoresSafeArea())
            .navigationTitle(String(localized: "Data & Privacy"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(.paceLime)
    }
}

private struct FileTransfers: ViewModifier {
    @Binding var shareItem: ShareItem?
    @Binding var showsImporter: Bool
    var onImportResult: (Result<[URL], Error>) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $shareItem) { item in
                ShareLink(item: item.url) {
                    Label(String(localized: "Share Backup"), systemImage: "square.and.arrow.up")
                }
                .presentationDetents([.height(160)])
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [.json, .data],
                allowsMultipleSelection: false,
                onCompletion: onImportResult
            )
    }
}

private struct DestructiveDialogs: ViewModifier {
    var retentionDays: Int
    var purgePreview: RetentionService.Preview?

    @Binding var showsPurge: Bool
    @Binding var showsDeleteOld: Bool
    @Binding var showsDeleteAll: Bool
    @Binding var alertMessage: String?

    var onPurge: () -> Void
    var onDeleteOld: () -> Void
    var onDeleteAll: () -> Void

    private var isAlertPresented: Binding<Bool> {
        Binding<Bool>(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

    private var purgeMessage: String {
        guard let preview = purgePreview, !preview.isEmpty else {
            return String(localized: "There are no routes older than \(retentionDays) days.")
        }
        let count = preview.activityCount
        let size = preview.formattedSize
        return String(localized: "This permanently deletes GPS routes and heart-rate detail from \(count) activities, freeing about \(size). Their distance, time, pace and splits stay. Your recent \(retentionDays) days are untouched.")
    }

    private var deleteOldMessage: String {
        String(localized: "This removes whole activities older than \(retentionDays) days, including their contribution to your lifetime totals and personal records. Apple Health is not affected.")
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "Delete old Pace Up routes?"),
                isPresented: $showsPurge,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete Old Routes"), role: .destructive, action: onPurge)
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(purgeMessage)
            }
            .confirmationDialog(
                String(localized: "Delete old activities entirely?"),
                isPresented: $showsDeleteOld,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete Activities"), role: .destructive, action: onDeleteOld)
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(deleteOldMessage)
            }
            .confirmationDialog(
                String(localized: "Delete everything?"),
                isPresented: $showsDeleteAll,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete All Data"), role: .destructive, action: onDeleteAll)
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text("Every activity, route, note and achievement in Pace Up will be permanently deleted. Workouts written to Apple Health remain in Health.")
            }
            .alert(String(localized: "Done"), isPresented: isAlertPresented) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
    }
}
