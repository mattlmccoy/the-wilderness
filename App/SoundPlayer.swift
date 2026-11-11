import AVFoundation
import os
import WildernessCore

/// Plays the quiet wind bed (App/Sound/wind.m4a, made by scripts/make_wind.py) as a gapless loop.
/// The file is decoded once into memory and looped from there, which avoids the small gap a
/// compressed file leaves when a player loops it. Volume only ever fades (Soundscape.step).
@MainActor
final class SoundPlayer {
    private static let log = Logger(subsystem: "com.mattmccoy.wilderness", category: "sound")
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer?
    private var running = false
    private(set) var volume = 0.0

    /// False when the sound file is missing or unreadable; the menu says so instead of "on".
    var available: Bool { buffer != nil }

    init() {
        buffer = Self.load()
        guard let buffer else { return }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
        node.volume = 0
        do {
            // Ambient: mixes with other audio and respects the system's silencing.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            Self.log.error("audio session category failed: \(error.localizedDescription)")
        }
    }

    /// Called on every app tick with the volume the current mode wants.
    func update(target: Double, dt: Double) {
        guard available else { return }
        volume = Soundscape.step(current: volume, target: target, dt: dt)
        node.volume = Float(volume)
        if volume > 0, !running { start() }
        if volume == 0, target == 0, running { stop() }
    }

    /// After the app returns to the foreground, restart the engine if tvOS stopped it.
    func resume() {
        guard running, !engine.isRunning else { return }
        running = false
        start()
    }

    private func start() {
        guard let buffer else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            node.play()
            running = true
        } catch {
            Self.log.error("sound start failed: \(error.localizedDescription)")
        }
    }

    private func stop() {
        node.stop()
        engine.stop()
        running = false
    }

    private static func load() -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: "wind", withExtension: "m4a") else {
            log.error("wind.m4a missing from the app bundle")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buf)
            return buf
        } catch {
            log.error("wind.m4a unreadable: \(error.localizedDescription)")
            return nil
        }
    }
}
