import SwiftUI

@main
struct PaceUpWatchApp: App {
    @StateObject private var workout = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchHomeView().environmentObject(workout).tint(Color.green)
        }
    }
}
