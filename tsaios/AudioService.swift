import AVFoundation

final class AudioService {

    /// Configure the shared audio session once at launch so alerts play
    /// even when the app is backgrounded and other audio (e.g. navigation)
    /// is running. `duckOthers` briefly lowers navigation/music volume so
    /// the beep is clearly audible while driving.
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

    // MARK: - Public play methods

    func play(_ tone: AlertTone) {
        Task.detached(priority: .userInitiated) {
            switch tone {
            case .tripleBeep:
                await self.playTripleBeep()
            case .singleBeep:
                await self.playSingleBeep()
            case .alertChime:
                await self.playAlertChime()
            }
        }
    }

    // MARK: - Private tone implementations

    private func playTripleBeep() async {
        for i in 0..<3 {
            if i > 0 {
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms gap
            }
            playTone(frequency: 880.0, duration: 0.12)
        }
    }

    private func playSingleBeep() async {
        playTone(frequency: 880.0, duration: 0.2)
    }

    private func playAlertChime() async {
        // C-E-G chord (C5=523.25, E5=659.25, G5=784.0)
        playChord(frequencies: [523.25, 659.25, 784.0], duration: 0.5)
    }

    // MARK: - AVAudioEngine helpers

    private func playTone(frequency: Double, duration: Double) {
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 8.0)
            channelData[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.5)
        }

        do {
            try engine.start()
        } catch {
            print("AudioService: engine start error \(error)")
            return
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.play()

        // Keep engine alive for duration + a small margin
        Thread.sleep(forTimeInterval: duration + 0.05)
        engine.stop()
    }

    private func playChord(frequencies: [Double], duration: Double) {
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let amplitude = Float(0.5) / Float(frequencies.count)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 3.0)
            var sample: Float = 0
            for freq in frequencies {
                sample += Float(sin(2.0 * .pi * freq * t) * envelope) * amplitude
            }
            channelData[i] = sample
        }

        do {
            try engine.start()
        } catch {
            print("AudioService: engine start error \(error)")
            return
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.play()

        Thread.sleep(forTimeInterval: duration + 0.05)
        engine.stop()
    }
}
