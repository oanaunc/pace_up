//
//  WaymarkDemoSeed.swift
//  Pace Up
//
//  Debug builds only. Launch with `-PaceUpDemoWaymarks YES` (Edit Scheme →
//  Arguments) to fill an empty store with a believable year of waymarks
//  around Cișmigiu Gardens, Bucharest, so App Store screenshots show the real
//  app with real data rather than mock-ups.
//
//  Waymarks are placed around the first location fix, so on a phone or a
//  simulator the bench note sits exactly where you are: tap Start → Walk →
//  START and "You were here · a year ago" surfaces on the first fix.
//

#if DEBUG
import Foundation
import SwiftData
import CoreLocation
import UIKit

enum WaymarkDemoSeed {

    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "PaceUpDemoWaymarks")
    }

    /// Seeds around wherever the device (or simulator) is, so the "You were
    /// here" moment fires on the first walk without setting a custom location.
    /// Falls back to Cișmigiu if no fix arrives.
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        guard isRequested, WaymarkStore(context: context).all().isEmpty else { return }
        Task { @MainActor in
            let fix = await OneShotLocator().locate()
            seed(context: context, around: fix?.coordinate ?? CLLocationCoordinate2D(latitude: 44.4362, longitude: 26.0904))
        }
    }

    @MainActor
    private static func seed(context: ModelContext, around anchor: CLLocationCoordinate2D) {
        let store = WaymarkStore(context: context)
        guard store.all().isEmpty else { return }

        let calendar = Calendar.current
        func ago(days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: .now) ?? .now }
        func ahead(days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: .now) ?? .now }
        func photo(_ name: String) -> Data? { UIImage(named: name).flatMap { WaymarkMedia.jpegData(from: $0, maxDimension: 1200) } }
        // Offsets are authored relative to Cișmigiu (44.4362, 26.0904) and
        // shifted onto the anchor.
        func at(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: anchor.latitude + (lat - 44.4362),
                                   longitude: anchor.longitude + (lon - 26.0904))
        }

        let items: [Waymark] = [
            Waymark(createdAt: ago(days: 365), coordinate: at(44.4362, 26.0904), kind: .note,
                    title: "The bench where I decided to move here",
                    body: "Sat here for an hour with cold coffee and finally said yes to the job. Scared and happy. If you're reading this again, I hope it was worth it.",
                    activityType: .walk),
            Waymark(createdAt: ago(days: 212), coordinate: at(44.4371, 26.0921), kind: .photo,
                    title: "First snow on the lake", body: "", photoData: photo("WaymarkHero"),
                    activityType: .run),
            Waymark(createdAt: ago(days: 160), coordinate: at(44.4349, 26.0889), kind: .note,
                    title: "Ran the whole loop without stopping",
                    body: "Three laps. In March I couldn't do one.", activityType: .run),
            Waymark(createdAt: ago(days: 98), coordinate: at(44.4386, 26.0935), kind: .capsule,
                    title: "For after the exams", body: "",
                    sealedUntil: ahead(days: 94), addressedTo: "Me, next summer", activityType: .walk),
            Waymark(createdAt: ago(days: 400), coordinate: at(44.4355, 26.0942), kind: .capsule,
                    title: "One year on",
                    body: "Hi, future me. Are you still walking here on Sundays? Did you call Grandma more? Go get a covrig and sit by the water for a bit.",
                    sealedUntil: ago(days: 35), addressedTo: "Me, in a year", activityType: .walk),
            Waymark(createdAt: ago(days: 45), coordinate: at(44.4340, 26.0915), kind: .capsule,
                    title: "For Ana", body: "",
                    sealedUntil: ahead(days: 320), addressedTo: "Ana", activityType: .walk),
            Waymark(createdAt: ago(days: 30), coordinate: at(44.4378, 26.0896), kind: .photo,
                    title: "The jar we hid by the old oak", body: "", photoData: photo("CapsuleSealed"),
                    activityType: .hike),
            Waymark(createdAt: ago(days: 12), coordinate: at(44.4367, 26.0878), kind: .note,
                    title: "Where the street musicians play on Fridays",
                    body: "Violin and accordion. Come back on a Friday evening.", activityType: .walk),
            Waymark(createdAt: ago(days: 3), coordinate: at(44.4394, 26.0910), kind: .note,
                    title: "New personal best start line",
                    body: "5 km in 26:40 from here.", activityType: .run)
        ]

        for (index, waymark) in items.enumerated() {
            // A few return visits, so the Journal shows a lived-in history.
            if index % 2 == 0 {
                waymark.visitDates = [ago(days: max(1, 120 - index * 10)), ago(days: max(1, 40 - index * 3))]
            }
            context.insert(waymark)
        }
        // The capsule whose date has passed stays unopened so it reads
        // "Ready — walk back to open".
        try? context.save()
        store.didChange()
    }
}
#endif
