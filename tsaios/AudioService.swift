import AVFoundation

final class AudioService {

    /// Configure the shared audio session once at launch so alerts play
    /// even when the app is backgrounded and other audio (e.g. navigation)
    /// is running. `duckOthers` briefly lowers navigation/music volume so
    /// the alert is clearly audible while driving.
    static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioService: AVAudioSession setup failed — \(error)")
        }
    }

    // MARK: - Public play

    func play(_ tone: AlertTone) {
        Task.detached(priority: .userInitiated) {
            switch tone {
            case .tripleBeep:  await self.playTripleBeep()
            case .singleBeep:  await self.playSingleBeep()
            case .alertChime:  await self.playAlertChime()
            case .siren:       await self.playSiren()
            case .klaxon:      await self.playKlaxon()
            case .rapidAlarm:  await self.playRapidAlarm()
            }
        }
    }

    // MARK: - Existing tones (amplitude boosted to 0.85)

    private func playTripleBeep() async {
        // Square-wave at 1200 Hz — harsh and loud, cuts through road/wind noise
        for i in 0..<3 {
            if i > 0 { try? await Task.sleep(nanoseconds: 120_000_000) }
            playSquareTone(frequency: 1200.0, duration: 0.18, amplitude: 0.92)
        }
    }

    private func playSingleBeep() async {
        playSquareTone(frequency: 1200.0, duration: 0.28, amplitude: 0.92)
    }

    private func playAlertChime() async {
        // C5–E5–G5 ascending arpeggio
        let notes: [(Double, UInt64)] = [(523.25, 0), (659.25, 160_000_000), (784.0, 320_000_000)]
        for (freq, delay) in notes {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            playTone(frequency: freq, duration: 0.35, amplitude: 0.85)
        }
    }

    // MARK: - Loud alert tones

    /// Siren — rising-falling frequency sweep, played twice.
    /// Very hard to miss; sounds like an emergency vehicle horn.
    private func playSiren() async {
        for i in 0..<2 {
            if i > 0 { try? await Task.sleep(nanoseconds: 120_000_000) }
            playFrequencySweep(from: 700, to: 1400, duration: 0.45, amplitude: 0.90)
            try? await Task.sleep(nanoseconds: 450_000_000)
            playFrequencySweep(from: 1400, to: 700, duration: 0.35, amplitude: 0.90)
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
    }

    /// Klaxon — harsh two-tone horn alternating between 880 Hz and 1320 Hz.
    /// Uses a square-wave approximation for extra bite.
    private func playKlaxon() async {
        let pattern: [(Double, Double)] = [
            (880, 0.20), (1320, 0.20),
            (880, 0.20), (1320, 0.20),
            (880, 0.20), (1320, 0.20),
        ]
        for (freq, dur) in pattern {
            playSquareTone(frequency: freq, duration: dur, amplitude: 0.88)
            try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000) + 25_000_000)
        }
    }

    /// Rapid Alarm — 7 short sharp blasts at 1500 Hz with quick gaps.
    /// Maximum urgency; very difficult to ignore while driving.
    private func playRapidAlarm() async {
        for i in 0..<7 {
            if i > 0 { try? await Task.sleep(nanoseconds: 70_000_000) }
            playSquareTone(frequency: 1500, duration: 0.09, amplitude: 0.90)
        }
    }

    // MARK: - AVAudioEngine helpers

    /// Pure sine-wave tone with a soft exponential decay envelope.
    private func playTone(frequency: Double, duration: Double, amplitude: Float = 0.85) {
        let engine     = AVAudioEngine()
        let player     = AVAudioPlayerNode()
        let sampleRate = 44100.0
        let frames     = AVAudioFrameCount(sampleRate * duration)
        let format     = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data   = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let env = Float(exp(-t * 7.0))
            data[i] = Float(sin(2.0 * .pi * frequency * t)) * env * amplitude
        }

        try? engine.start()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
        Thread.sleep(forTimeInterval: duration + 0.05)
        engine.stop()
    }

    /// Square-wave approximation (summed odd harmonics) — harsher and
    /// perceptually louder than a pure sine at the same amplitude.
    private func playSquareTone(frequency: Double, duration: Double, amplitude: Float) {
        let engine     = AVAudioEngine()
        let player     = AVAudioPlayerNode()
        let sampleRate = 44100.0
        let frames     = AVAudioFrameCount(sampleRate * duration)
        let format     = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data   = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        let normFactor = Float(4.0 / .pi) // square wave peak normalisation
        for i in 0..<Int(frames) {
            let t   = Double(i) / sampleRate
            // Sustain flat, then fast release in last 15 ms
            let rel = max(0.0, t - (duration - 0.015))
            let env = Float(exp(-rel * 200.0))
            // Odd harmonics: 1st + 3rd + 5th + 7th
            var s = sin(2 * .pi * frequency       * t)
            s    += sin(2 * .pi * frequency * 3.0 * t) / 3.0
            s    += sin(2 * .pi * frequency * 5.0 * t) / 5.0
            s    += sin(2 * .pi * frequency * 7.0 * t) / 7.0
            data[i] = Float(s) / normFactor * env * amplitude
        }

        try? engine.start()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
        Thread.sleep(forTimeInterval: duration + 0.05)
        engine.stop()
    }

    /// Linear frequency sweep — phase-correct integration of instantaneous frequency.
    /// φ(t) = 2π · (f1·t + (f2−f1)·t²/2T)
    private func playFrequencySweep(from f1: Double, to f2: Double,
                                    duration: Double, amplitude: Float) {
        let engine     = AVAudioEngine()
        let player     = AVAudioPlayerNode()
        let sampleRate = 44100.0
        let frames     = AVAudioFrameCount(sampleRate * duration)
        let format     = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data   = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for i in 0..<Int(frames) {
            let t     = Double(i) / sampleRate
            // Short attack + short release, sustain in the middle
            let atk   = min(1.0, t / 0.02)
            let rel   = min(1.0, (duration - t) / 0.02)
            let env   = Float(atk * rel)
            let phase = 2.0 * .pi * (f1 * t + (f2 - f1) * t * t / (2.0 * duration))
            data[i]   = Float(sin(phase)) * env * amplitude
        }

        try? engine.start()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
        Thread.sleep(forTimeInterval: duration + 0.05)
        engine.stop()
    }
}
