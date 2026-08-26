//
//  ConnectHealthView.swift
//  Pace Up
//

import SwiftUI

struct ConnectHealthView: View {

    @Environment(HealthKitManager.self) private var health
    var onFinish: () -> Void

    @State private var isRequesting = false

    private let readItems: [(String, String)] = [
        ("figure.walk", String(localized: "Steps")),
        ("figure.run", String(localized: "Walking + Running Distance")),
        ("figure.mixed.cardio", String(localized: "Workouts")),
        ("heart.fill", String(localized: "Heart Rate")),
        ("flame.fill", String(localized: "Active Energy"))
    ]

    var body: some View {
        VStack(spacing: PaceSpacing.xl) {
            Spacer()

            VStack(spacing: PaceSpacing.l) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.paceRed)
                    .frame(width: 74, height: 74)
                    .background(Color.white, in: .rect(cornerRadius: 18))

                Text("Connect Health")
                    .font(.title.bold())

                Text("Pace Up uses HealthKit to securely read your activity data.")
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaceSpacing.xl)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(readItems, id: \.1) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0)
                            .font(.subheadline)
                            .foregroundStyle(.paceLime)
                            .frame(width: 22)
                        Text(item.1)
                            .font(.subheadline)
                            .foregroundStyle(.paceTextPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: PaceSpacing.m) {
                if health.isAvailable {
                    // Guideline 5.1.1(iv): this screen explains *why* Pace Up
                    // asks for Health data, so its only action must be to show
                    // the system permission sheet. There is deliberately no
                    // "Not now" escape — a custom screen may not stand in for
                    // the system prompt or let the user defer it. Declining
                    // happens in the sheet itself, where iOS records the
                    // choice, and the app continues either way.
                    PrimaryButton(
                        title: isRequesting
                            ? String(localized: "Connecting…")
                            : String(localized: "Continue"),
                        isEnabled: !isRequesting
                    ) {
                        Task {
                            isRequesting = true
                            await health.requestAuthorization()
                            isRequesting = false
                            onFinish()
                        }
                    }

                    Text("Pace Up works either way. If you decline, activities are recorded with GPS only, and you can change this later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.paceTextTertiary)
                        .multilineTextAlignment(.center)
                } else {
                    // Health data is unavailable in some regions and on some
                    // devices. There is no permission to request, so the button
                    // simply continues.
                    Text("Health data isn't available on this device. You can still record activities with GPS.")
                        .font(.footnote)
                        .foregroundStyle(.paceTextSecondary)
                        .multilineTextAlignment(.center)

                    PrimaryButton(title: String(localized: "Continue")) {
                        onFinish()
                    }
                }
            }
            .padding(.horizontal, PaceSpacing.xl)
            .padding(.bottom, 60)
        }
    }
}
