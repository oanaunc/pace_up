import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var workout: WatchWorkoutManager

    var body: some View {
        Group {
            if let screenshotMode {
                WatchStoreScreenshot(mode: screenshotMode)
            } else if workout.activity == nil {
                picker
            } else {
                live
            }
        }
        .alert("Pace Up", isPresented: .constant(workout.errorMessage != nil)) { Button("OK") { workout.errorMessage = nil } } message: { Text(workout.errorMessage ?? "") }
    }

    private var screenshotMode: String? {
        if let environmentMode = ProcessInfo.processInfo.environment["PACEUP_SCREENSHOT"] { return environmentMode }
        let arguments = ProcessInfo.processInfo.arguments
        guard let marker = arguments.firstIndex(of: "--paceup-screenshot"), arguments.indices.contains(marker + 1) else { return nil }
        return arguments[marker + 1]
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("PACE UP").font(.caption2.bold()).foregroundStyle(.green)
                Text("Ready to move?").font(.title3.bold())
                ForEach(WatchActivity.allCases) { activity in
                    Button { Task { await workout.start(activity) } } label: {
                        Label(activity.title, systemImage: activity.symbol).frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered)
                }
            }
        }
    }

    private var live: some View {
        TabView {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 5) {
                    Label(workout.activity?.title ?? "Workout", systemImage: workout.activity?.symbol ?? "figure.walk").font(.caption).foregroundStyle(.green)
                    Text(duration(at: context.date)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                    HStack { metric("heart.fill", "\(Int(workout.heartRate))", "BPM"); metric("location.fill", String(format: "%.2f", workout.distance / 1000), "KM") }
                }
            }
            VStack(spacing: 12) {
                Button { workout.togglePause() } label: { Label(workout.isPaused ? "Resume" : "Pause", systemImage: workout.isPaused ? "play.fill" : "pause.fill") }.tint(.yellow)
                Button(role: .destructive) { workout.finish(); workout.reset() } label: { Label("Finish", systemImage: "stop.fill") }
            }.buttonStyle(.borderedProminent)
        }.tabViewStyle(.page)
    }

    private func duration(at date: Date) -> String {
        let seconds = Int(workout.startedAt.map { date.timeIntervalSince($0) } ?? 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func metric(_ icon: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 1) { Image(systemName: icon).font(.caption2).foregroundStyle(.green); Text(value).font(.headline.monospacedDigit()); Text(unit).font(.system(size: 8)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
}

private struct WatchStoreScreenshot: View {
    let mode: String

    var body: some View {
        switch mode {
        case "run": live(activity: "Outdoor Run", symbol: "figure.run", time: "24:18", heart: "148", distance: "3.72")
        case "hike": live(activity: "Hike", symbol: "figure.hiking", time: "42:06", heart: "126", distance: "4.38")
        case "cycle": live(activity: "Cycle", symbol: "figure.outdoor.cycle", time: "36:42", heart: "139", distance: "12.8")
        case "controls": controls
        default: ready
        }
    }

    private var ready: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label("PACE UP", systemImage: "bolt.fill").font(.caption2.bold()).foregroundStyle(.green)
                Text("Ready to move?").font(.title3.bold())
                activityButton("Walk", "figure.walk")
                activityButton("Run", "figure.run")
                activityButton("Hike", "figure.hiking")
                activityButton("Cycle", "figure.outdoor.cycle")
            }
        }
    }

    private func activityButton(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white.opacity(0.10), in: .capsule)
    }

    private func live(activity: String, symbol: String, time: String, heart: String, distance: String) -> some View {
        VStack(spacing: 6) {
            Label(activity, systemImage: symbol).font(.caption.bold()).foregroundStyle(.green)
            Text(time).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
            HStack(spacing: 4) {
                storeMetric("heart.fill", heart, "BPM")
                storeMetric("location.fill", distance, activity == "Cycle" ? "KM" : "KM")
            }
            Text("LIVE WORKOUT").font(.system(size: 8, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Label("Outdoor Run", systemImage: "figure.run").font(.caption.bold()).foregroundStyle(.green)
            Text("24:18").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
            Label("Pause", systemImage: "pause.fill")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Color.yellow, in: .capsule).foregroundStyle(.black)
            Label("Finish", systemImage: "stop.fill")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Color.red, in: .capsule).foregroundStyle(.white)
        }
    }

    private func storeMetric(_ icon: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.green)
            Text(value).font(.headline.monospacedDigit())
            Text(unit).font(.system(size: 8)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 12))
    }
}
