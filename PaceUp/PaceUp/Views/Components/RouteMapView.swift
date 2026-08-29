//
//  RouteMapView.swift
//  Pace Up
//
//  MapKit route rendering.
//
//  Pace Up owns the route: the polyline is a sequence of coordinates the app
//  recorded itself. MapKit only supplies the backdrop, which is why no map data
//  licence or tile budget is involved.
//

import SwiftUI
import MapKit
import CoreLocation

enum PaceMapStyle: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case satellite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:  return String(localized: "Standard")
        case .hybrid:    return String(localized: "Hybrid")
        case .satellite: return String(localized: "Satellite")
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard:  return .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
        case .hybrid:    return .hybrid(elevation: .realistic)
        case .satellite: return .imagery(elevation: .realistic)
        }
    }

    var symbolName: String {
        switch self {
        case .standard:  return "map"
        case .hybrid:    return "globe.americas"
        case .satellite: return "globe.americas.fill"
        }
    }
}

struct RouteMapView: View {

    /// One entry per route. A screen showing a single activity passes one; a
    /// day with three walks passes three, and gets three polylines instead of
    /// silently dropping two of them.
    var routes: [[CLLocationCoordinate2D]]
    var style: PaceMapStyle = .standard
    var showsUserLocation: Bool = false
    var showsControls: Bool = false
    var showsEndpoints: Bool = true
    var interactionModes: MapInteractionModes = .all
    /// When set, the camera re-frames on this value changing. Used to follow a
    /// live recording without fighting the user's own panning.
    var followTrigger: Int = 0
    /// Called as the camera moves, so an owner can offer zoom controls without
    /// keeping its own copy of MapKit's state.
    var onRegionChange: ((MKCoordinateRegion) -> Void)?

    @Binding var cameraPosition: MapCameraPosition

    init(coordinates: [CLLocationCoordinate2D],
         style: PaceMapStyle = .standard,
         showsUserLocation: Bool = false,
         showsControls: Bool = false,
         showsEndpoints: Bool = true,
         interactionModes: MapInteractionModes = .all,
         followTrigger: Int = 0,
         onRegionChange: ((MKCoordinateRegion) -> Void)? = nil,
         cameraPosition: Binding<MapCameraPosition>? = nil) {
        self.init(routes: coordinates.isEmpty ? [] : [coordinates],
                  style: style,
                  showsUserLocation: showsUserLocation,
                  showsControls: showsControls,
                  showsEndpoints: showsEndpoints,
                  interactionModes: interactionModes,
                  followTrigger: followTrigger,
                  onRegionChange: onRegionChange,
                  cameraPosition: cameraPosition)
    }

    init(routes: [[CLLocationCoordinate2D]],
         style: PaceMapStyle = .standard,
         showsUserLocation: Bool = false,
         showsControls: Bool = false,
         showsEndpoints: Bool = true,
         interactionModes: MapInteractionModes = .all,
         followTrigger: Int = 0,
         onRegionChange: ((MKCoordinateRegion) -> Void)? = nil,
         cameraPosition: Binding<MapCameraPosition>? = nil) {
        self.routes = routes.filter { !$0.isEmpty }
        self.style = style
        self.showsUserLocation = showsUserLocation
        self.showsControls = showsControls
        self.showsEndpoints = showsEndpoints
        self.interactionModes = interactionModes
        self.followTrigger = followTrigger
        self.onRegionChange = onRegionChange
        if let cameraPosition {
            self._cameraPosition = cameraPosition
        } else {
            self._cameraPosition = .constant(.automatic)
        }
    }

    /// Every point across every route, for framing.
    private var allCoordinates: [CLLocationCoordinate2D] {
        routes.flatMap { $0 }
    }

    var body: some View {
        Map(position: $cameraPosition, interactionModes: interactionModes) {
            ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                if route.count > 1 {
                    // A soft dark casing underneath keeps the lime readable over
                    // pale satellite imagery and snow.
                    MapPolyline(coordinates: route)
                        .stroke(Color.black.opacity(0.45), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))

                    MapPolyline(coordinates: route)
                        .stroke(PaceGradient.route, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }

                if showsEndpoints, let start = route.first {
                    Annotation("", coordinate: start, anchor: .center) {
                        EndpointMarker(color: .paceLimeBright, symbol: "flag.fill")
                    }
                }

                if showsEndpoints, route.count > 1, let end = route.last {
                    Annotation("", coordinate: end, anchor: .center) {
                        EndpointMarker(color: .paceRed, symbol: "flag.checkered")
                    }
                }
            }

            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapStyle(style.mapStyle)
        .mapControls {
            if showsControls {
                MapCompass()
                MapScaleView()
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            onRegionChange?(context.region)
        }
        .onChange(of: followTrigger) { _, _ in
            frameRoute()
        }
        .onAppear {
            if case .automatic = cameraPosition { frameRoute() }
        }
    }

    /// Frames every route, or falls back to the user's location.
    ///
    /// The fallback matters: without it, "Recenter" on a day with no recorded
    /// route hits the `guard` and returns silently, which is indistinguishable
    /// from a dead button.
    private func frameRoute() {
        if let region = RouteMath.region(for: allCoordinates) {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(region)
            }
        } else if showsUserLocation {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
    }
}

private struct EndpointMarker: View {
    var color: Color
    var symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.paceInk)
        }
    }
}

/// Read-only map used inside cards, with interaction disabled so it does not
/// steal scroll gestures from the enclosing list.
struct StaticRouteMap: View {
    var coordinates: [CLLocationCoordinate2D]
    var style: PaceMapStyle = .standard

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        RouteMapView(
            coordinates: coordinates,
            style: style,
            showsUserLocation: false,
            showsEndpoints: true,
            interactionModes: [],
            cameraPosition: $position
        )
        .allowsHitTesting(false)
    }
}
