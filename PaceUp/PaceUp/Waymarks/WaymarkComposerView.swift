//
//  WaymarkComposerView.swift
//  Pace Up
//
//  Leave something where you are standing.
//
//  Opened from the live activity screen (one tap, mid-run) or from the
//  Journal. Kept short on purpose: a title is the only required field, and a
//  voice memo needs no typing at all.
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct WaymarkComposerView: View {

    var coordinate: CLLocationCoordinate2D
    var sessionID: UUID?
    var activityType: ActivityType?
    var initialKind: WaymarkKind = .note
    var onSaved: (Waymark) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: WaymarkKind = .note
    @State private var title = ""
    @State private var text = ""
    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var memo = VoiceMemoRecorder()
    @State private var sealPreset: SealPreset = .oneYear
    @State private var customSealDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var addressedTo = ""
    @FocusState private var titleFocused: Bool

    enum SealPreset: String, CaseIterable, Identifiable {
        case oneMonth, sixMonths, oneYear, fiveYears, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneMonth:  return String(localized: "1 month")
            case .sixMonths: return String(localized: "6 months")
            case .oneYear:   return String(localized: "1 year")
            case .fiveYears: return String(localized: "5 years")
            case .custom:    return String(localized: "Date")
            }
        }
    }

    private var sealDate: Date {
        let calendar = Calendar.current
        switch sealPreset {
        case .oneMonth:  return calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
        case .sixMonths: return calendar.date(byAdding: .month, value: 6, to: .now) ?? .now
        case .oneYear:   return calendar.date(byAdding: .year, value: 1, to: .now) ?? .now
        case .fiveYears: return calendar.date(byAdding: .year, value: 5, to: .now) ?? .now
        case .custom:    return customSealDate
        }
    }

    private var canSave: Bool {
        switch kind {
        case .note:    return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case .photo:   return image != nil
        case .voice:   return memo.state == .recorded
        case .capsule: return !text.trimmingCharacters(in: .whitespaces).isEmpty || image != nil || memo.state == .recorded
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PaceSpacing.l) {
                    header
                    PillPicker(options: WaymarkKind.allCases, title: \.displayName, selection: $kind)
                        .frame(maxWidth: .infinity)

                    TextField(placeholderTitle, text: $title)
                        .font(.title3.weight(.semibold))
                        .focused($titleFocused)
                        .padding(PaceSpacing.m)
                        .paceSolidCard(cornerRadius: PaceRadius.control)

                    if kind == .note || kind == .capsule {
                        textEditor
                    }
                    if kind == .photo || kind == .capsule {
                        photoSection
                    }
                    if kind == .voice || kind == .capsule {
                        voiceSection
                    }
                    if kind == .capsule {
                        sealSection
                    }

                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.paceTextTertiary)
                }
                .padding(PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background(Color.paceInk.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: kind == .capsule ? String(localized: "Seal Capsule Here") : String(localized: "Leave It Here"),
                    systemImage: kind == .capsule ? "lock.fill" : "mappin.and.ellipse",
                    isEnabled: canSave,
                    action: save
                )
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, PaceSpacing.s)
            }
            .navigationTitle(String(localized: "New Waymark"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        memo.discard()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showsCamera) {
                CameraPicker { image = $0 }.ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                        image = picked
                    }
                }
            }
            // Swiping the sheet away skips Cancel; don't leave an orphaned memo.
            .onDisappear { memo.discard() }
            .onAppear {
                kind = initialKind
                if kind == .note { titleFocused = true }
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: PaceSpacing.m) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.paceLime)
                .frame(width: 44, height: 44)
                .background(Color.paceLime.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pinned to where you stand")
                    .font(.subheadline.weight(.semibold))
                Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.paceTextTertiary)
            }
        }
    }

    private var placeholderTitle: String {
        switch kind {
        case .note:    return String(localized: "What happened here?")
        case .photo:   return String(localized: "Caption (optional)")
        case .voice:   return String(localized: "Name this memo (optional)")
        case .capsule: return String(localized: "Name the capsule")
        }
    }

    private var footnote: String {
        switch kind {
        case .capsule:
            return String(localized: "A capsule stays sealed until its date — and even then, it only opens when you walk back to this exact spot.")
        default:
            return String(localized: "This comes back to you the next time you pass here during a walk, run or ride. It never leaves your iPhone.")
        }
    }

    private var textEditor: some View {
        TextEditor(text: $text)
            .frame(minHeight: kind == .capsule ? 160 : 110)
            .scrollContentBackground(.hidden)
            .padding(PaceSpacing.s)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(kind == .capsule
                         ? String(localized: "Write to whoever opens this. Maybe you, a year from now.")
                         : String(localized: "A few words for future you…"))
                        .foregroundStyle(.paceTextTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .paceSolidCard(cornerRadius: PaceRadius.control)
    }

    private var photoSection: some View {
        Group {
            if let image {
                FillImage(image: Image(uiImage: image))
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: PaceRadius.tile))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.image = nil
                            photoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding(8)
                    }
            } else {
                HStack(spacing: PaceSpacing.s) {
                    if CameraPicker.isAvailable {
                        SecondaryButton(title: String(localized: "Camera"), systemImage: "camera.fill") {
                            showsCamera = true
                        }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(String(localized: "Library"), systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .paceGlassControl(cornerRadius: 26)
                }
            }
        }
    }

    private var voiceSection: some View {
        HStack(spacing: PaceSpacing.m) {
            Button {
                switch memo.state {
                case .recording: memo.stop()
                case .recorded: memo.discard()
                default: Task { await memo.start() }
                }
            } label: {
                Image(systemName: memo.state == .recording ? "stop.fill" : (memo.state == .recorded ? "arrow.counterclockwise" : "mic.fill"))
                    .font(.title3)
                    .foregroundStyle(Color.paceInk)
                    .frame(width: 56, height: 56)
                    .background(memo.state == .recording ? Color.paceRed : Color.paceLime, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(memo.state == .recording ? String(localized: "Stop recording") : String(localized: "Record voice memo"))

            VStack(alignment: .leading, spacing: 6) {
                Text(voiceLabel)
                    .font(.subheadline.weight(.semibold))
                LevelBars(level: memo.level, isActive: memo.state == .recording)
                    .frame(height: 18)
            }
            Spacer()
            Text(PaceFormat.clock(memo.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.paceTextSecondary)
        }
        .padding(PaceSpacing.m)
        .paceSolidCard(cornerRadius: PaceRadius.tile)
    }

    private var voiceLabel: String {
        switch memo.state {
        case .idle:      return String(localized: "Tap to record, up to 90 s")
        case .recording: return String(localized: "Recording…")
        case .recorded:  return String(localized: "Memo ready")
        case .denied:    return String(localized: "Microphone access is off in Settings")
        }
    }

    private var sealSection: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            Label(String(localized: "Seal until"), systemImage: "hourglass")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                PillPicker(options: SealPreset.allCases, title: \.label, selection: $sealPreset)
            }
            if sealPreset == .custom {
                DatePicker(String(localized: "Opens on"), selection: $customSealDate,
                           in: (Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)...,
                           displayedComponents: .date)
            } else {
                Text(String(localized: "Opens \(sealDate.formatted(date: .long, time: .omitted)), here."))
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)
            }
            TextField(String(localized: "Addressed to (e.g. Me, Ana, the kids)"), text: $addressedTo)
                .padding(PaceSpacing.m)
                .paceSolidCard(cornerRadius: PaceRadius.control)
        }
        .padding(PaceSpacing.l)
        .background(Color.paceViolet.opacity(0.10), in: .rect(cornerRadius: PaceRadius.card))
        .overlay { RoundedRectangle(cornerRadius: PaceRadius.card).stroke(Color.paceViolet.opacity(0.25)) }
    }

    // MARK: Save

    private func save() {
        if memo.state == .recording { memo.stop() }
        let audio = memo.takeFile()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle: String = {
            switch kind {
            case .note:    return String(localized: "A note")
            case .photo:   return String(localized: "A photo")
            case .voice:   return String(localized: "A voice memo")
            case .capsule: return String(localized: "Time capsule")
            }
        }()

        let waymark = Waymark(
            coordinate: coordinate,
            kind: kind,
            title: trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle,
            body: text.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: image.flatMap { WaymarkMedia.jpegData(from: $0) },
            audioFileName: audio?.name,
            audioDuration: audio?.duration,
            sealedUntil: kind == .capsule ? sealDate : nil,
            addressedTo: kind == .capsule ? (addressedTo.isEmpty ? String(localized: "Me, later") : addressedTo) : nil,
            activityID: sessionID,
            activityType: activityType
        )
        WaymarkStore(context: context).insert(waymark)
        WaymarkNotifications.requestAuthorizationIfNeeded()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaved(waymark)
        dismiss()
    }
}

/// A small live level meter for the voice recorder.
struct LevelBars: View {
    var level: Float
    var isActive: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<18, id: \.self) { index in
                let threshold = Float(index) / 18
                Capsule()
                    .fill(isActive && level > threshold ? Color.paceLime : Color.white.opacity(0.14))
                    .frame(width: 4)
            }
        }
        .animation(.linear(duration: 0.1), value: level)
    }
}
