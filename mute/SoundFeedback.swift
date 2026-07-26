import AppKit

/// Subtle audio cues played when Mute toggles Do Not Disturb.
/// The tones mirror the ones in the web demo: a soft descending chime when DND
/// turns on, and a single rising tone (the reverse) when it turns off.
/// Playback goes through `NSSound`, so it follows the system output volume.
enum SoundFeedback {
    private static let sampleRate: Double = 44_100

    private static let onSound = makeSound(dndOnSamples())
    private static let offSound = makeSound(dndOffSamples())

    static func playDndOn() { replay(onSound) }
    static func playDndOff() { replay(offSound) }

    private static func replay(_ sound: NSSound?) {
        guard let sound else { return }
        if sound.isPlaying { sound.stop() }
        sound.play()
    }

    // MARK: - Synthesis

    private static func dndOnSamples() -> [Float] {
        let duration = 0.5
        let count = Int(sampleRate * duration)
        var out = [Float](repeating: 0, count: count)
        var phase0 = 0.0
        var phase1 = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let gain = envelope(t, peak: 0.12, attack: 0.01, decayEnd: 0.35)
            let f0 = sweep(t, start: 880, end: 440, rampDuration: 0.18)
            phase0 += 2 * .pi * f0 / sampleRate
            var sample = sin(phase0)
            if t >= 0.06 {
                let f1 = sweep(t - 0.06, start: 440, end: 220, rampDuration: 0.18)
                phase1 += 2 * .pi * f1 / sampleRate
                sample += sin(phase1)
            }
            out[i] = Float(gain * sample)
        }
        return out
    }

    private static func dndOffSamples() -> [Float] {
        let duration = 0.4
        let count = Int(sampleRate * duration)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let gain = envelope(t, peak: 0.1, attack: 0.01, decayEnd: 0.3)
            let f = sweep(t, start: 440, end: 880, rampDuration: 0.15)
            phase += 2 * .pi * f / sampleRate
            out[i] = Float(gain * sin(phase))
        }
        return out
    }

    private static func envelope(_ t: Double, peak: Double, attack: Double, decayEnd: Double) -> Double {
        if t < attack { return peak * (t / attack) }
        if t < decayEnd {
            let floorValue = 0.0001
            let fraction = (t - attack) / (decayEnd - attack)
            return peak * pow(floorValue / peak, fraction)
        }
        return 0
    }

    private static func sweep(_ t: Double, start: Double, end: Double, rampDuration: Double) -> Double {
        if t <= 0 { return start }
        if t >= rampDuration { return end }
        return start * pow(end / start, t / rampDuration)
    }

    // MARK: - WAV packaging

    /// Wraps float samples in a minimal 16-bit PCM mono WAV so `NSSound` can play them.
    private static func makeSound(_ samples: [Float]) -> NSSound? {
        NSSound(data: wavData(samples))
    }

    private static func wavData(_ samples: [Float]) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let rate = UInt32(sampleRate)
        let byteRate = rate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count) * UInt32(blockAlign)

        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append(UInt32(36) + dataSize)
        append("WAVE")
        append("fmt ")
        append(UInt32(16))          // fmt chunk size
        append(UInt16(1))           // PCM
        append(channels)
        append(rate)
        append(byteRate)
        append(blockAlign)
        append(bitsPerSample)
        append("data")
        append(dataSize)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append(Int16(clamped * Float(Int16.max)))
        }
        return data
    }
}
