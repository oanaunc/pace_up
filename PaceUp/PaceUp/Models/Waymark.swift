//
//  Waymark.swift
//  Pace Up
//
//  A waymark is a memory pinned to a place: a note, a photo, a voice memo, or
//  a sealed time capsule. It is the thing Pace Up is built around.
//
//  Waymarks are never shown on a timer or a feed. They come back to you only
//  when you are physically standing where you left them — on foot, during a
//  recorded walk, run or ride. A capsule adds a second lock: it stays sealed
//  until its date, *and* it only opens when you walk back to it.
//
//  Waymarks are permanent. The 30-day route cleanup never touches them, and
//  they are stored on device only.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Waymark {

    #Index<Waymark>([\.createdAt])

    @Attribute(.unique) var id: UUID
    var createdAt: Date

    var latitude: Double
    var longitude: Double
    /// How close, in metres, the user has to be for it to resurface.
    var radius: Double

    /// Backing store for `kind`.
    var kindRaw: String
    var title: String
    var body: String

    /// JPEG, kept out of the SQLite row.
    @Attribute(.externalStorage) var photoData: Data?
    /// File name inside `WaymarkMedia.directory`. Nil when there is no memo.
    var audioFileName: String?
    var audioDuration: Double?

    /// For capsules: the earliest date it may be opened. It still has to be
    /// opened in person.
    var sealedUntil: Date?
    /// When a capsule was first opened. Nil until then.
    var openedAt: Date?

    /// Every time the user has walked back past it, newest last.
    var visitDates: [Date]

    /// The recording this waymark was dropped during, if any. Matches
    /// `Activity.id`, which is the recorder's session ID.
    var activityID: UUID?
    /// Activity type during which it was dropped, for the icon in lists.
    var activityTypeRaw: String?

    /// Who the capsule is addressed to, e.g. "Me, in a year" or "Ana".
    var addressedTo: String?

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         coordinate: CLLocationCoordinate2D,
         radius: Double = 45,
         kind: WaymarkKind,
         title: String,
         body: String = "",
         photoData: Data? = nil,
         audioFileName: String? = nil,
         audioDuration: Double? = nil,
         sealedUntil: Date? = nil,
         addressedTo: String? = nil,
         activityID: UUID? = nil,
         activityType: ActivityType? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.radius = radius
        self.kindRaw = kind.rawValue
        self.title = title
        self.body = body
        self.photoData = photoData
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
        self.sealedUntil = sealedUntil
        self.addressedTo = addressedTo
        self.activityID = activityID
        self.activityTypeRaw = activityType?.rawValue
        self.visitDates = []
    }

    // MARK: Derived

    var kind: WaymarkKind {
        get { WaymarkKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var activityType: ActivityType? {
        activityTypeRaw.flatMap(ActivityType.init(rawValue:))
    }

    var isCapsule: Bool { kind == .capsule }

    /// A capsule whose date has not come yet.
    func isSealed(at date: Date = .now) -> Bool {
        guard isCapsule, let sealedUntil else { return false }
        return date < sealedUntil
    }

    /// A capsule whose date has passed but which nobody has walked back to.
    func isWaitingToBeOpened(at date: Date = .now) -> Bool {
        isCapsule && !isSealed(at: date) && openedAt == nil
    }

    /// Content may be shown in lists. Sealed and unopened capsules show only
    /// their envelope.
    func isReadable(at date: Date = .now) -> Bool {
        !isCapsule || openedAt != nil
    }

    var lastVisit: Date? { visitDates.last }
    var visitCount: Int { visitDates.count }
}

enum WaymarkKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case note
    case photo
    case voice
    case capsule

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .note:    return String(localized: "Note")
        case .photo:   return String(localized: "Photo")
        case .voice:   return String(localized: "Voice")
        case .capsule: return String(localized: "Capsule")
        }
    }

    var symbolName: String {
        switch self {
        case .note:    return "text.quote"
        case .photo:   return "camera.fill"
        case .voice:   return "waveform"
        case .capsule: return "envelope.badge.fill"
        }
    }
}
