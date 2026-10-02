//
//  WaymarkDetailView.swift
//  Pace Up
//

import SwiftUI
import SwiftData
import MapKit

struct WaymarkDetailView: View {

    @Bindable var waymark: Waymark

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var player = VoiceMemoPlayer()
    @State private var showsDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaceSpacing.l) {
                if waymark.isReadable() {
                    readable
                } else {
                    envelope
                }
                mapCard
                facts
                Button {
                    walkBack()
                } label: {
                    Label(String(localized: "Walk Back Here"), systemImage: "figure.walk")
                        .font(.headline)
                        .foregroundStyle(Color.paceInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.paceLime, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(PaceSpacing.l)
            .padding(.bottom, 60)
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(waymark.isReadable() ? waymark.kind.displayName : String(localized: "Capsule"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(String(localized: "Delete waymark"))
            }
        }
        .confirmationDialog(String(localized: "Delete this waymark?"), isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button(String(localized: "Delete"), role: .destructive) {
                player.stop()
                // Leave the screen first: SwiftData traps if a view reads a
                // model after it has been deleted.
                let doomed = waymark
                let store = WaymarkStore(context: context)
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    store.delete(doomed)
                }
            }
        } message: {
            Text("Its note, photo and voice memo are removed from this iPhone.")
        }
        .onDisappear { player.stop() }
    }

    // MARK: Content

    @ViewBuilder
    private var readable: some View {
        if let data = waymark.photoData, let image = UIImage(data: data) {
            FillImage(image: Image(uiImage: image))
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: PaceRadius.card))
        }

        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.bold())
                .tracking(1.4)
                .foregroundStyle(waymark.isCapsule ? .paceAmber : .paceLime)
            Text(waymark.title)
                .font(.title.bold())
            if waymark.isCapsule, let to = waymark.addressedTo {
                Text(String(localized: "To \(to)"))
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)
            }
        }

        if !waymark.body.isEmpty {
            Text(waymark.body)
                .font(.body)
                .foregroundStyle(.paceTextPrimary.opacity(0.9))
                .lineSpacing(4)
                .textSelection(.enabled)
        }

        if let file = waymark.audioFileName {
            Button {
                player.toggle(fileName: file)
            } label: {
                HStack(spacing: PaceSpacing.m) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(Color.paceInk)
                        .frame(width: 44, height: 44)
                        .background(Color.paceLime, in: .circle)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Voice memo"))
                            .font(.subheadline.weight(.semibold))
                        ProgressView(value: player.progress)
                            .tint(.paceLime)
                    }
                    if let duration = waymark.audioDuration {
                        Text(PaceFormat.clock(duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.paceTextSecondary)
                    }
                }
                .padding(PaceSpacing.m)
                .paceSolidCard(cornerRadius: PaceRadius.tile)
            }
            .buttonStyle(.plain)
        }
    }

    private var eyebrow: String {
        if waymark.isCapsule, let opened = waymark.openedAt {
            return String(localized: "Opened \(opened.formatted(date: .abbreviated, time: .omitted)) · sealed \(WaymarkFormat.ago(waymark.createdAt))")
        }
        return String(localized: "Left \(WaymarkFormat.ago(waymark.createdAt))")
    }

    private var envelope: some View {
        VStack(spacing: PaceSpacing.m) {
            FillImage(image: Image("CapsuleSealed"))
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: PaceRadius.card))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(waymark.isSealed() ? String(localized: "SEALED") : String(localized: "READY TO OPEN"),
                              systemImage: waymark.isSealed() ? "lock.fill" : "lock.open.fill")
                            .font(.caption.bold())
                            .tracking(1.4)
                            .foregroundStyle(waymark.isSealed() ? .paceViolet : .paceAmber)
                        Text(waymark.title)
                            .font(.title2.bold())
                        if let to = waymark.addressedTo {
                            Text(String(localized: "To \(to)"))
                                .font(.subheadline)
                                .foregroundStyle(.paceTextSecondary)
                        }
                    }
                    .padding(PaceSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .paceInk.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                }

            if let until = waymark.sealedUntil {
                if waymark.isSealed() {
                    CapsuleCountdown(until: until)
                    Text("Sealed \(waymark.createdAt.formatted(date: .long, time: .omitted)). Even after it unlocks, it only opens when you are standing here again.")
                        .font(.footnote)
                        .foregroundStyle(.paceTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Its date has come. Walk back to this spot during a recorded walk, run or ride and it will open.")
                        .font(.subheadline)
                        .foregroundStyle(.paceAmber)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var mapCard: some View {
        Map(initialPosition: .camera(MapCamera(centerCoordinate: waymark.coordinate, distance: 900)), interactionModes: [.zoom, .pan]) {
            Annotation("", coordinate: waymark.coordinate, anchor: .center) {
                WaymarkPin(kind: waymark.kind, isSealed: waymark.isSealed(), isWaiting: waymark.isWaitingToBeOpened())
            }
            MapCircle(center: waymark.coordinate, radius: waymark.radius)
                .foregroundStyle(Color.paceLime.opacity(0.12))
                .stroke(Color.paceLime.opacity(0.5), lineWidth: 1)
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .frame(height: 200)
        .clipShape(.rect(cornerRadius: PaceRadius.card))
    }

    private var facts: some View {
        VStack(spacing: 0) {
            factRow(symbol: "calendar", title: String(localized: "Left"), value: waymark.createdAt.formatted(date: .long, time: .shortened))
            Divider().overlay(Color.paceHairline)
            if let type = waymark.activityType {
                factRow(symbol: type.symbolName, title: String(localized: "During"), value: type.displayName)
                Divider().overlay(Color.paceHairline)
            }
            factRow(symbol: "arrow.uturn.backward", title: String(localized: "Returns"), value: waymark.visitsLabel)
            if let last = waymark.lastVisit {
                Divider().overlay(Color.paceHairline)
                factRow(symbol: "clock", title: String(localized: "Last time here"), value: WaymarkFormat.ago(last))
            }
        }
        .paceSolidCard()
    }

    private func factRow(symbol: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(.paceLime)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.paceTextSecondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(PaceSpacing.m)
    }

    private func walkBack() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: waymark.coordinate))
        item.name = waymark.isReadable() ? waymark.title : String(localized: "Time capsule")
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// Days · hours · minutes until a capsule unlocks.
struct CapsuleCountdown: View {
    var until: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let parts = Calendar.current.dateComponents([.day, .hour, .minute], from: context.date, to: until)
            HStack(spacing: PaceSpacing.s) {
                unit(max(0, parts.day ?? 0), String(localized: "days"))
                unit(max(0, parts.hour ?? 0), String(localized: "hours"))
                unit(max(0, parts.minute ?? 0), String(localized: "min"))
            }
        }
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.paceViolet)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.paceTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PaceSpacing.m)
        .background(Color.paceViolet.opacity(0.10), in: .rect(cornerRadius: PaceRadius.tile))
    }
}
