//
//  StartActivityView.swift
//  Pace Up
//

import SwiftUI
import CoreLocation

struct StartActivityView: View {

    @Environment(ActivityRecorder.self) private var recorder

    @State private var showsMoreTypes = false

    private var visibleTypes: [ActivityType] {
        showsMoreTypes ? ActivityType.allCases : [.walk, .run, .hike]
    }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: PaceSpacing.xl) {
                Text("What do you want to do?")
                    .font(.largeTitle.bold())
                    .padding(.top, PaceSpacing.l)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleTypes) { type in
                        NavigationLink(value: type) {
                            ActivityTypeCard(type: type)
                        }
                        .buttonStyle(.plain)
                    }

                    if !showsMoreTypes {
                        Button {
                            withAnimation(.snappy) { showsMoreTypes = true }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "ellipsis")
                                    .font(.title)
                                    .foregroundStyle(.paceTextSecondary)
                                Text("More")
                                    .font(.headline)
                                    .foregroundStyle(.paceTextPrimary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 96)
                            .padding(PaceSpacing.l)
                            .paceGlassCard(cornerRadius: PaceRadius.tile)
                        }
                        .buttonStyle(.plain)
                    }
                }

                locationNotice

                Spacer()
            }
            .padding(.horizontal, PaceSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paceInk.ignoresSafeArea())
            .navigationTitle(String(localized: "Start Activity"))
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
        VStack(spacing: 10) {
            Image(systemName: type.symbolName)
                .font(.title)
                .foregroundStyle(type.tint)
            Text(type.displayName)
                .font(.headline)
                .foregroundStyle(.paceTextPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(PaceSpacing.l)
        .background {
            RoundedRectangle(cornerRadius: PaceRadius.tile)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: PaceRadius.tile)
                        .strokeBorder(isSelected ? type.tint : Color.paceHairline, lineWidth: isSelected ? 1.5 : 1)
                }
        }
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
