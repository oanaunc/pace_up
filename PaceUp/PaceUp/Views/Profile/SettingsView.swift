//
//  SettingsView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(HealthKitManager.self) private var health
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section(String(localized: "Units")) {
                Picker(String(localized: "Distance"), selection: $settings.units) {
                    ForEach(MeasurementUnits.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle(String(localized: "Auto-pause"), isOn: $settings.autoPauseEnabled)
                Toggle(String(localized: "Keep screen awake"), isOn: $settings.keepScreenAwake)
            } header: {
                Text("Recording")
            } footer: {
                Text("Auto-pause stops the timer when you stop moving and resumes when you set off again.")
            }

            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(healthStatusText)
                        .foregroundStyle(.paceTextSecondary)
                }
                if health.authorizationState != .authorized {
                    Button(String(localized: "Connect Apple Health")) {
                        Task { await health.requestAuthorization() }
                    }
                }
                Button(String(localized: "Open Health Settings")) {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("iOS never tells an app which Health permissions were granted. If your steps look wrong, check Pace Up's access in the Health app under Sharing.")
            }

            Section(String(localized: "Goal")) {
                NavigationLink {
                    StepGoalView()
                } label: {
                    HStack {
                        Text("Daily step goal")
                        Spacer()
                        Text(PaceFormat.steps(settings.dailyStepGoal))
                            .foregroundStyle(.paceTextSecondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    DataPrivacyView()
                } label: {
                    Label(String(localized: "Data & Privacy"), systemImage: "lock.shield")
                }
            }

            Section {
                HStack {
                    Text("Maps")
                    Spacer()
                    Text("Apple MapKit")
                        .foregroundStyle(.paceTextSecondary)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Pace Up has no account, no server and no analytics. Routes are recorded on your device and drawn over Apple Maps.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(.paceLime)
    }

    private var healthStatusText: String {
        switch health.authorizationState {
        case .authorized:    return String(localized: "Connected")
        case .denied:        return String(localized: "Denied")
        case .notDetermined: return String(localized: "Not connected")
        case .unavailable:   return String(localized: "Unavailable")
        case .unknown:       return String(localized: "Unknown")
        }
    }
}
