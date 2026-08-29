//
//  ExploreMapView.swift
//  Pace Up
//
//  Terra — the map that starts dark and clears where you have walked.
//
//  ── How the fog is drawn ──────────────────────────────────────────────────
//
//  A `Canvas` sits over the map, fills itself with fog, then switches to
//  `.destinationOut` and fills a disc per explored cell, punching the fog away.
//  Everything is a screen-space operation over cells already in memory, so
//  panning costs one projection per visible cell per frame and nothing else —
//  no route decoding, no geometry tests, no tile fetches.
//
//  Two separate cadences keep that affordable:
//
//    • `region` updates continuously, so the Canvas re-projects every frame and
//      the fog tracks the map instead of sliding behind it.
//    • `visibleCells` is recomputed only when the map has moved a meaningful
//      fraction of a screen, because filtering the whole set is O(cells) with
//      trigonometry per cell and does not need to happen at 60 Hz.
//
//  The window `visibleCells` is built from carries a margin, so the stale list
//  used mid-pan still covers the edges coming into view.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ExploreMapView: View {

    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Environment(AppSettings.self) private var settings

    @State private var store = ExplorationStore.shared
    @State private var camera: MapCameraPosition = .automatic
    @State private var region: MKCoordinateRegion?
    @State private var visibleCells: [ExplorationCell] = []
    /// Region the current `visibleCells` was culled for.
    @State private var culledFor: MKCoordinateRegion?
    /// Block size `visibleCells` was merged at. 1 means unmerged cells.
    @State private var cellScale: Int32 = 1
    @State private var mapStyle: PaceMapStyle = .standard
    @State private var hasFramed = false
    @State private var frontier: FrontierSuggestion?

    /// Drawing more than this many discs in one frame costs more than it shows;
    /// past it the fog is effectively solid anyway. Zoomed-out views hit this
    /// and simply render the first slice, which is visually indistinguishable
    /// from rendering all of them at that scale.
    private let maxDiscsPerFrame = 6_000

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
            header
            VStack {
                Spacer()
                frontierCard
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, PaceSpacing.xl)
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle("Terra")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Map style", selection: $mapStyle) {
                        ForEach(PaceMapStyle.allCases) { style in
                            Label(style.displayName, systemImage: style.symbolName).tag(style)
                        }
                    }
                } label: {
                    Image(systemName: mapStyle.symbolName)
                }
            }
        }
        .task {
            store.load()
            await store.ingest(activities)
            frameIfNeeded()
            recomputeVisibleCells()
            findFrontier()
        }
    }

    private func findFrontier() {
        // Start of the most recent route, falling back to the middle of
        // everything explored for a user whose latest activity had no GPS.
        let origin = activities.first(where: { $0.hasRoute })?.thumbnailCoordinates.first
            ?? store.explorationCenter
        guard let origin else { return }
        withAnimation(.snappy) {
            frontier = store.frontier(from: origin)
        }
    }

    // MARK: Map

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: .all) {
                UserAnnotation()
            }
            .mapStyle(mapStyle.mapStyle)
            .overlay {
                fogCanvas(proxy: proxy)
                    .allowsHitTesting(false)
            }
            .onMapCameraChange(frequency: .continuous) { context in
                region = context.region
                // One modifier, two cadences: `region` is assigned on every
                // frame so the Canvas re-projects in step with the map, but the
                // cell list is only rebuilt once the map has moved far enough
                // to be running out of margin. `MKCoordinateRegion` is not
                // Equatable, so this cannot be an `onChange`.
                if shouldRebuildCellList(for: context.region) {
                    culledFor = context.region
                    recomputeVisibleCells()
                }
            }
        }
        // All edges, not just the bottom. With `.bottom` only, the Map drew
        // under the status and navigation bars while the Canvas overlay stopped
        // at the safe-area inset, leaving an unfogged strip of live map across
        // the top of the screen.
        .ignoresSafeArea()
    }

    private func fogCanvas(proxy: MapProxy) -> some View {
        Canvas { context, size in
            let fog = Color.paceInk.opacity(0.93)
            let full = Path(CGRect(origin: .zero, size: size))

            guard let region, !visibleCells.isEmpty else {
                context.fill(full, with: .color(fog))
                return
            }

            // Metres-to-points from the visible span rather than by projecting
            // a second coordinate per cell: one division instead of thousands
            // of conversions, and exact enough at any zoom where discs are
            // larger than a pixel.
            let metresPerDegreeLatitude = 111_320.0
            let visibleMetres = region.span.latitudeDelta * metresPerDegreeLatitude
            guard visibleMetres > 0 else {
                context.fill(full, with: .color(fog))
                return
            }

            // `cellScale` blocks are `cellScale` cells wide, so their discs grow
            // in step. The floor keeps a block visible even if the culling pass
            // and the real canvas height disagree about scale.
            let radius = max(3,
                             ExplorationGrid.renderRadiusMeters
                             * Double(cellScale)
                             * size.height / visibleMetres)

            var holes = Path()
            var drawn = 0
            for cell in visibleCells {
                guard drawn < maxDiscsPerFrame else { break }
                let coordinate = ExplorationGrid.center(ofBlock: cell, factor: cellScale)
                let point = proxy.convert(coordinate, to: .local)
                    ?? Self.project(coordinate, in: region, size: size)

                // Cheap off-screen reject. The margin on the window means the
                // list contains cells beyond the edges by design.
                guard point.x > -radius, point.x < size.width + radius,
                      point.y > -radius, point.y < size.height + radius else { continue }

                holes.addEllipse(in: CGRect(x: point.x - radius,
                                            y: point.y - radius,
                                            width: radius * 2,
                                            height: radius * 2))
                drawn += 1
            }

            // Clip the holes out, then paint fog over what remains.
            //
            // This replaces a `.destinationOut` blend, which drew nothing at
            // all: erasing by blend mode depends on the fills compositing
            // against the fog inside an isolated layer, and `.compositingGroup()`
            // on the Canvas did not give it one. Clipping needs no compositing
            // behaviour and cannot silently no-op.
            //
            // It also has to be `clip`, not an even-odd fill: the discs overlap
            // by design, and under even-odd every overlap would flip back to
            // opaque and stipple the cleared corridor. Clipping unions them.
            context.clip(to: holes, options: .inverse)
            context.fill(full, with: .color(fog))
        }
    }

    /// Screen position for a coordinate, from the visible region alone.
    ///
    /// Fallback for when `MapProxy.convert` returns nil, which it does before
    /// the map has laid out. Linear in both axes: it ignores Mercator curvature
    /// and any map rotation, which is imperceptible across a city-sized span and
    /// much better than dropping the cell entirely.
    private static func project(_ coordinate: CLLocationCoordinate2D,
                                in region: MKCoordinateRegion,
                                size: CGSize) -> CGPoint {
        let latSpan = region.span.latitudeDelta
        let lonSpan = region.span.longitudeDelta
        guard latSpan > 0, lonSpan > 0 else { return CGPoint(x: -1e6, y: -1e6) }

        let x = (coordinate.longitude - (region.center.longitude - lonSpan / 2)) / lonSpan * size.width
        let y = ((region.center.latitude + latSpan / 2) - coordinate.latitude) / latSpan * size.height
        return CGPoint(x: x, y: y)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: PaceSpacing.s) {
            HStack(spacing: PaceSpacing.xl) {
                stat(value: areaText, caption: "uncovered")
                stat(value: stepsText, caption: "steps that did it")
                stat(value: streakText, caption: "explorer streak")
            }
            .padding(.vertical, PaceSpacing.m)
            .padding(.horizontal, PaceSpacing.l)
            .paceGlassCard(cornerRadius: PaceRadius.tile)

            if store.isIngesting {
                Label("Uncovering your history…", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
            } else if !store.hasExploredAnything {
                Text("Record a walk or a run and this map starts clearing.")
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaceSpacing.xl)
            } else {
                Text(stepsSentence)
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaceSpacing.xl)
            }
        }
        .padding(.horizontal, PaceSpacing.l)
        .padding(.top, PaceSpacing.s)
    }

    /// Where to go next.
    ///
    /// The origin is the start of the most recent activity rather than a live
    /// location fix: it is almost always the user's door, it needs no
    /// permission prompt on a screen that is not recording anything, and it
    /// keeps this view free of a location manager it would otherwise own.
    @ViewBuilder
    private var frontierCard: some View {
        if let frontier {
            Button {
                withAnimation(.easeInOut(duration: 0.6)) {
                    camera = .region(MKCoordinateRegion(
                        center: frontier.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            } label: {
                HStack(spacing: PaceSpacing.m) {
                    Image(systemName: "signpost.right.fill")
                        .font(.title3)
                        .foregroundStyle(.paceLime)
                        .frame(width: 40, height: 40)
                        .background(Color.paceLime.opacity(0.12), in: .circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("New ground \(distanceText(frontier.distanceMeters)) \(frontier.compassPoint)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.paceTextPrimary)
                        Text("About \(Self.areaText(frontier.estimatedNewSquareKilometres, units: settings.units)) waiting there.")
                            .font(.caption)
                            .foregroundStyle(.paceTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(.paceTextTertiary)
                }
                .padding(PaceSpacing.m)
                .contentShape(.rect)
                .paceGlassCard(cornerRadius: PaceRadius.tile)
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func distanceText(_ metres: Double) -> String {
        if settings.units == .imperial {
            let miles = metres / 1609.344
            return miles < 0.6
                ? String(format: String(localized: "%.0f yd"), metres * 1.09361)
                : String(format: String(localized: "%.1f mi"), miles)
        }
        return metres < 1000
            ? String(format: String(localized: "%.0f m"), metres)
            : String(format: String(localized: "%.1f km"), metres / 1000)
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.paceLime)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.paceTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var areaText: String {
        Self.areaText(store.exploredSquareKilometres, units: settings.units)
    }

    static func areaText(_ squareKilometres: Double, units: MeasurementUnits) -> String {
        if units == .imperial {
            let squareMiles = squareKilometres * 0.386102
            return String(format: squareMiles < 10 ? "%.2f mi²" : "%.1f mi²", squareMiles)
        }
        return String(format: squareKilometres < 10 ? "%.2f km²" : "%.1f km²", squareKilometres)
    }

    private var stepsText: String {
        let steps = store.stepsExplored
        if steps >= 1_000_000 { return String(format: "%.1fM", Double(steps) / 1_000_000) }
        if steps >= 10_000 { return "\(steps / 1_000)k" }
        return "\(steps)"
    }

    private var streakText: String {
        store.explorerStreak > 0 ? "\(store.explorerStreak)" : "—"
    }

    /// The line that binds the step counter to the map. Nothing else in the app
    /// gives a step total a spatial meaning, and it is the sentence most likely
    /// to make a user open Terra a second time.
    private var stepsSentence: String {
        let steps = store.stepsExplored
        guard steps > 0 else {
            return String(localized: "Every route you record clears a little more.")
        }
        let formatted = steps.formatted(.number.grouping(.automatic))
        return String(localized: "\(formatted) steps uncovered \(areaText).")
    }

    // MARK: Camera and culling

    private func frameIfNeeded() {
        guard !hasFramed, let center = store.explorationCenter else { return }
        hasFramed = true

        // Tight enough that a short walk is more than a speck. At the previous
        // 0.08° the whole of a 0.07 km² history fit inside a couple of discs.
        let framed = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
        camera = .region(framed)

        // Seed `region` here rather than waiting for the first camera-change
        // callback. Until that fires `region` is nil, and the Canvas has no
        // scale to draw at — so the very first frame after opening Terra was
        // solid fog with no holes in it.
        region = framed
        culledFor = framed
    }

    /// True once the map has panned or zoomed far enough that the culled list
    /// is close to running out of the margin it was built with.
    ///
    /// `MapWindow` pads by 25%, so rebuilding after a quarter-span of movement
    /// keeps a full screen of cells ahead of the user in every direction while
    /// filtering a few times per gesture rather than sixty.
    private func shouldRebuildCellList(for region: MKCoordinateRegion) -> Bool {
        guard let culledFor else { return true }

        let latMoved = abs(region.center.latitude - culledFor.center.latitude)
        let lonMoved = abs(region.center.longitude - culledFor.center.longitude)
        if latMoved > culledFor.span.latitudeDelta * 0.25 { return true }
        if lonMoved > culledFor.span.longitudeDelta * 0.25 { return true }

        // Zooming out brings in cells no pan would have reached.
        let zoomRatio = region.span.latitudeDelta / max(culledFor.span.latitudeDelta, .leastNonzeroMagnitude)
        return zoomRatio > 1.4 || zoomRatio < 0.7
    }

    private func recomputeVisibleCells() {
        guard let region else {
            visibleCells = Array(store.cells.prefix(maxDiscsPerFrame))
            cellScale = 1
            return
        }
        let window = MapWindow(
            center: region.center,
            latitudeSpan: region.span.latitudeDelta,
            longitudeSpan: region.span.longitudeDelta
        )
        let inWindow = store.cells(in: window)

        // Zoomed far enough out, individual 100 m cells fall below a pixel.
        // Drawing an arbitrary `maxDiscsPerFrame` slice of them would show a
        // random speckle rather than the shape of where the user has been, so
        // cells are merged into square blocks until one block is big enough to
        // see. The picture coarsens; it does not become a different picture.
        let visibleMetres = region.span.latitudeDelta * 111_320
        let nominalCanvasHeight = 700.0
        let radiusAtScale1 = ExplorationGrid.renderRadiusMeters * nominalCanvasHeight / max(visibleMetres, 1)

        var factor: Int32 = 1
        while radiusAtScale1 * Double(factor) < 2.0 && factor < 128 {
            factor *= 2
        }

        var merged = Self.blocks(of: inWindow, factor: factor)

        // Radius alone is not enough. Between roughly 5 and 25 km of visible
        // span, discs are still comfortably larger than a pixel while a dense
        // city can hold more cells than one frame should draw. Escalate until
        // the set fits the budget, so the cap is never reached by truncating an
        // arbitrary slice off the end of the list.
        while merged.count > maxDiscsPerFrame && factor < 128 {
            factor *= 2
            merged = Self.blocks(of: inWindow, factor: factor)
        }

        visibleCells = merged
        cellScale = factor
    }

    /// Merges cells into `factor × factor` blocks. A factor of 1 is the
    /// identity, so the caller never needs to special-case it.
    private static func blocks(of cells: [ExplorationCell], factor: Int32) -> [ExplorationCell] {
        guard factor > 1 else { return cells }
        var merged = Set<ExplorationCell>()
        merged.reserveCapacity(cells.count / Int(factor) + 1)
        for cell in cells {
            merged.insert(ExplorationGrid.block(cell, factor: factor))
        }
        return Array(merged)
    }
}

/// Entry card for the Journey tab.
struct ExploreCard: View {

    /// The card folds new activities in itself rather than waiting for the map
    /// to be opened, so the area on the Journey tab is current the first time
    /// the user sees it after a run. Ingestion is idempotent and skips anything
    /// already accounted for, so doing it here and in the map costs nothing.
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Environment(AppSettings.self) private var settings
    @State private var store = ExplorationStore.shared

    var body: some View {
        NavigationLink { ExploreMapView() } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.paceInk, .paceSurfaceRaised, .paceInk],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 150)

                // A suggestion of the thing itself: scattered cleared patches
                // over a dark ground.
                Canvas { context, size in
                    context.blendMode = .plusLighter
                    for index in 0..<26 {
                        let x = size.width * (0.06 + 0.9 * Double((index * 37) % 100) / 100)
                        let y = size.height * (0.1 + 0.8 * Double((index * 61) % 100) / 100)
                        let r = 10.0 + Double((index * 13) % 14)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(.paceLime.opacity(0.07))
                        )
                    }
                }
                .frame(height: 150)

                VStack(alignment: .leading, spacing: 6) {
                    Label("TERRA", systemImage: "map.fill")
                        .font(.caption.bold())
                        .tracking(1.4)
                        .foregroundStyle(.paceLime)
                    Text(store.hasExploredAnything ? headline : "Uncover your first ground")
                        .font(.title3.bold())
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.paceTextSecondary)
                }
                .padding(PaceSpacing.l)
            }
            .clipShape(.rect(cornerRadius: PaceRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PaceRadius.card)
                    .stroke(Color.white.opacity(0.1))
            }
        }
        .buttonStyle(.plain)
        .task {
            store.load()
            await store.ingest(activities)
        }
    }

    private var headline: String {
        String(localized: "\(ExploreMapView.areaText(store.exploredSquareKilometres, units: settings.units)) uncovered")
    }

    private var subtitle: String {
        let streak = store.explorerStreak
        if streak >= 2 {
            return String(localized: "New ground \(streak) days running.")
        }
        return String(localized: "Every route you record clears a little more of the dark.")
    }
}
