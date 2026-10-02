//
//  WaymarkEncounterView.swift
//  Pace Up
//
//  The card that rises over the live map when you walk back past a waymark.
//  This is the moment the whole app exists for, so it gets the most care.
//

import SwiftUI
import SwiftData

struct WaymarkEncounterView: View {

    var encounter: WaymarkEncounter
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var context
    @State private var player = VoiceMemoPlayer()
    @State private var revealed = false

    private var waymark: Waymark? {
        WaymarkStore(context: context).waymark(id: encounter.waymarkID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            eyebrow

            switch encounter.kind {
            case .capsuleSealed(let until):
                sealed(until: until)
            case .capsuleOpened:
                if revealed { content } else { envelope }
            case .memory:
                content
            }

            HStack {
                Text(visitsCopy)
                    .font(.caption)
                    .foregroundStyle(.paceTextTertiary)
                Spacer()
                Button(String(localized: "Keep moving")) {
                    player.stop()
                    onDismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.paceLime)
            }
        }
        .padding(PaceSpacing.l)
        .background {
            ZStack {
                Color.paceSurface.opacity(0.92)
                LinearGradient(colors: [accent.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
            }
        }
        .clipShape(.rect(cornerRadius: PaceRadius.sheet))
        .overlay { RoundedRectangle(cornerRadius: PaceRadius.sheet).stroke(accent.opacity(0.35)) }
        .shadow(color: accent.opacity(0.25), radius: 24)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }

    private var accent: Color {
        switch encounter.kind {
        case .memory: return .paceLime
        case .capsuleOpened: return .paceAmber
        case .capsuleSealed: return .paceViolet
        }
    }

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(eyebrowText.uppercased())
                .tracking(1.4)
        }
        .font(.caption.bold())
        .foregroundStyle(accent)
    }

    private var icon: String {
        switch encounter.kind {
        case .memory: return "sparkles"
        case .capsuleOpened: return "envelope.open.fill"
        case .capsuleSealed: return "lock.fill"
        }
    }

    private var eyebrowText: String {
        let ago = WaymarkFormat.ago(encounter.createdAt)
        switch encounter.kind {
        case .memory: return String(localized: "You were here · \(ago)")
        case .capsuleOpened: return String(localized: "Capsule unlocked · sealed \(ago)")
        case .capsuleSealed: return String(localized: "Sealed capsule underfoot")
        }
    }

    private var visitsCopy: String {
        switch encounter.previousVisits {
        case 0: return String(localized: "First time back")
        case 1: return String(localized: "Second time back")
        default: return String(localized: "Back \(encounter.previousVisits + 1) times now")
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let waymark {
            if let data = waymark.photoData, let image = UIImage(data: data) {
                FillImage(image: Image(uiImage: image))
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: PaceRadius.tile))
            }
            Text(waymark.title)
                .font(.title3.bold())
            if let to = waymark.addressedTo, waymark.isCapsule {
                Text(String(localized: "To \(to) — from you, \(waymark.createdAt.formatted(date: .long, time: .omitted))"))
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
            }
            if !waymark.body.isEmpty {
                // Sized to the text: a ScrollView here claimed its full
                // maximum height and left a gap under short notes.
                Text(waymark.body)
                    .font(.body)
                    .foregroundStyle(.paceTextSecondary)
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let file = waymark.audioFileName {
                Button {
                    player.toggle(fileName: file)
                } label: {
                    HStack {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        Text(player.isPlaying ? String(localized: "Playing your memo") : String(localized: "Play your memo"))
                        Spacer()
                        if let duration = waymark.audioDuration {
                            Text(PaceFormat.clock(duration)).monospacedDigit()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(PaceSpacing.m)
                    .background(Color.paceLime.opacity(0.14), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(encounter.title).font(.title3.bold())
        }
    }

    private var envelope: some View {
        Button {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { revealed = true }
        } label: {
            VStack(spacing: PaceSpacing.s) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.paceAmber)
                    .symbolEffect(.bounce, options: .repeating.speed(0.4))
                Text(encounter.title)
                    .font(.headline)
                Text("You walked back. Tap to open.")
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PaceSpacing.l)
        }
        .buttonStyle(.plain)
    }

    private func sealed(until: Date) -> some View {
        HStack(spacing: PaceSpacing.m) {
            FillImage(image: Image("CapsuleSealed"))
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.title)
                    .font(.headline)
                Text(WaymarkFormat.opensIn(until))
                    .font(.subheadline)
                    .foregroundStyle(.paceViolet)
                Text("Come back here after \(until.formatted(date: .abbreviated, time: .omitted)) to open it.")
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
            }
        }
    }
}
