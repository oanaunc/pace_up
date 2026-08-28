//
//  StartActivityView.swift
//  Pace Up
//

import SwiftUI
import CoreLocation

struct StartActivityView: View {

    @Environment(ActivityRecorder.self) private var recorder

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PaceSpacing.l) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("START MOVING").font(.caption.bold()).tracking(1.8).foregroundStyle(.paceLime)
                        Text("Choose your activity").font(.title2.bold())
                        Text("Every route counts. Pick a mode and set your intention.")
                            .font(.subheadline).foregroundStyle(.paceTextSecondary)
                    }.padding(.top, PaceSpacing.s)

                    LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ActivityType.allCases) { type in
                        NavigationLink(value: type) {
                            ActivityTypeCard(type: type)
                        }
                        .buttonStyle(.plain)
                    }
                    }

                    locationNotice
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background { PacePageBackground(image: "StartTrails", imageHeight: 470, opacity: 0.42) }
            .navigationTitle(String(localized: "Start"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ActivityType.self) { type in
                ActivitySetupView(type: type)
            }
            .onAppear {
                recorder.beginPreview(for: .run)
            }
            .onDisappear {
                recorder.endPreview()
            }
        }
    }

    @ViewBuilder
    private var locationNotice: some View {
        switch recorder.authorizationStatus {
        case .notDetermined:
            NoticeCard(
                symbol: "location.circle",
                title: String(localized: "Location access needed"),
                message: String(localized: "Pace Up records your route while an activity is running, and only then."),
                actionTitle: String(localized: "Allow Location")
            ) {
                recorder.requestLocationPermission()
            }
        case .denied, .restricted:
            NoticeCard(
                symbol: "location.slash",
                title: String(localized: "Location is turned off"),
                message: String(localized: "Without location, Pace Up can still time your activity but cannot draw a route."),
                actionTitle: String(localized: "Open Settings")
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        default:
            if !recorder.hasFullAccuracy {
                NoticeCard(
                    symbol: "scope",
                    title: String(localized: "Precise location is off"),
                    message: String(localized: "Approximate location can't produce a usable route."),
                    actionTitle: String(localized: "Open Settings")
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

struct ActivityTypeCard: View {
    var type: ActivityType
    var isSelected: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(type.artworkName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .clipped()
            LinearGradient(colors: [.clear, Color.paceInk.opacity(0.92)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 7) {
                Text(type.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Circle().fill(type.tint).frame(width: 7, height: 7)
            }
            .padding(12)
        }
        .clipShape(.rect(cornerRadius: PaceRadius.tile))
        .overlay { RoundedRectangle(cornerRadius: PaceRadius.tile).strokeBorder(isSelected ? type.tint : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1) }
    }
}

struct NoticeCard: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.paceAmber)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.paceTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.paceLime)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PaceSpacing.l)
        .background(Color.paceAmber.opacity(0.10), in: .rect(cornerRadius: PaceRadius.tile))
    }
}
