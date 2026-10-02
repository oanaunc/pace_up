//
//  JournalView.swift
//  Pace Up
//
//  The Journal tab: every waymark you have left, on a map, in time, and the
//  capsules still waiting for you.
//

import SwiftUI
import SwiftData
import MapKit

struct JournalTab: View {
    var body: some View {
        NavigationStack {
            JournalScreen()
        }
    }
}

struct JournalScreen: View {

    enum Mode: String, CaseIterable, Identifiable {
        case map, timeline, capsules
        var id: String { rawValue }
        var title: String {
            switch self {
            case .map: return String(localized: "Map")
            case .timeline: return String(localized: "Timeline")
            case .capsules: return String(localized: "Capsules")
            }
        }
    }

    @Query(sort: \Waymark.createdAt, order: .reverse) private var waymarks: [Waymark]
    @Environment(\.modelContext) private var context

    @State private var mode: Mode = .map
    @State private var selected: Waymark?
    @State private var locator = OneShotLocator()
    @State private var composeAt: ComposeTarget?
    @State private var showsLocationError = false

    struct ComposeTarget: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let kind: WaymarkKind
    }

    private var sealed: [Waymark] { waymarks.filter { $0.isSealed() }.sorted { ($0.sealedUntil ?? .now) < ($1.sealedUntil ?? .now) } }
    private var ready: [Waymark] { waymarks.filter { $0.isWaitingToBeOpened() } }
    private var opened: [Waymark] { waymarks.filter { $0.isCapsule && $0.openedAt != nil } }
    private var onThisDay: [Waymark] { WaymarkStore(context: context).onThisDay().filter { $0.isReadable() } }
    private var totalReturns: Int { waymarks.reduce(0) { $0 + $1.visitCount } }

    var body: some View {
        ScrollView {
            VStack(spacing: PaceSpacing.l) {
                hero
                if waymarks.isEmpty {
                    emptyState
                } else {
                    if let memory = onThisDay.first { onThisDayCard(memory) }
                    if !ready.isEmpty { readyCard }
                    PillPicker(options: Mode.allCases, title: \.title, selection: $mode)
                    switch mode {
                    case .map: mapSection
                    case .timeline: timeline
                    case .capsules: capsules
                    }
                }
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, 100)
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Journal"))
        .navigationDestination(item: $selected) { WaymarkDetailView(waymark: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { drop(.note) } label: { Label(String(localized: "Note"), systemImage: WaymarkKind.note.symbolName) }
                    Button { drop(.photo) } label: { Label(String(localized: "Photo"), systemImage: WaymarkKind.photo.symbolName) }
                    Button { drop(.voice) } label: { Label(String(localized: "Voice memo"), systemImage: WaymarkKind.voice.symbolName) }
                    Button { drop(.capsule) } label: { Label(String(localized: "Time capsule"), systemImage: WaymarkKind.capsule.symbolName) }
                } label: {
                    if locator.isLocating {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .accessibilityLabel(String(localized: "Leave a waymark here"))
            }
        }
        .sheet(item: $composeAt) { target in
            WaymarkComposerView(coordinate: target.coordinate, initialKind: target.kind)
        }
        .alert(String(localized: "Couldn't find where you are"), isPresented: $showsLocationError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text("A waymark is pinned to the exact spot you're standing. Allow location for Pace Up in Settings and try again outdoors.")
        }
    }

    private func drop(_ kind: WaymarkKind) {
        guard !locator.isLocating else { return }
        Task {
            if let location = await locator.locate() {
                composeAt = ComposeTarget(coordinate: location.coordinate, kind: kind)
            } else {
                showsLocationError = true
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            FillImage(image: Image("WaymarkHero"))
                .frame(height: 230)
                .clipped()
            LinearGradient(colors: [.clear, .paceInk.opacity(0.95)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Label(String(localized: "YOUR WAYMARKS"), systemImage: "mappin.and.ellipse")
                    .font(.caption.bold())
                    .tracking(1.4)
                    .foregroundStyle(.paceLime)
                Text(waymarks.isEmpty
                     ? String(localized: "Leave something where it happened")
                     : String(localized: "\(waymarks.count) memories, pinned to the places they belong"))
                    .font(.title2.bold())
                if !waymarks.isEmpty {
                    HStack(spacing: PaceSpacing.l) {
                        stat("\(totalReturns)", String(localized: "returns"))
                        stat("\(sealed.count)", String(localized: "sealed"))
                        stat("\(opened.count)", String(localized: "opened"))
                    }
                }
            }
            .padding(PaceSpacing.l)
        }
        .clipShape(.rect(cornerRadius: PaceRadius.card))
        .overlay { RoundedRectangle(cornerRadius: PaceRadius.card).stroke(Color.white.opacity(0.1)) }
        .padding(.top, PaceSpacing.s)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.paceTextSecondary)
        }
    }

    // MARK: Cards

    private func onThisDayCard(_ waymark: Waymark) -> some View {
        Button { selected = waymark } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let data = waymark.photoData, let image = UIImage(data: data) {
                        FillImage(image: Image(uiImage: image))
                    } else {
                        FillImage(image: Image("MemoryLane"))
                    }
                }
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipped()
                LinearGradient(colors: [.clear, .paceInk.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "ON THIS DAY · \(waymark.createdAt.formatted(.dateTime.year()))"))
                        .font(.caption2.bold()).tracking(1.5).foregroundStyle(.paceLime)
                    Text(waymark.title).font(.headline)
                    Text(String(localized: "You left this \(WaymarkFormat.ago(waymark.createdAt)). Walk back and hear it again."))
                        .font(.caption).foregroundStyle(.paceTextSecondary)
                }
                .padding(PaceSpacing.l)
            }
            .clipShape(.rect(cornerRadius: PaceRadius.card))
        }
        .buttonStyle(.plain)
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            Label(String(localized: "\(ready.count) capsule\(ready.count == 1 ? "" : "s") ready to open"), systemImage: "envelope.badge.fill")
                .font(.headline)
                .foregroundStyle(.paceAmber)
            Text("Their dates have come. They open only when you walk back to where you sealed them.")
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
            ForEach(ready) { capsule in
                Button { selected = capsule } label: {
                    HStack {
                        Text(capsule.addressedTo.map { String(localized: "To \($0)") } ?? capsule.title)
                        Spacer()
                        Text(String(localized: "Sealed \(WaymarkFormat.ago(capsule.createdAt))"))
                            .font(.caption).foregroundStyle(.paceTextTertiary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.paceTextTertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PaceSpacing.l)
        .background(Color.paceAmber.opacity(0.10), in: .rect(cornerRadius: PaceRadius.card))
        .overlay { RoundedRectangle(cornerRadius: PaceRadius.card).stroke(Color.paceAmber.opacity(0.25)) }
    }

    // MARK: Map

    private var mapSection: some View {
        Map(initialPosition: .automatic) {
            ForEach(waymarks) { waymark in
                Annotation(waymark.isReadable() ? waymark.title : "", coordinate: waymark.coordinate, anchor: .center) {
                    Button { selected = waymark } label: {
                        WaymarkPin(kind: waymark.kind, isSealed: waymark.isSealed(), isWaiting: waymark.isWaitingToBeOpened())
                    }
                    .buttonStyle(.plain)
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls { MapUserLocationButton() }
        .frame(height: 380)
        .clipShape(.rect(cornerRadius: PaceRadius.card))
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: PaceSpacing.m) {
                legend(.paceLime, String(localized: "Memory"))
                legend(.paceViolet, String(localized: "Sealed"))
                legend(.paceAmber, String(localized: "Ready"))
            }
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: .capsule)
            .padding(10)
        }
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: Timeline

    private var months: [(key: Date, value: [Waymark])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: waymarks) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.createdAt)) ?? $0.createdAt
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var timeline: some View {
        LazyVStack(alignment: .leading, spacing: PaceSpacing.m) {
            ForEach(months, id: \.key) { month in
                Text(month.key.formatted(.dateTime.month(.wide).year()))
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.paceTextTertiary)
                    .padding(.top, PaceSpacing.s)
                ForEach(month.value) { waymark in
                    Button { selected = waymark } label: { WaymarkRow(waymark: waymark) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Capsules

    private var capsules: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            if sealed.isEmpty && ready.isEmpty && opened.isEmpty {
                EmptyStateView(
                    symbolName: "envelope.badge",
                    title: String(localized: "No capsules yet"),
                    message: String(localized: "Seal a message to yourself somewhere that matters. It opens on a date you choose — but only when you walk back to it.")
                )
            }
            if !sealed.isEmpty {
                SectionHeader(title: String(localized: "Sealed"))
                ForEach(sealed) { capsule in
                    Button { selected = capsule } label: { WaymarkRow(waymark: capsule) }.buttonStyle(.plain)
                }
            }
            if !opened.isEmpty {
                SectionHeader(title: String(localized: "Opened"))
                ForEach(opened) { capsule in
                    Button { selected = capsule } label: { WaymarkRow(waymark: capsule) }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.l) {
            FillImage(image: Image("JournalEmpty"))
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: PaceRadius.card))
            step(1, "mappin.and.ellipse", String(localized: "Drop a waymark mid-walk"), String(localized: "Tap Waymark on the live screen to pin a note, photo or voice memo to the exact spot."))
            step(2, "arrow.uturn.backward", String(localized: "Walk back, and it finds you"), String(localized: "Pass the same spot weeks or years later and your phone or Watch buzzes with what you left."))
            step(3, "envelope.badge.fill", String(localized: "Seal a time capsule"), String(localized: "Write to future you. It opens on the date you pick, and only when you're standing there."))
        }
    }

    private func step(_ number: Int, _ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: PaceSpacing.m) {
            Image(systemName: symbol)
                .foregroundStyle(.paceLime)
                .frame(width: 40, height: 40)
                .background(Color.paceLime.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.paceTextSecondary)
            }
        }
    }
}

struct WaymarkRow: View {
    var waymark: Waymark

    var body: some View {
        HStack(spacing: PaceSpacing.m) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(waymark.isReadable() ? waymark.title : (waymark.addressedTo.map { String(localized: "To \($0)") } ?? String(localized: "Time capsule")))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(waymark.isSealed() ? .paceViolet : .paceTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if waymark.visitCount > 0 {
                Label("\(waymark.visitCount)", systemImage: "arrow.uturn.backward")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.paceTextTertiary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.paceTextTertiary)
        }
        .padding(PaceSpacing.m)
        .paceSolidCard(cornerRadius: PaceRadius.tile)
    }

    private var subtitle: String {
        if let until = waymark.sealedUntil, waymark.isSealed() { return WaymarkFormat.opensIn(until) }
        if waymark.isWaitingToBeOpened() { return String(localized: "Ready — walk back to open") }
        return WaymarkFormat.ago(waymark.createdAt)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if waymark.isReadable(), let data = waymark.photoData, let image = UIImage(data: data) {
            FillImage(image: Image(uiImage: image))
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 12))
        } else {
            WaymarkPin(kind: waymark.kind, isSealed: waymark.isSealed(), isWaiting: waymark.isWaitingToBeOpened())
                .scaleEffect(1.3)
                .frame(width: 48, height: 48)
        }
    }
}
