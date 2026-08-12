//
//  GoalSetupView.swift
//  Pace Up
//

import SwiftUI

struct GoalSetupView: View {

    @Environment(AppSettings.self) private var settings
    var onContinue: () -> Void

    @State private var selectedGoal: PrimaryGoal?
    @State private var stepGoal: Double = 10000

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaceSpacing.xl) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's your goal?")
                        .font(.largeTitle.bold())
                    Text("We'll help you stay consistent and reach it.")
                        .font(.subheadline)
                        .foregroundStyle(.paceTextSecondary)
                }
                .padding(.top, 64)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PrimaryGoal.allCases) { goal in
                        GoalCard(goal: goal, isSelected: selectedGoal == goal) {
                            withAnimation(.snappy) {
                                selectedGoal = goal
                                stepGoal = Double(goal.suggestedStepGoal)
                            }
                        }
                    }
                }

                VStack(spacing: PaceSpacing.m) {
                    Text("Daily step goal")
                        .font(.subheadline)
                        .foregroundStyle(.paceTextSecondary)

                    HStack(spacing: PaceSpacing.xl) {
                        StepperButton(symbol: "minus") {
                            stepGoal = max(1000, stepGoal - 500)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(Int(stepGoal).formatted())
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("steps")
                                .font(.subheadline)
                                .foregroundStyle(.paceTextSecondary)
                        }
                        StepperButton(symbol: "plus") {
                            stepGoal = min(30000, stepGoal + 500)
                        }
                    }

                    Slider(value: $stepGoal, in: 5000...20000, step: 500)
                        .tint(.paceLime)

                    HStack {
                        ForEach([5, 7, 10, 15, 20], id: \.self) { thousands in
                            Text("\(thousands)K")
                                .font(.caption2)
                                .foregroundStyle(.paceTextTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(PaceSpacing.l)
                .paceGlassCard()

                Spacer(minLength: 20)

                PrimaryButton(title: String(localized: "Continue")) {
                    settings.primaryGoal = selectedGoal
                    settings.dailyStepGoal = Int(stepGoal)
                    onContinue()
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, PaceSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            stepGoal = Double(settings.dailyStepGoal)
            selectedGoal = settings.primaryGoal
        }
    }
}

private struct GoalCard: View {
    var goal: PrimaryGoal
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: goal.symbolName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.paceLime : Color.paceTextSecondary)
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.paceTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(PaceSpacing.l)
            .background {
                RoundedRectangle(cornerRadius: PaceRadius.tile)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: PaceRadius.tile)
                            .strokeBorder(
                                isSelected ? Color.paceLime : Color.paceHairline,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct StepperButton: View {
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.paceTextPrimary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .paceGlassCircle()
    }
}
