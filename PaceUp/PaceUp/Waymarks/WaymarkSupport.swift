//
//  WaymarkSupport.swift
//  Pace Up
//
//  Small UIKit and Core Location bridges the waymark screens need.
//

import SwiftUI
import UIKit
import CoreLocation

/// Camera capture. PhotosPicker covers the library; this covers "right here,
/// right now", which is the waymark use case.
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// One accurate fix, for dropping a waymark when no activity is recording.
/// Uses When In Use authorisation only.
@MainActor
@Observable
final class OneShotLocator: NSObject, CLLocationManagerDelegate {

    private(set) var location: CLLocation?
    private(set) var isLocating = false
    private(set) var failed = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func locate() async -> CLLocation? {
        guard continuation == nil else { return nil }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        isLocating = true
        failed = false
        let result: CLLocation? = await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
        isLocating = false
        failed = result == nil
        location = result
        return result
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            self.continuation?.resume(returning: latest)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .denied || status == .restricted {
                self.continuation?.resume(returning: nil)
                self.continuation = nil
            }
        }
    }
}

/// The pin used on every waymark map.
struct WaymarkPin: View {
    var kind: WaymarkKind
    var isSealed: Bool
    var isWaiting: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSealed ? Color.paceViolet : (isWaiting ? Color.paceAmber : Color.paceLime))
                .frame(width: 30, height: 30)
                .shadow(color: (isSealed ? Color.paceViolet : Color.paceLime).opacity(0.6), radius: 8)
            Image(systemName: isSealed ? "lock.fill" : kind.symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.paceInk)
        }
        .overlay { Circle().stroke(Color.paceInk, lineWidth: 2) }
        .accessibilityHidden(true)
    }
}

extension Waymark {
    /// "3rd time back" style copy.
    var visitsLabel: String {
        switch visitCount {
        case 0: return String(localized: "Not revisited yet")
        case 1: return String(localized: "Walked back once")
        default: return String(localized: "Walked back \(visitCount) times")
        }
    }
}
