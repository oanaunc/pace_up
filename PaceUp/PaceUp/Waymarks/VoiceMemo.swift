//
//  VoiceMemo.swift
//  Pace Up
//
//  Record and play the voice memos attached to waymarks.
//
//  The audio session mixes with others, so dropping a memo mid-run does not
//  stop the user's music or podcast for longer than the recording itself.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class VoiceMemoRecorder: NSObject {

    enum State: Equatable { case idle, recording, recorded, denied }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval = 0
    private(set) var level: Float = 0
    private(set) var fileName: String?

    /// A memo is a moment, not a podcast.
    let maximumDuration: TimeInterval = 90

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?

    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { state = .denied; return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch { return }

        discard()
        let name = WaymarkMedia.newAudioFileName()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        guard let recorder = try? AVAudioRecorder(url: WaymarkMedia.audioURL(for: name), settings: settings) else { return }
        recorder.isMeteringEnabled = true
        recorder.record(forDuration: maximumDuration)
        self.recorder = recorder
        fileName = name
        duration = 0
        state = .recording

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    func stop() {
        guard let recorder else { return }
        duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
        state = duration > 0.5 ? .recorded : .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Deletes whatever was recorded and returns to idle.
    func discard() {
        recorder?.stop()
        recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        WaymarkMedia.deleteAudio(named: fileName)
        fileName = nil
        duration = 0
        if state != .denied { state = .idle }
    }

    /// Hands ownership of the file to the waymark. After this, `discard()`
    /// will not delete it.
    func takeFile() -> (name: String, duration: TimeInterval)? {
        guard state == .recorded, let fileName else { return nil }
        self.fileName = nil
        state = .idle
        return (fileName, duration)
    }

    private func tick() {
        guard let recorder else { return }
        if !recorder.isRecording {
            stop()
            return
        }
        recorder.updateMeters()
        duration = recorder.currentTime
        // -60 dB…0 dB → 0…1
        let power = recorder.averagePower(forChannel: 0)
        level = max(0, min(1, (power + 60) / 60))
    }
}

@MainActor
@Observable
final class VoiceMemoPlayer: NSObject, AVAudioPlayerDelegate {

    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(fileName: String) {
        if isPlaying { stop(); return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        guard let player = try? AVAudioPlayer(contentsOf: WaymarkMedia.audioURL(for: fileName)) else { return }
        player.delegate = self
        player.play()
        self.player = player
        isPlaying = true

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        isPlaying = false
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
