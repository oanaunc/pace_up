//
//  Palette.swift
//  Pace Up
//
//  Brand colours sampled from logo.png and the UI comps.
//
//  Pace Up is a dark-first app: the comps are all dark, and the map, route
//  polylines and glass materials are tuned for a dark backdrop. The app locks
//  itself to `.dark` in `PaceUpApp`. Light-mode values are provided anyway so
//  that widgets and share sheets, which the system may render on a light
//  background, stay legible.
//

import SwiftUI

extension Color {

    /// Primary brand accent. Sampled from the UI comps (#CCED31).
    static let paceLime = Color(red: 0.800, green: 0.929, blue: 0.192)

    /// The saturated logo lime (#D1FC09). Used sparingly for the wordmark and
    /// the progress ring cap.
    static let paceLimeBright = Color(red: 0.820, green: 0.988, blue: 0.035)

    /// App background.
    static let paceInk = Color(red: 0.043, green: 0.051, blue: 0.043)

    /// Card and sheet surfaces sitting on `paceInk`.
    static let paceSurface = Color(red: 0.086, green: 0.098, blue: 0.082)

    /// Raised surface — segmented controls, list rows inside cards.
    static let paceSurfaceRaised = Color(red: 0.122, green: 0.137, blue: 0.118)

    /// Hairline separators.
    static let paceHairline = Color.white.opacity(0.08)

    // Semantic accents
    static let paceOrange = Color(red: 1.000, green: 0.541, blue: 0.122)
    static let paceRed    = Color(red: 1.000, green: 0.271, blue: 0.227)
    static let paceMint   = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let paceCyan   = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let paceViolet = Color(red: 0.655, green: 0.545, blue: 0.980)
    static let paceAmber  = Color(red: 0.984, green: 0.749, blue: 0.141)

    /// Text tiers.
    static let paceTextPrimary = Color.white
    static let paceTextSecondary = Color.white.opacity(0.62)
    static let paceTextTertiary = Color.white.opacity(0.38)
}

extension ShapeStyle where Self == Color {
    static var paceLime: Color { .paceLime }
    static var paceTextSecondary: Color { .paceTextSecondary }
}

/// Gradient used for the route polyline: lime at the start, warming to orange
/// at the current position, matching the comps.
enum PaceGradient {
    static let route = LinearGradient(
        colors: [.paceLimeBright, .paceLime, .paceAmber, .paceOrange],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let ring = AngularGradient(
        colors: [.paceLime, .paceLimeBright, .paceLime],
        center: .center
    )

    static let surfaceSheen = LinearGradient(
        colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Shared corner radii so cards, sheets and glass shapes stay consistent.
enum PaceRadius {
    static let card: CGFloat = 20
    static let tile: CGFloat = 16
    static let control: CGFloat = 14
    static let sheet: CGFloat = 28
}

enum PaceSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
