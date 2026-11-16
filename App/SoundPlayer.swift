import AVFoundation
import os
import WildernessCore

/// The living sound (docs/superpowers/plans/2026-11-15-living-sound.md), from real CC0 recordings
/// built by scripts/make_soundscape.py:
///   bed   = a choir and a pad in D, two loops of different lengths (so they never line up the
///           same way twice), through a soft low-pass that opens with Christ's breath, then a hall.
///   bowl  = one recorded singing bowl tuned to D, its hum only (no strike), swelling in like a
///           breath at each figure's own note (SoundCues), with a longer cathedral tail.
/// Everything is decoded once into memory and looped from there (no gap at the loop point).
/// Volume only ever fades (Soundscape.step).
@MainActor
final class SoundPlayer {
    private static let log = Logger(subsystem: "com.mattmccoy.wilderness", category: "sound")
    private let engine = AVAudioEngine()
    private let bedMix = AVAudioMixerNode()
    private let bedTone = AVAudioUnitEQ(numberOfBands: 1)
    private let bedHall = AVAudioUnitReverb()
    private let bowlMix = AVAudioMixerNode()   // a reverb has one input: the four voices meet here first
    private let bowlHall = AVAudioUnitReverb()
    private var beds: [(node: AVAudioPlayerNode, buffer: AVAudioPCMBuffer)] = []
    private var bowls: [(node: AVAudioPlayerNode, pitch: AVAudioUnitVarispeed)] = []
    private var bowl: AVAudioPCMBuffer?
    private var nextBowl = 0
    private var running = false
    private(set) var volume = 0.0

    /// False when the bed is missing or unreadable; the menu says so instead of "on".
    var available: Bool { !beds.isEmpty }

    init() {
        let choir = Self.load("choir"), pad = Self.load("pad")
        bowl = Self.load("bowl")
        guard let choir, let pad else { return }

        engine.attach(bedMix); engine.attach(bedTone); engine.attach(bedHall); engine.attach(bowlMix); engine.attach(bowlHall)
        for buffer in [choir, pad] {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: bedMix, format: buffer.format)
            beds.append((node, buffer))
        }
        let band = bedTone.bands[0]
        band.filterType = .lowPass
        band.bypass = false
        band.frequency = 4000
        bedHall.loadFactoryPreset(.largeHall)
        bedHall.wetDryMix = 18
        bowlHall.loadFactoryPreset(.cathedral)
        bowlHall.wetDryMix = 42
        engine.connect(bedMix, to: bedTone, format: choir.format)
        engine.connect(bedTone, to: bedHall, format: choir.format)
        engine.connect(bedHall, to: engine.mainMixerNode, format: choir.format)

        if let bowl {
            for _ in 0..<4 {
                let node = AVAudioPlayerNode(), pitch = AVAudioUnitVarispeed()
                engine.attach(node); engine.attach(pitch)
                engine.connect(node, to: pitch, format: bowl.format)
                engine.connect(pitch, to: bowlMix, format: bowl.format)
                bowls.append((node, pitch))
            }
            engine.connect(bowlMix, to: bowlHall, format: bowl.format)
            engine.connect(bowlHall, to: engine.mainMixerNode, format: bowl.format)
        }
        bedMix.outputVolume = 0
        do {
            // Ambient: mixes with other audio and respects the system's silencing.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            Self.log.error("audio session category failed: \(error.localizedDescription)")
        }
    }

    /// Called on every app tick with the volume the current mode wants and how far into
    /// Christ's breath the wall is (0…1).
    func update(target: Double, dt: Double, breath: Double) {
        guard available else { return }
        volume = Soundscape.step(current: volume, target: target, dt: dt)
        // The breath: about ±1.5 dB and a low-pass that opens from 2.4 to 5.4 kHz.
        let lift = pow(10, (-1.5 + 3 * breath) / 20)
        bedMix.outputVolume = Float(volume * lift)
        bedTone.bands[0].frequency = Float(2400 + 3000 * breath)
        if volume > 0, !running { start() }
        if volume == 0, target == 0, running { stop() }
    }

    /// Breathe the bowl's hum for a cue (a new figure, Unfold beat or Context page), only while
    /// sound is on. Moving on quickly never piles breaths up: the one before eases out.
    func ring(_ cue: SoundCue) {
        guard running, volume > 0, let bowl, !bowls.isEmpty else { return }
        if let previous = lastVoice { fadeOut(bowls[previous].node, seconds: 0.8) }
        let i = nextBowl
        nextBowl = (nextBowl + 1) % bowls.count
        let voice = bowls[i]
        fades[i]?.cancel()
        voice.pitch.rate = Float(pow(2, Double(cue.semitones) / 12))
        // As loud as the bed is allowed to be right now, so it dips under Unfold with it.
        voice.node.volume = Float(cue.gain * min(volume / Soundscape.ambient, 1) * 0.8)
        voice.node.stop()
        voice.node.scheduleBuffer(bowl, at: nil)
        voice.node.play()
        lastVoice = i
        Self.log.debug("bowl breath \(cue.semitones) semitones, gain \(cue.gain, format: .fixed(precision: 2))")
    }

    private var lastVoice: Int?
    private var fades: [Int: Task<Void, Never>] = [:]

    /// A short, smooth fade (20 steps), then silence.
    private func fadeOut(_ node: AVAudioPlayerNode, seconds: Double) {
        guard let i = bowls.firstIndex(where: { $0.node === node }) else { return }
        fades[i]?.cancel()
        let start = node.volume
        fades[i] = Task { @MainActor in
            for step in 1...20 {
                try? await Task.sleep(for: .seconds(seconds / 20))
                if Task.isCancelled { return }
                node.volume = start * Float(1 - Double(step) / 20)
            }
            node.stop()
        }
    }

    /// After the app returns to the foreground, restart the engine if tvOS stopped it.
    func resume() {
        guard running, !engine.isRunning else { return }
        running = false
        start()
    }

    private func start() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            for bed in beds {
                bed.node.scheduleBuffer(bed.buffer, at: nil, options: .loops)
                bed.node.play()
            }
            running = true
        } catch {
            Self.log.error("sound start failed: \(error.localizedDescription)")
        }
    }

    private func stop() {
        for bed in beds { bed.node.stop() }
        for voice in bowls { voice.node.stop() }
        engine.stop()
        running = false
    }

    private static func load(_ name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            log.error("\(name).m4a missing from the app bundle")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buf)
            return buf
        } catch {
            log.error("\(name).m4a unreadable: \(error.localizedDescription)")
            return nil
        }
    }
}
