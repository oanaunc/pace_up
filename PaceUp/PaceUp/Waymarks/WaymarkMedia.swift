//
//  WaymarkMedia.swift
//  Pace Up
//
//  Voice memos live as files next to the store, inside the App Group, so they
//  are included in device backups and removed by "Delete All Pace Up Data".
//  Photos live in the store itself as external-storage blobs.
//

import Foundation
import UIKit

enum WaymarkMedia {

    static var directory: URL {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "Waymarks", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func audioURL(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    static func newAudioFileName() -> String {
        "memo-\(UUID().uuidString).m4a"
    }

    static func deleteAudio(named fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: audioURL(for: fileName))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Downscales a camera photo so a year of waymarks does not cost gigabytes.
    /// 1600 px on the long edge is sharper than any screen the app shows it on.
    static func jpegData(from image: UIImage, maxDimension: CGFloat = 1600) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
