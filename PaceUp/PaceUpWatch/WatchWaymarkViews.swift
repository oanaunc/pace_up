//
//  WatchWaymarkViews.swift
//  Pace Up Watch
//

import SwiftUI
import CoreLocation

private let lime = Color(red: 0.800, green: 0.929, blue: 0.192)
private let violet = Color(red: 0.655, green: 0.545, blue: 0.980)
private let amber = Color(red: 0.984, green: 0.749, blue: 0.141)

/// Arrow that points at the nearest memory, with distance.
struct WaymarkCompassView: View {
    @EnvironmentObject private var waymarks: WatchWaymarkCenter

    var body: some View {
        VStack(spacing: 6) {
            if let nearest = waymarks.nearest {
                Text(nearest.waymark.isReady() ? "CAPSULE READY" : "NEAREST MEMORY")
                    .font(.system(size: 10, weight: .bold)).tracking(1)
                    .foregroundStyle(nearest.waymark.isReady() ? amber : lime)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 2)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(lime)
                        .rotationEffect(.degrees(arrowAngle(bearing: nearest.bearing)))
                        .animation(.easeOut(duration: 0.3), value: waymarks.heading)
                }
                .frame(width: 76, height: 76)
                Text(distanceText(nearest.distance))
                    .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                Text(waymarks.heading == nil
                     ? "\(WatchWaymarkCenter.compassPoint(nearest.bearing)) · \(nearest.waymark.title)"
                     : nearest.waymark.title)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            } else if waymarks.waymarks.isEmpty {
                Image(systemName: "mappin.and.ellipse").font(.title2).foregroundStyle(lime)
                Text("No waymarks yet").font(.headline)
                Text("Drop one on this walk.").font(.caption2).foregroundStyle(.secondary)
            } else {
                ProgressView()
                Text("Finding you…").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// With a heading, the arrow points relative to the wrist. Without one it
    /// points relative to north, and the text gives the compass point.
    private func arrowAngle(bearing: Double) -> Double {
        bearing - (waymarks.heading ?? 0)
    }

    private func distanceText(_ metres: CLLocationDistance) -> String {
        metres < 1000 ? "\(Int(metres.rounded())) m" : String(format: "%.1f km", metres / 1000)
    }
}

/// Drop a waymark from the wrist. The text field opens dictation, so this
/// works mid-run without typing.
struct WatchDropView: View {
    @EnvironmentObject private var waymarks: WatchWaymarkCenter
    @State private var text = ""
    @State private var sealMonths: Int? = nil
    @State private var confirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("LEAVE A WAYMARK").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(lime)
                TextField("Say what happened here", text: $text)
                Picker("Seal", selection: $sealMonths) {
                    Text("Note").tag(Int?.none)
                    Text("Capsule · 6 mo").tag(Int?.some(6))
                    Text("Capsule · 1 yr").tag(Int?.some(12))
                }
                .pickerStyle(.navigationLink)
                Button {
                    let title = text.isEmpty ? "A moment" : String(text.prefix(40))
                    if waymarks.drop(title: title, text: text, sealFor: sealMonths) {
                        text = ""
                        confirmation = true
                    }
                } label: {
                    Label(sealMonths == nil ? "Pin it here" : "Seal it here",
                          systemImage: sealMonths == nil ? "mappin.and.ellipse" : "lock.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(sealMonths == nil ? lime : violet)
                .foregroundStyle(.black)
                .disabled(waymarks.location == nil)
                if waymarks.location == nil {
                    Text("Waiting for GPS…").font(.caption2).foregroundStyle(.secondary)
                }
                if waymarks.droppedThisWorkout > 0 {
                    Text("\(waymarks.droppedThisWorkout) left on this workout").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .alert("Pinned", isPresented: $confirmation) {
            Button("OK") {}
        } message: {
            Text("It will find you next time you pass here.")
        }
    }
}

/// Full-screen moment when a workout takes you back past a waymark.
struct WatchEncounterView: View {
    let encounter: WatchEncounter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Label(eyebrow, systemImage: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                Text(ago).font(.caption2).foregroundStyle(.secondary)
                switch encounter.kind {
                case .capsuleSealed(let until):
                    Text("Sealed capsule").font(.headline)
                    Text("Opens \(until.formatted(date: .abbreviated, time: .omitted)). Come back then.")
                        .font(.caption).foregroundStyle(violet)
                default:
                    Text(encounter.waymark.title).font(.headline)
                    if let text = encounter.waymark.text, !text.isEmpty, text != encounter.waymark.title {
                        Text(text).font(.body)
                    }
                    if encounter.waymark.hasPhoto || encounter.waymark.hasVoice {
                        Label(encounter.waymark.hasVoice ? "Voice memo on iPhone" : "Photo on iPhone",
                              systemImage: encounter.waymark.hasVoice ? "waveform" : "photo")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Button("Keep moving") { dismiss() }
                    .tint(lime)
                    .padding(.top, 4)
            }
        }
    }

    private var accent: Color {
        switch encounter.kind {
        case .memory: lime
        case .capsuleOpened: amber
        case .capsuleSealed: violet
        }
    }

    private var icon: String {
        switch encounter.kind {
        case .memory: "sparkles"
        case .capsuleOpened: "envelope.open.fill"
        case .capsuleSealed: "lock.fill"
        }
    }

    private var eyebrow: String {
        switch encounter.kind {
        case .memory: "YOU WERE HERE"
        case .capsuleOpened: "CAPSULE OPENED"
        case .capsuleSealed: "UNDERFOOT"
        }
    }

    private var ago: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: encounter.waymark.createdAt, relativeTo: .now)
    }
}

/// Home-screen card summarising what is out there.
struct WatchMemoryCard: View {
    @EnvironmentObject private var waymarks: WatchWaymarkCenter

    var body: some View {
        NavigationLink {
            WaymarkCompassView()
                .onAppear { waymarks.refreshLocation() }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label("Memory lane", systemImage: "mappin.and.ellipse")
                    .font(.caption.bold()).foregroundStyle(lime)
                if let nearest = waymarks.nearest {
                    Text(nearest.waymark.title).font(.headline).lineLimit(1)
                    Text("\(nearest.distance < 1000 ? "\(Int(nearest.distance)) m" : String(format: "%.1f km", nearest.distance / 1000)) \(WatchWaymarkCenter.compassPoint(nearest.bearing))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("\(waymarks.waymarks.count) waymarks").font(.headline)
                }
                if waymarks.readyCount > 0 {
                    Text("\(waymarks.readyCount) capsule ready").font(.caption2).foregroundStyle(amber)
                } else if waymarks.sealedCount > 0 {
                    Text("\(waymarks.sealedCount) sealed").font(.caption2).foregroundStyle(violet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
