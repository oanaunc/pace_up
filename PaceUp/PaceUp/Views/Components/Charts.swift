//
//  Charts.swift
//  Pace Up
//
//  Swift Charts wrappers for the pace, elevation and heart-rate panels, plus
//  the weekly step bars.
//

import SwiftUI
import Charts

/// Weekly step bars with the goal line, as on the Progress screen.
struct WeeklyBarChart: View {

    struct Bar: Identifiable {
        var id: Int
        var label: String
        var value: Double
        var isToday: Bool
    }

    var bars: [Bar]
    var goal: Double
    var tint: Color = .paceLime
    var usesMomentumGradient = false

    private var upperBound: Double {
        max(goal * 1.08, (bars.map(\.value).max() ?? goal) * 1.18, 1)
    }

    private var average: Double {
        guard !bars.isEmpty else { return 0 }
        return bars.reduce(0) { $0 + $1.value } / Double(bars.count)
    }

    var body: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Day", bar.label),
                    y: .value("Steps", bar.value),
                    width: .ratio(0.58)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: barColors(for: bar),
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(.rect(topLeadingRadius: 7, topTrailingRadius: 7))

                if bar.isToday {
                    PointMark(x: .value("Day", bar.label), y: .value("Steps", bar.value))
                        .foregroundStyle(Color.white)
                        .symbolSize(28)
                        .annotation(position: .top) {
                            Text(PaceFormat.compactCount(Int(bar.value))).font(.caption2.bold()).foregroundStyle(.paceTextPrimary)
                        }
                }
            }

            RuleMark(y: .value("Average", average))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle((usesMomentumGradient ? Color.paceAmber : tint).opacity(0.48))
                .annotation(position: .leading, alignment: .topLeading) {
                    Text("AVG").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle((usesMomentumGradient ? Color.paceAmber : tint).opacity(0.82))
                }

            if goal > 0 {
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.24))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("GOAL \(PaceFormat.compactCount(Int(goal)))")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(.paceTextTertiary)
                    }
            }
        }
        .chartYScale(domain: 0...upperBound)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.white.opacity(0.025), in: .rect(cornerRadius: 14))
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.paceTextTertiary)
                    }
                }
            }
        }
        .frame(height: 176)
    }

    private func barColors(for bar: Bar) -> [Color] {
        guard usesMomentumGradient else {
            return bar.isToday ? [tint, tint.opacity(0.58)] : [tint.opacity(0.48), tint.opacity(0.16)]
        }
        if bar.isToday {
            return [.paceAmber, .paceOrange, .paceViolet.opacity(0.78)]
        }
        return [.paceAmber.opacity(0.50), .paceViolet.opacity(0.34), .paceViolet.opacity(0.12)]
    }
}

/// Pace over distance. Y axis is inverted because a lower number is a faster
/// pace, and a chart where "up means better" reads correctly at a glance.
struct PaceChart: View {
    var series: [(distance: Double, paceSecondsPerKm: Double)]
    var units: MeasurementUnits

    private var paces: [Double] { series.map(\.paceSecondsPerKm) }

    var body: some View {
        Chart {
            ForEach(Array(series.enumerated()), id: \.offset) { _, sample in
                AreaMark(
                    x: .value("Distance", sample.distance / 1000),
                    y: .value("Pace", sample.paceSecondsPerKm)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.paceLime.opacity(0.35), .paceLime.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Distance", sample.distance / 1000),
                    y: .value("Pace", sample.paceSecondsPerKm)
                )
                .foregroundStyle(Color.paceLime)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        // Swift Charts reverses a continuous scale when the domain is given as
        // [upper, lower]. Lower pace = faster, so this makes "up" mean "faster".
        .chartYScale(domain: [yDomain.upperBound, yDomain.lowerBound])
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(PaceFormat.paceValue(secondsPerKm: seconds, units: units))
                            .font(.caption2)
                            .foregroundStyle(.paceTextTertiary)
                    }
                }
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let km = value.as(Double.self) {
                        Text("\(Int(km))")
                            .font(.caption2)
                            .foregroundStyle(.paceTextTertiary)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    private var yDomain: ClosedRange<Double> {
        guard let low = paces.min(), let high = paces.max(), high > low else {
            return 240...480
        }
        let padding = (high - low) * 0.15 + 10
        return (low - padding)...(high + padding)
    }
}

/// Elevation profile against distance.
struct ElevationChart: View {
    var series: [(distance: Double, altitude: Double)]
    var units: MeasurementUnits

    var body: some View {
        Chart {
            ForEach(Array(series.enumerated()), id: \.offset) { _, sample in
                AreaMark(
                    x: .value("Distance", sample.distance / 1000),
                    y: .value("Elevation", displayed(sample.altitude))
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.paceMint.opacity(0.40), .paceMint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Distance", sample.distance / 1000),
                    y: .value("Elevation", displayed(sample.altitude))
                )
                .foregroundStyle(Color.paceMint)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
                .interpolationMethod(.monotone)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let elevation = value.as(Double.self) {
                        Text("\(Int(elevation))")
                            .font(.caption2)
                            .foregroundStyle(.paceTextTertiary)
                    }
                }
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let km = value.as(Double.self) {
                        Text("\(Int(km))")
                            .font(.caption2)
                            .foregroundStyle(.paceTextTertiary)
                    }
                }
            }
        }
        .frame(height: 120)
    }

    private func displayed(_ metres: Double) -> Double {
        units == .metric ? metres : metres * 3.28084
    }
}

/// Heart rate over elapsed time.
struct HeartRateChart: View {
    var samples: [HeartRateSample]

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                LineMark(
                    x: .value("Time", sample.elapsed / 60),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(Color.paceRed)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let bpm = value.as(Double.self) {
                        Text("\(Int(bpm))")
                            .font(.caption2)
                            .foregroundStyle(.paceTextTertiary)
                    }
                }
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
            }
        }
        .chartXAxis(.hidden)
        .frame(height: 110)
    }
}

/// Horizontal split bars, longest bar = slowest split.
struct SplitBars: View {
    var splits: [Split]
    var units: MeasurementUnits

    private var slowest: Double {
        max(splits.map(\.paceSecondsPerKm).max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(units == .metric ? "KM" : "MI")
                    .frame(width: 34, alignment: .leading)
                Text(String(localized: "PACE \(PaceFormat.paceUnitLabel(units).uppercased())"))
                Spacer()
            }
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.paceTextTertiary)

            ForEach(splits) { split in
                HStack(spacing: 10) {
                    Text(PaceFormat.splitLabel(split, units: units))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.paceTextSecondary)
                        .frame(width: 34, alignment: .leading)

                    Text(PaceFormat.paceValue(secondsPerKm: split.paceSecondsPerKm, units: units))
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.paceTextPrimary)
                        .frame(width: 52, alignment: .leading)

                    GeometryReader { geometry in
                        Capsule()
                            .fill(Color.paceLime)
                            .frame(
                                width: max(6, geometry.size.width * (split.paceSecondsPerKm / slowest)),
                                height: 8
                            )
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 14)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
