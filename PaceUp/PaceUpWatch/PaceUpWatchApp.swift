import SwiftUI

@main
struct PaceUpWatchApp: App {
    @StateObject private var workout = WatchWorkoutManager()
    @StateObject private var waymarks = WatchWaymarkCenter()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(workout)
                .environmentObject(waymarks)
                .tint(Color(red: 0.800, green: 0.929, blue: 0.192))
        }
    }
}
