import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var workout: WatchWorkoutManager
    @EnvironmentObject private var waymarks: WatchWaymarkCenter

    var body: some View {
        Group {
            if workout.activity == nil {
                picker
            } else {
                live
            }
        }
        .sheet(item: $waymarks.encounter) { WatchEncounterView(encounter: $0) }
        .onChange(of: workout.activity) { _, activity in
            if activity == nil { waymarks.stopWorkoutTracking() } else { waymarks.startWorkoutTracking() }
        }
        .alert("Pace Up", isPresented: .constant(workout.errorMessage != nil)) { Button("OK") { workout.errorMessage = nil } } message: { Text(workout.errorMessage ?? "") }
    }


    private var picker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PACE UP").font(.caption2.bold()).foregroundStyle(.tint)
                    WatchMemoryCard()
                    Text("Ready to move?").font(.title3.bold()).padding(.top, 4)
                    ForEach(WatchActivity.allCases) { activity in
                        Button { Task { await workout.start(activity) } } label: {
                            Label(activity.title, systemImage: activity.symbol).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.bordered)
                    }
                }
            }
            .onAppear { waymarks.refreshLocation() }
        }
    }

    private var live: some View {
        TabView {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 5) {
                    Label(workout.activity?.title ?? "Workout", systemImage: workout.activity?.symbol ?? "figure.walk").font(.caption).foregroundStyle(.tint)
                    Text(duration(at: context.date)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                    HStack { metric("heart.fill", "\(Int(workout.heartRate))", "BPM"); metric("location.fill", String(format: "%.2f", workout.distance / 1000), "KM") }
                }
            }
            NavigationStack { WatchDropView() }
            WaymarkCompassView()
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
