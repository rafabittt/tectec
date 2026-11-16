import AVFoundation
import AudioToolbox
import CoreAudio

/// Banco de sons: para cada keyCode do macOS, um buffer de "down" e um de "up".
struct SoundBank {
    var keys: [UInt16: (down: AVAudioPCMBuffer, up: AVAudioPCMBuffer?)] = [:]
    var fallback: (down: AVAudioPCMBuffer, up: AVAudioPCMBuffer?)?

    func sound(for keyCode: UInt16) -> (down: AVAudioPCMBuffer, up: AVAudioPCMBuffer?)? {
        keys[keyCode] ?? fallback
    }
}

final class SoundEngine {
    static let sampleRate: Double = 48_000
    static let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private let voiceCount = 24

    var bank = SoundBank()
    var volume: Float = 0.7 { didSet { engine.mainMixerNode.outputVolume = volume } }
    var spatial = true
    var headphones = false { didSet { applyRendering() } }
    var pitchVariation = true

    init() {
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 10
        environment.reverbParameters.enable = false

        for _ in 0..<voiceCount {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: environment, format: Self.format)
            voices.append(p)
        }
        applyRendering()
        engine.mainMixerNode.outputVolume = volume
        engine.prepare()

        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.start()
        }
        start()
    }

    func start() {
        do {
            if !engine.isRunning { try engine.start() }
            lowerLatency()
            for v in voices where !v.isPlaying { v.play() }
        } catch {
            NSLog("TecTec: falha ao iniciar áudio: \(error)")
        }
    }

    /// Buffer de saída pequeno = som "instantâneo" ao apertar a tecla.
    private func lowerLatency() {
        guard let unit = engine.outputNode.audioUnit else { return }
        var frames: UInt32 = 128
        AudioUnitSetProperty(unit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0, &frames, UInt32(MemoryLayout<UInt32>.size))
    }

    private func applyRendering() {
        for v in voices {
            v.renderingAlgorithm = headphones ? .HRTFHQ : .equalPowerPanning
        }
    }

    func play(keyCode: UInt16, isDown: Bool) {
        guard let s = bank.sound(for: keyCode) else { return }
        guard let buffer = isDown ? s.down : s.up else { return }
        play(buffer: buffer, pan: spatial ? ABNT2.pan(for: keyCode) : 0)
    }

    func play(buffer: AVAudioPCMBuffer, pan: Float) {
        if !engine.isRunning { start() }
        let v = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voiceCount
        // Posição no "palco": teclas da esquerda soam à esquerda.
        let x = pan * (headphones ? 1.2 : 2.5)
        v.position = AVAudio3DPoint(x: x, y: 0, z: -1)
        v.rate = pitchVariation ? Float.random(in: 0.97...1.03) : 1
        v.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !v.isPlaying { v.play() }
    }

    static func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, samples.count)))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buf.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        return buf
    }

}
