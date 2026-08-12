//
//  PaceUpStore.swift
//  Pace Up
//
//  Model container configuration.
//
//  The store is placed in the shared App Group container from day one. Moving
//  it later would require a file migration, and the widget cannot read the
//  app's private container.
//

import Foundation
import SwiftData

enum PaceUpStore {

    static let schema = Schema([
        Activity.self,
        ActivityDetail.self,
        AchievementUnlock.self
    ])

    /// The production container, backed by the App Group.
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            "PaceUp",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A container that cannot open is unrecoverable for the app. Rather
            // than crash on a corrupt store, fall back to a fresh on-disk store
            // so the user can still record and export.
            assertionFailure("Primary store failed to open: \(error)")
            let fallback = ModelConfiguration("PaceUpRecovery", schema: schema)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    /// In-memory container for previews and tests.
    @MainActor
    static func makePreviewContainer(seeded: Bool = true) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        if seeded {
            SampleData.populate(container.mainContext)
        }
        return container
    }
}
