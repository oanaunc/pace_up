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
                GoalSetupView { withAnimation { page = 2 } }
                    .tag(1)
                ConnectHealthView {
                    settings.hasCompletedOnboarding = true
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                PageDots(count: 3, current: page)
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
                Text("Every step\nmoves you forward.")
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
    var body: some View {
        Canvas { context, size in
            for index in 0..<14 {
                let progress = Double(index) / 14
                var path = Path()
                let amplitude = 26 + progress * 60
                let yBase = size.height * (0.08 + progress * 0.9)

                path.move(to: CGPoint(x: -20, y: yBase))
                var x: CGFloat = -20
                while x < size.width + 20 {
                    let y = yBase
                        + sin((x / size.width) * .pi * 2.4 + progress * 5) * amplitude * 0.35
                        + cos((x / size.width) * .pi * 1.3 + progress * 2) * amplitude * 0.22
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 6
                }

                context.stroke(
                    path,
                    with: .color(.paceLime.opacity(0.05 + progress * 0.10)),
                    lineWidth: 1
                )
            }
        }
        .blur(radius: 0.3)
        .accessibilityHidden(true)
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
