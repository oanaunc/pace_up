//
//  ActivitySetupView.swift
//  Pace Up
//

import SwiftUI

struct ActivitySetupView: View {

    var type: ActivityType

    @Environment(ActivityRecorder.self) private var recorder
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    enum GoalKind: String, CaseIterable, Identifiable {
        case none, distance, time, calories
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none:     return String(localized: "No Goal")
            case .distance: return String(localized: "Distance")
            case .time:     return String(localized: "Time")
            case .calories: return String(localized: "Calories")
            }
        }
    }

    @State private var goalKind: GoalKind = .none
    @State private var distanceTarget: Double = 5
    @State private var timeTarget: Double = 30
    @State private var calorieTarget: Double = 300

    var body: some View {
        VStack(spacing: PaceSpacing.l) {
            gpsStatus

            VStack(alignment: .leading, spacing: PaceSpacing.s) {
                Text("Choose a goal (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)

                VStack(spacing: 8) {
                    ForEach(GoalKind.allCases) { kind in
                        GoalRow(
                            title: kind.title,
                            detail: detail(for: kind),
                            isSelected: goalKind == kind
                        ) {
                            withAnimation(.snappy) { goalKind = kind }
                        }
                    }
                }

                if goalKind != .none {
                    goalStepper
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            PrimaryButton(title: String(localized: "START")) {
                recorder.start(type: type, goal: resolvedGoal, units: settings.units)
            }

            Label(
                recorder.signalQuality >= .fair
                    ? String(localized: "GPS accuracy is good")
                    : String(localized: "Waiting for a GPS fix — you can start anyway"),
                systemImage: recorder.signalQuality >= .fair ? "checkmark.circle" : "clock"
            )
            .font(.caption)
            .foregroundStyle(.paceTextTertiary)
        }
        .padding(.horizontal, PaceSpacing.l)
        .padding(.bottom, PaceSpacing.l)
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Outdoor \(type.displayName)"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { recorder.beginPreview(for: type) }
    }

    // MARK: Pieces

    private var gpsStatus: some View {
        HStack(spacing: 10) {
            Text("GPS")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.paceTextSecondary)

            HStack(spacing: 3) {
                ForEach(1...3, id: \.self) { bar in
                    Capsule()
                        .fill(recorder.signalQuality.bars >= bar ? Color.paceLime : Color.white.opacity(0.18))
                        .frame(width: 4, height: CGFloat(6 + bar * 4))
                }
            }

            Text(recorder.signalQuality.label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(recorder.signalQuality >= .fair ? Color.paceLime : Color.paceAmber)

            Spacer()
        }
        .padding(.top, PaceSpacing.s)
        .accessibilityElement(children: .combine)
    }

    private var goalStepper: some View {
        VStack(spacing: PaceSpacing.m) {
            switch goalKind {
            case .distance:
                Stepper(value: $distanceTarget, in: 1...50, step: 0.5) {
                    Text("\(distanceTarget, format: .number.precision(.fractionLength(1))) \(settings.units.distanceAbbreviation)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            case .time:
                Stepper(value: $timeTarget, in: 5...300, step: 5) {
                    Text("\(Int(timeTarget)) min")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            case .calories:
                Stepper(value: $calorieTarget, in: 50...2000, step: 50) {
                    Text("\(Int(calorieTarget)) kcal")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            case .none:
                EmptyView()
            }
        }
        .tint(.paceLime)
        .padding(PaceSpacing.l)
        .paceGlassCard(cornerRadius: PaceRadius.tile)
    }

    private func detail(for kind: GoalKind) -> String? {
        guard kind == goalKind, kind != .none else { return nil }
        switch kind {
        case .distance: return "\(distanceTarget.formatted(.number.precision(.fractionLength(1)))) \(settings.units.distanceAbbreviation)"
        case .time:     return "\(Int(timeTarget)) min"
        case .calories: return "\(Int(calorieTarget)) kcal"
        case .none:     return nil
        }
    }

    private var resolvedGoal: ActivityRecorder.Goal {
        switch goalKind {
        case .none:
            return .none
        case .distance:
            let metres = settings.units == .metric ? distanceTarget * 1000 : distanceTarget * 1609.344
            return .distance(metres)
        case .time:
            return .time(timeTarget * 60)
        case .calories:
            return .calories(calorieTarget)
        }
    }
}

private struct GoalRow: View {
    var title: String
    var detail: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.paceTextPrimary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.paceTextSecondary)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.paceLime : Color.paceTextTertiary)
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05), in: .rect(cornerRadius: PaceRadius.control))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
