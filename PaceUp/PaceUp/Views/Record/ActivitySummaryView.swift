//
//  ActivitySummaryView.swift
//  Pace Up
//
//  Post-activity screen. Nothing has been written to the database when this
//  appears — the user's Save is what commits it.
//

import SwiftUI
import SwiftData

struct ActivitySummaryView: View {

    var finished: FinishedActivity
    /// `true` when the activity was written, `false` when the user backed out.
    /// The caller needs the distinction: a recovered run must stay on disk if
    /// it was not saved.
    var onDismiss: (Bool) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(HealthKitManager.self) private var health
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var feeling: Int?
    @State private var showsNoteField = false
    @State private var isSaving = false
    @State private var showsDiscardConfirmation = false
    @State private var newAchievements: [AchievementKind] = []

    private let feelings: [(value: Int, symbol: String, label: String)] = [
        (1, "😣", String(localized: "Rough")),
        (2, "😐", String(localized: "Okay")),
        (3, "🙂", String(localized: "Good")),
        (4, "😀", String(localized: "Great")),
        (5, "😍", String(localized: "Amazing"))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaceSpacing.l) {
                    header
                    metrics
                    if finished.points.count > 1 {
                        routeCard
                    }
                    feelingPicker
                    if showsNoteField { noteField }
                    if !newAchievements.isEmpty { achievementBanner }
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 140)
            }
            .background(Color.paceInk.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { actions }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Discard"), role: .destructive) {
                        showsDiscardConfirmation = true
                    }
                    .foregroundStyle(.paceTextSecondary)
                }
            }
            .confirmationDialog(
                String(localized: "Discard this activity?"),
                isPresented: $showsDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Discard"), role: .destructive) {
                    onDismiss(false)
                    dismiss()
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text("This activity will not be saved.")
            }
            .onAppear {
                if title.isEmpty {
                    title = Activity.generatedTitle(for: finished.type, at: finished.startDate)
                }
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Text(finished.wasRecovered
                 ? String(localized: "Recovered activity")
                 : String(localized: "Nice \(finished.type.displayName.lowercased())! 🎉"))
                .font(.title3.weight(.semibold))
            Text(finished.wasRecovered
                 ? String(localized: "Here's what we saved before the interruption.")
                 : String(localized: "You did it."))
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)

            BigMetric(
                value: PaceFormat.distanceValue(finished.distance, units: settings.units),
                unit: settings.units.distanceAbbreviation,
                size: 60
            )
            .padding(.top, PaceSpacing.s)
        }
        .padding(.top, PaceSpacing.l)
    }

    private var metrics: some View {
        VStack(spacing: 14) {
            MetricRowItem(caption: String(localized: "Time"), value: PaceFormat.duration(finished.movingDuration))
            Divider().overlay(Color.paceHairline)
            MetricRowItem(
                caption: String(localized: "Avg Pace"),
                value: PaceFormat.pace(secondsPerKm: finished.averagePaceSecondsPerKm, units: settings.units)
            )
            Divider().overlay(Color.paceHairline)
            MetricRowItem(caption: String(localized: "Steps"), value: PaceFormat.steps(finished.steps))
            Divider().overlay(Color.paceHairline)
            MetricRowItem(caption: String(localized: "Calories"), value: "\(PaceFormat.energy(finished.activeEnergy)) kcal")
            Divider().overlay(Color.paceHairline)
            MetricRowItem(
                caption: String(localized: "Elevation"),
                value: PaceFormat.elevation(finished.elevationGain, units: settings.units)
            )
        }
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    private var routeCard: some View {
        RouteThumbnail(coordinates: finished.points.map(\.coordinate), lineWidth: 3)
            .frame(height: 150)
            .padding(PaceSpacing.l)
            .paceGlassCard()
    }

    private var feelingPicker: some View {
        VStack(spacing: PaceSpacing.m) {
            Text("How did it feel?")
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)

            HStack(spacing: PaceSpacing.m) {
                ForEach(feelings, id: \.value) { item in
                    Button {
                        withAnimation(.snappy) {
                            feeling = feeling == item.value ? nil : item.value
                        }
                    } label: {
                        Text(item.symbol)
                            .font(.system(size: 30))
                            .frame(width: 48, height: 48)
                            .background {
                                Circle()
                                    .fill(feeling == item.value ? Color.paceLime.opacity(0.22) : Color.clear)
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(feeling == item.value ? Color.paceLime : Color.clear, lineWidth: 1.5)
                            }
                            .grayscale(feeling == nil || feeling == item.value ? 0 : 0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                    .accessibilityAddTraits(feeling == item.value ? [.isSelected] : [])
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            TextField(String(localized: "Activity name"), text: $title)
                .textFieldStyle(.plain)
                .font(.headline)

            Divider().overlay(Color.paceHairline)

            TextField(String(localized: "How was it?"), text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(3...6)
        }
        .padding(PaceSpacing.l)
        .paceGlassCard()
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var achievementBanner: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            Label(String(localized: "New achievement"), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.paceLime)
            ForEach(newAchievements) { kind in
                HStack(spacing: 10) {
                    Image(systemName: kind.symbolName)
                        .foregroundStyle(kind.tint)
                    Text(kind.title)
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PaceSpacing.l)
        .background(Color.paceLime.opacity(0.10), in: .rect(cornerRadius: PaceRadius.tile))
    }

    private var actions: some View {
        VStack(spacing: PaceSpacing.s) {
            PrimaryButton(
                title: isSaving ? String(localized: "Saving…") : String(localized: "Save Activity"),
                isEnabled: !isSaving
            ) {
                save()
            }

            Button(showsNoteField
                   ? String(localized: "Hide Note")
                   : String(localized: "Add Note")) {
                withAnimation(.snappy) { showsNoteField.toggle() }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.paceTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .paceGlassControl(cornerRadius: 24)
        }
        .padding(.horizontal, PaceSpacing.l)
        .padding(.bottom, PaceSpacing.s)
        .background(.ultraThinMaterial)
    }

    /// Saving is two phases, and only the first one blocks the user.
    ///
    /// Phase one writes the activity to SwiftData and evaluates achievements —
    /// both local, both milliseconds. The run is safe at that point, so the
    /// sheet closes.
    ///
    /// Phase two reconciles with HealthKit and rewrites the widget snapshot.
    /// That involves a workout write, a route write with several thousand
    /// locations, and a batch of statistics queries; on a device with a Watch
    /// and years of history it can take seconds. Making the user watch a
    /// "Saving…" button through all of it is what made finishing a run feel
    /// broken.
    ///
    /// The `Task` below is unstructured on purpose. A `.task` modifier would be
    /// cancelled the moment the sheet dismisses, which would abandon the
    /// HealthKit write half-done.
    private func save() {
        guard !isSaving else { return }
        isSaving = true

        let store = ActivityStore(context: context)
        let activity = store.saveLocally(
            finished,
            title: title.isEmpty ? nil : title,
            note: note.isEmpty ? nil : note,
            feeling: feeling
        )

        newAchievements = AchievementEngine.evaluate(context: context, triggeredBy: activity)

        let capturedFinished = finished
        let capturedUnits = settings.units
        let capturedHealth = health
        Task {
            await store.syncWithHealth(
                activity,
                finished: capturedFinished,
                units: capturedUnits,
                health: capturedHealth
            )
        }

        isSaving = false

        guard !newAchievements.isEmpty else {
            onDismiss(true)
            dismiss()
            return
        }

        // A newly earned badge is worth a beat on screen — but a short one, and
        // it is the only thing now standing between the tap and the dismissal.
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            onDismiss(true)
            dismiss()
        }
    }
}
