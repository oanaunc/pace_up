//
//  MetricViews.swift
//  Pace Up
//
//  The small typographic building blocks the comps repeat everywhere: a big
//  number with a unit, a labelled column, a row of three stats.
//

import SwiftUI

/// Headline number with its unit set smaller and trailing, e.g. "5.24 km".
struct BigMetric: View {
    var value: String
    var unit: String?
    var size: CGFloat = 56
    var tint: Color = .paceTextPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .monospacedDigit()
            if let unit {
                Text(unit)
                    .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.paceTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Value over caption, centred. The trio under the big distance readout.
struct MetricColumn: View {
    var value: String
    var caption: String
    var tint: Color = .paceTextPrimary
    var valueSize: CGFloat = 18

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.paceTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

/// Caption over value, leading aligned. Used in the summary lists.
struct MetricRowItem: View {
    var caption: String
    var value: String
    var tint: Color = .paceTextPrimary

    var body: some View {
        HStack {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Spacer(minLength: 12)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

/// Small labelled tile used on the Profile header and Progress cards.
struct StatTile: View {
    var value: String
    var caption: String
    var tint: Color = .paceTextPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(caption)
                .font(.caption)
                .foregroundStyle(.paceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PaceSpacing.l)
        .paceGlassCard(cornerRadius: PaceRadius.tile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

/// Section heading with an optional trailing control.
struct SectionHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.paceTextPrimary)
            Spacer()
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Pill segmented control matching the comps ("All / Runs / Walks / Hikes").
struct PillPicker<Value: Hashable>: View {
    var options: [Value]
    var title: (Value) -> String
    @Binding var selection: Value

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.paceInk : Color.paceTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.paceLime)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: .capsule)
    }
}

/// Full-width primary action, the lime button used throughout the comps.
struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var tint: Color = .paceLime
    var foreground: Color = .paceInk
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint.opacity(isEnabled ? 1 : 0.35), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Secondary action rendered on glass rather than a filled capsule.
struct SecondaryButton: View {
    var title: String
    var systemImage: String?
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(role == .destructive ? Color.paceRed : Color.paceTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .paceGlassControl(cornerRadius: 26)
    }
}

/// Empty-state block: symbol, headline, one line of guidance, optional action.
struct EmptyStateView: View {
    var symbolName: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: PaceSpacing.m) {
            Image(systemName: symbolName)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.paceLime)
            Text(title)
                .font(.headline)
                .foregroundStyle(.paceTextPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
                    .tint(.paceLime)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
