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

/// Escala do volume do TecTec. O controle anda em decibéis, que é como o ouvido percebe volume:
/// 0 = mudo, 2/3 = som original (0 dB), 1 = +18 dB de ganho (com a saturação, cerca de +12 dB reais: ~2,3× mais alto).
enum Volume {
    static let minDB: Float = -36
    static let maxDB: Float = 18
    static let unity: Float = -minDB / (maxDB - minDB)   // 2/3

    static func decibels(_ level: Float) -> Float? {
        level <= 0.01 ? nil : minDB + (maxDB - minDB) * min(max(level, 0), 1)
    }
    static func level(fromLinear v: Float) -> Float {
        guard v > 0 else { return 0 }
        return min(max((20 * log10(v) - minDB) / (maxDB - minDB), 0), 1)
    }
    /// Volume percebido em relação ao som original (+10 dB ≈ 2× mais alto). Acima de 0 dB a saturação
    /// entrega cerca de 2/3 do ganho em volume real (medido nas gravações), então o rótulo usa isso.
    static func percent(_ level: Float) -> Int {
        guard let db = decibels(level) else { return 0 }
        let real = db > 0 ? db * 0.65 : db
        return Int((pow(2, real / 10) * 100).rounded())
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

    /// Sons como foram carregados; `boosted` é a versão com o volume do TecTec aplicado.
    var bank: SoundBank {
        get { rawBank }
        set { rawBank = newValue; applyVolume() }
    }
    private var rawBank = SoundBank()
    private var boosted = SoundBank()
    /// Posição do controle de volume, 0…1, numa escala em decibéis (ver `Volume`).
    var level: Float = Volume.unity { didSet { applyVolume() } }
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
        applyVolume()
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

    /// Abaixo do som original: só abaixa o volume do mixer.
    /// Acima: aplica o ganho nas próprias gravações com saturação suave, que arredonda só os picos.
    /// (Um limitador comum achata o estalo da tecla e quase não deixa mais alto; medido.)
    private func applyVolume() {
        guard let db = Volume.decibels(level) else { engine.mainMixerNode.outputVolume = 0; boosted = rawBank; return }
        if db <= 0 {
            engine.mainMixerNode.outputVolume = pow(10, db / 20)
            boosted = rawBank
        } else {
            engine.mainMixerNode.outputVolume = 1
            boosted = Self.boost(rawBank, gain: pow(10, db / 20))
        }
    }

    private static func softClip(_ u: Float) -> Float {
        let a = abs(u), knee: Float = 0.8, room: Float = 0.19
        return a <= knee ? u : (u < 0 ? -1 : 1) * (knee + room * tanh((a - knee) / room))
    }

    /// Reforça cada gravação uma vez só (o mesmo buffer serve para várias teclas).
    private static func boost(_ bank: SoundBank, gain: Float) -> SoundBank {
        var done: [ObjectIdentifier: AVAudioPCMBuffer] = [:]
        func b(_ x: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
            if let y = done[ObjectIdentifier(x)] { return y }
            let y = AVAudioPCMBuffer(pcmFormat: x.format, frameCapacity: x.frameLength)!
            y.frameLength = x.frameLength
            let src = x.floatChannelData![0], dst = y.floatChannelData![0]
            for i in 0..<Int(x.frameLength) { dst[i] = softClip(src[i] * gain) }
            done[ObjectIdentifier(x)] = y
            return y
        }
        var out = SoundBank()
        for (k, v) in bank.keys { out.keys[k] = (b(v.down), v.up.map(b)) }
        out.fallback = bank.fallback.map { (b($0.down), $0.up.map(b)) }
        return out
    }

    private func applyRendering() {
        for v in voices {
            v.renderingAlgorithm = headphones ? .HRTFHQ : .equalPowerPanning
        }
    }

    func play(keyCode: UInt16, isDown: Bool) {
        guard let s = boosted.sound(for: keyCode) else { return }
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
