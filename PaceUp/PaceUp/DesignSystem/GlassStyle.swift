//
//  GlassStyle.swift
//  Pace Up
//
//  Every Liquid Glass call in the app funnels through this file.
//
//  iOS 26's glass APIs are new and their exact spellings are the most likely
//  thing to break a build against a future SDK. Keeping them in one place means
//  a signature change is a one-file fix rather than a hunt through fifty views.
//

import SwiftUI

extension View {

    /// Standard glass card surface.
    func paceGlassCard(cornerRadius: CGFloat = PaceRadius.card,
                       tint: Color? = nil) -> some View {
        self.glassEffect(
            tint.map { Glass.regular.tint($0.opacity(0.20)) } ?? Glass.regular,
            in: .rect(cornerRadius: cornerRadius)
        )
    }

    /// Glass surface for something the user taps, which picks up the
    /// system's touch response.
    func paceGlassControl(cornerRadius: CGFloat = PaceRadius.control,
                          tint: Color? = nil) -> some View {
        self.glassEffect(
            (tint.map { Glass.regular.tint($0.opacity(0.28)) } ?? Glass.regular).interactive(true),
            in: .rect(cornerRadius: cornerRadius)
        )
    }

    /// Circular glass control — the lock, pause and settings buttons on the
    /// live activity screen.
    func paceGlassCircle(tint: Color? = nil) -> some View {
        self.glassEffect(
            (tint.map { Glass.regular.tint($0.opacity(0.28)) } ?? Glass.regular).interactive(true),
            in: .circle
        )
    }

    /// Floating panel that sits over the map. Uses clear glass so the route
    /// stays visible underneath.
    func paceGlassPanel(cornerRadius: CGFloat = PaceRadius.sheet) -> some View {
        self.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
    }

    /// Opaque fallback surface for contexts where glass is inappropriate,
    /// such as inside a `List` row or in the widget (glass is not available
    /// in widget rendering).
    func paceSolidCard(cornerRadius: CGFloat = PaceRadius.card) -> some View {
        self
            .background(Color.paceSurface, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.paceHairline, lineWidth: 1)
            }
    }
}

/// Wrapper around `GlassEffectContainer` so callers do not have to import the
/// spacing constant, and so the container can be swapped for a plain `ZStack`
/// if a future SDK changes its behaviour.
struct PaceGlassGroup<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    }
}
