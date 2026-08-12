//
//  ProgressRing.swift
//  Pace Up
//

import SwiftUI

/// The step ring on the Today screen.
struct ProgressRing<Label: View>: View {

    var progress: Double
    var lineWidth: CGFloat = 18
    var trackOpacity: Double = 0.12
    @ViewBuilder var label: () -> Label

    @State private var animatedProgress: Double = 0

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    PaceGradient.ring,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .paceLime.opacity(0.35), radius: 12)

            label()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(Int(clamped * 100)) percent of goal"))
        .onAppear { animate(to: clamped) }
        .onChange(of: clamped) { _, newValue in animate(to: newValue) }
    }

    private func animate(to value: Double) {
        withAnimation(.smooth(duration: 0.9)) {
            animatedProgress = value
        }
    }
}

/// Compact ring used in list rows and the widget-style tiles.
struct MiniRing: View {
    var progress: Double
    var tint: Color = .paceLime
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    ZStack {
        Color.paceInk.ignoresSafeArea()
        ProgressRing(progress: 0.78) {
            VStack(spacing: 2) {
                Text("7,842")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("STEPS")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.paceTextSecondary)
            }
        }
        .frame(width: 220, height: 220)
    }
    .preferredColorScheme(.dark)
}
