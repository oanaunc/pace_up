//
//  ExplorationStore.swift
//  Pace Up
//
//  Owns the set of grid cells the user has uncovered, and the list of
//  activities already folded into it.
//
//  ── Why the ingested-ID list exists ───────────────────────────────────────
//
//  Folding is not idempotent in cost, only in result: re-folding 500 routes on
//  every launch would burn hundreds of milliseconds to arrive at exactly the
//  set already on disk. Recording which activity IDs have been folded turns
//  launch into a no-op and a finished run into ~60 points of work.
//
//  Cells are never removed. Deleting an activity, or letting the 30-day cleanup
//  purge its GPS trace, does not un-walk the ground — Terra is a record of
//  where the user has been, not a view onto the current database. The one
//  visible consequence is that `ingested` keeps the IDs of deleted activities;
//  at 16 bytes each that is not worth reconciling.
//

import Foundation
import CoreLocation

@MainActor
@Observable
final class ExplorationStore {

    static let shared = ExplorationStore()

    private(set) var state = ExplorationState()

    var cells: Set<ExplorationCell> { state.cells }
    var ingested: Set<UUID> { state.ingested }

    /// False until the first `load()` completes, so the map can show a settled
    /// empty state instead of flashing "0 km²" at every user with history.
    private(set) var isLoaded = false

    /// True while a fold is running. The first launch after this feature ships
    /// folds the user's entire history, which is the only slow case.
    private(set) var isIngesting = false

    /// Cells added by the most recent `ingest` call. Drives the "new ground"
    /// readout after a run.
    private(set) var lastRevealedCellCount = 0

    private init() {}

    // MARK: Derived

    var exploredSquareKilometres: Double {
        ExplorationGrid.areaSquareKilometres(cellCount: cells.count)
    }

    var lastRevealedSquareKilometres: Double {
        ExplorationGrid.areaSquareKilometres(cellCount: lastRevealedCellCount)
    }

    var hasExploredAnything: Bool { !cells.isEmpty }

    /// Steps taken on the activities that built this map.
    var stepsExplored: Int { Int(state.steps) }

    /// Consecutive days uncovering new ground.
    var explorerStreak: Int {
        ExplorationGrid.explorerStreak(from: state.explorerDays)
    }

    /// Days on which any new ground was uncovered, ever.
    var explorerDayCount: Int { state.explorerDays.count }

    // MARK: Storage

    private static var directory: URL {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Exploration", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var fileURL: URL {
        directory.appendingPathComponent("explored.pux")
    }

    func load() {
        guard !isLoaded else { return }
        state = ExplorationCodec.decode(try? Data(contentsOf: Self.fileURL))
        isLoaded = true
    }

    private func persist() {
        let data = ExplorationCodec.encode(state)
        // Atomic: a half-written file would decode to a partial map, and the
        // codec's truncation clamp should be the last line of defence rather
        // than the routine outcome of a kill during a save.
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: Ingestion

    /// Folds any activities not already accounted for into the explored set.
    ///
    /// Yields between activities. The work is main-actor bound because
    /// `Activity` is a SwiftData model and its route blob cannot be read from
    /// another isolation domain; yielding keeps a first-launch fold of several
    /// hundred routes from blocking the map behind it.
    @discardableResult
    func ingest(_ activities: [Activity]) async -> Int {
        load()
        guard !isIngesting else { return 0 }

        let pending = activities.filter { !ingested.contains($0.id) && $0.hasRoute }
        guard !pending.isEmpty else {
            lastRevealedCellCount = 0
            return 0
        }

        isIngesting = true
        defer { isIngesting = false }

        var revealed = 0

        for activity in pending {
            // The thumbnail, not the full trace: it is the copy that survives
            // the retention purge. See the note in ExplorationGrid.
            let coordinates = activity.thumbnailCoordinates
            state.ingested.insert(activity.id)

            guard !coordinates.isEmpty else { continue }

            let produced = ExplorationGrid.cells(along: coordinates)
            let before = state.cells.count
            state.cells.formUnion(produced)
            let gained = state.cells.count - before
            revealed += gained

            state.steps &+= UInt64(max(0, activity.steps))

            // Only days that actually uncovered something count towards the
            // explorer streak. Running the same loop every morning is a move
            // streak, which the app already tracks elsewhere; this one is
            // specifically about going somewhere new.
            if gained > 0 {
                state.explorerDays.insert(ExplorationGrid.dayKey(for: activity.startDate))
            }

            await Task.yield()
        }

        lastRevealedCellCount = revealed
        persist()
        TerraSnapshot.write(from: state)
        return revealed
    }

    /// Clears the map. Offered in Data & Privacy alongside the other local
    /// deletions, since the explored set is derived personal location history
    /// and a user clearing their routes would reasonably expect it to go too.
    func reset() {
        state = ExplorationState()
        lastRevealedCellCount = 0
        try? FileManager.default.removeItem(at: Self.fileURL)
        TerraSnapshot.clear()
    }

    /// How much of a route is ground the user has never covered.
    ///
    /// Read-only: the summary screen shows this before the activity is saved,
    /// and discarding the activity must leave the map untouched. Ingestion
    /// happens later, from the saved `Activity`.
    func previewNewGround(along coordinates: [CLLocationCoordinate2D]) -> (newCells: Int, totalCells: Int) {
        load()
        let produced = ExplorationGrid.cells(along: coordinates)
        guard !produced.isEmpty else { return (0, 0) }
        return (produced.subtracting(cells).count, produced.count)
    }

    /// Somewhere nearby worth going that the user has not been.
    ///
    /// Not run automatically. It is O(cells × 4) plus scoring, which is fine
    /// once when a screen appears and wrong inside anything that repeats.
    func frontier(from origin: CLLocationCoordinate2D) -> FrontierSuggestion? {
        load()
        return ExplorationGrid.nearestFrontier(from: origin, cells: state.cells)
    }

    // MARK: Querying

    /// Cells whose centres fall inside a coordinate window, with a margin so
    /// a cell just off-screen still contributes the half of its disc that
    /// overlaps the visible edge.
    func cells(in region: MapWindow) -> [ExplorationCell] {
        cells.filter { cell in
            let center = ExplorationGrid.center(of: cell)
            return center.latitude >= region.minLatitude
                && center.latitude <= region.maxLatitude
                && center.longitude >= region.minLongitude
                && center.longitude <= region.maxLongitude
        }
    }

    /// Centre of everything explored, used to frame the map on first open.
    var explorationCenter: CLLocationCoordinate2D? {
        guard !cells.isEmpty else { return nil }
        var latTotal = 0.0
        var lonTotal = 0.0
        for cell in cells {
            let center = ExplorationGrid.center(of: cell)
            latTotal += center.latitude
            lonTotal += center.longitude
        }
        let count = Double(cells.count)
        return CLLocationCoordinate2D(latitude: latTotal / count, longitude: lonTotal / count)
    }
}

/// A plain lat/lon window. `MKCoordinateRegion` would do, but this keeps the
/// store free of a MapKit import and is trivially testable.
struct MapWindow {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double

    init(center: CLLocationCoordinate2D, latitudeSpan: Double, longitudeSpan: Double, margin: Double = 1.25) {
        let latHalf = (latitudeSpan / 2) * margin
        let lonHalf = (longitudeSpan / 2) * margin
        minLatitude = center.latitude - latHalf
        maxLatitude = center.latitude + latHalf
        minLongitude = center.longitude - lonHalf
        maxLongitude = center.longitude + lonHalf
    }
}
