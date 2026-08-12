//
//  RouteThumbnail.swift
//  Pace Up
//
//  Route glyphs for list rows and grids.
//
//  Drawn with `Canvas` rather than `Map`. The activity list can show dozens of
//  routes at once; dozens of live MKMapViews would stall scrolling and burn
//  battery for images the size of a postage stamp. The simplified thumbnail
//  route stored on every activity is exactly what this needs, and it survives
//  the 30-day purge, so old rows keep their glyph.
//

import SwiftUI
import CoreLocation

struct RouteThumbnail: View {

    var coordinates: [CLLocationCoordinate2D]
    var lineWidth: CGFloat = 2.5
    var showsEndpoints: Bool = true
    var gradient: [Color] = [.paceLimeBright, .paceLime, .paceOrange]

    var body: some View {
        Canvas { context, size in
            guard coordinates.count > 1 else { return }
            let points = normalized(in: size)
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: gradient),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            if showsEndpoints, let first = points.first, let last = points.last {
                let dot = lineWidth * 1.6
                context.fill(
                    Path(ellipseIn: CGRect(x: first.x - dot, y: first.y - dot, width: dot * 2, height: dot * 2)),
                    with: .color(.paceLimeBright)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: last.x - dot, y: last.y - dot, width: dot * 2, height: dot * 2)),
                    with: .color(.paceOrange)
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// Maps coordinates into the drawing rect, preserving aspect ratio so a
    /// long straight out-and-back does not get stretched into a blob.
    private func normalized(in size: CGSize) -> [CGPoint] {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard
            let minLat = latitudes.min(), let maxLat = latitudes.max(),
            let minLon = longitudes.min(), let maxLon = longitudes.max()
        else { return [] }

        let inset: CGFloat = lineWidth * 2 + 2
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)

        // Longitude degrees shrink with latitude; correcting keeps the shape
        // honest instead of squashed east–west.
        let latitudeCorrection = cos((minLat + maxLat) / 2 * .pi / 180)
        let spanLat = max(maxLat - minLat, 0.00001)
        let spanLon = max((maxLon - minLon) * latitudeCorrection, 0.00001)

        let scale = min(width / spanLon, height / spanLat)
        let drawnWidth = spanLon * scale
        let drawnHeight = spanLat * scale
        let offsetX = inset + (width - drawnWidth) / 2
        let offsetY = inset + (height - drawnHeight) / 2

        return coordinates.map { coordinate in
            let x = (coordinate.longitude - minLon) * latitudeCorrection * scale + offsetX
            // Flip: latitude increases north, screen y increases down.
            let y = drawnHeight - (coordinate.latitude - minLat) * scale + offsetY
            return CGPoint(x: x, y: y)
        }
    }
}

/// Placeholder for activities whose route was purged or never recorded.
struct RouteThumbnailPlaceholder: View {
    var symbolName: String = "map"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.paceTextTertiary)
        }
    }
}
