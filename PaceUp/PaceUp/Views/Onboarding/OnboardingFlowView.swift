//
//  OnboardingFlowView.swift
//  Pace Up
//
//  Three screens, no account.
//
//  Because there is no sign-up, no email verification and no password, the
//  whole flow is: say hello, pick a goal, grant Health. Location is requested
//  later, at the moment the user first taps Start, where the reason for it is
//  self-evident — asking for location on a welcome screen is how apps get
//  denied.
//

import SwiftUI

struct OnboardingFlowView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(HealthKitManager.self) private var health

    @State private var page = 0

    var body: some View {
        ZStack {
            Color.paceInk.ignoresSafeArea()
            ContourBackground()
                .ignoresSafeArea()
                .opacity(page == 0 ? 1 : 0.25)
                .animation(.smooth(duration: 0.6), value: page)

            TabView(selection: $page) {
                WelcomeView { withAnimation { page = 1 } }
                    .tag(0)
                WaymarksIntroView { withAnimation { page = 2 } }
                    .tag(1)
                GoalSetupView { withAnimation { page = 3 } }
                    .tag(2)
                ConnectHealthView {
                    settings.hasCompletedOnboarding = true
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                PageDots(count: 4, current: page)
                    .padding(.bottom, 14)
            }
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: PaceSpacing.m) {
                LogoWordmark()
                Text("Leave memories where they happened.\nWalk back, and they find you.")
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: PaceSpacing.s) {
                PrimaryButton(title: String(localized: "Get Started"), action: onContinue)

                Text("No account needed. Your data stays on your device.")
                    .font(.caption)
                    .foregroundStyle(.paceTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PaceSpacing.xl)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Waymarks

/// The concept page. Pace Up is a walking journal first; the tracker exists to
/// bring people back to the places they marked.
struct WaymarksIntroView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                FillImage(image: Image("WaymarkOnboarding"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .clipped()
                LinearGradient(colors: [.clear, .paceInk], startPoint: .center, endPoint: .bottom)
            }
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: PaceSpacing.l) {
                Text("Your walks remember")
                    .font(.largeTitle.bold())
                row("mappin.and.ellipse", "Drop a waymark", "Pin a note, photo or voice memo to the exact spot, mid-walk.")
                row("applewatch.radiowaves.left.and.right", "It finds you again", "Pass that spot months later and your iPhone or Apple Watch taps you with it.")
                row("envelope.badge.fill", "Seal time capsules", "Write to future you. It opens on its date — and only where you left it.")
            }
            .padding(.horizontal, PaceSpacing.xl)

            Spacer()

            PrimaryButton(title: String(localized: "Continue"), action: onContinue)
                .padding(.horizontal, PaceSpacing.xl)
                .padding(.bottom, 60)
        }
    }

    private func row(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: PaceSpacing.m) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.paceLime)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.paceTextSecondary)
            }
        }
    }
}

/// The Pace Up wordmark. Falls back to text if the logo asset is missing so a
/// misconfigured asset catalogue never ships a blank first screen.
struct LogoWordmark: View {
    var size: CGFloat = 132

    var body: some View {
        Group {
            if UIImage(named: "PaceUpLogo") != nil {
                Image("PaceUpLogo")
                    .resizable()
                    .scaledToFit()
            } else {
                HStack(spacing: 6) {
                    Text("Pace")
                        .foregroundStyle(.paceTextPrimary)
                    Text("Up")
                        .foregroundStyle(.paceLime)
                }
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .italic()
            }
        }
        .frame(height: size)
        .accessibilityLabel("Pace Up")
    }
}

/// The topographic line motif from the splash comp, drawn rather than shipped
/// as an image so it scales to any device without extra assets.
struct ContourBackground: View {

    private static let lineCount = 14

    // Everything below is deliberately annotated as `Double` and the path is
    // built in a separate function. The original one-expression version mixed
    // CGFloat and Double across a chain of sin/cos and multiplications, and the
    // implicit CGFloat↔Double conversions gave the type checker a combinatorial
    // number of candidate overloads to try — enough that it gave up with
    // "unable to type-check this expression in reasonable time".
    var body: some View {
        Canvas { context, size in
            let width = Double(size.width)
            let height = Double(size.height)
            guard width > 0 else { return }

            for index in 0..<Self.lineCount {
                let progress = Double(index) / Double(Self.lineCount)
                let amplitude: Double = 26 + progress * 60
                let yBase: Double = height * (0.08 + progress * 0.9)
                let opacity: Double = 0.05 + progress * 0.10

                let path = Self.contourPath(
                    width: width,
                    yBase: yBase,
                    amplitude: amplitude,
                    progress: progress
                )

                context.stroke(
                    path,
                    with: .color(.paceLime.opacity(opacity)),
                    lineWidth: 1
                )
            }
        }
        .blur(radius: 0.3)
        .accessibilityHidden(true)
    }

    private static func contourPath(width: Double,
                                    yBase: Double,
                                    amplitude: Double,
                                    progress: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: -20, y: yBase))

        var x: Double = -20
        while x < width + 20 {
            let phase: Double = x / width
            let wave: Double = sin(phase * .pi * 2.4 + progress * 5) * amplitude * 0.35
            let ripple: Double = cos(phase * .pi * 1.3 + progress * 2) * amplitude * 0.22
            path.addLine(to: CGPoint(x: x, y: yBase + wave + ripple))
            x += 6
        }

        return path
    }
}

struct PageDots: View {
    var count: Int
    var current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.paceLime : Color.white.opacity(0.22))
                    .frame(width: index == current ? 18 : 6, height: 6)
                    .animation(.snappy, value: current)
            }
        }
        .accessibilityHidden(true)
    }
}
