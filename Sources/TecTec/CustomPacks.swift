import AVFoundation

/// Pacotes de som do usuário em ~/Library/Application Support/TecTec/Pacotes/<Nome>/
///
/// Formatos aceitos (wav, aiff, mp3, m4a, caf — o macOS não lê .ogg nativamente):
///  1. Estilo "por tecla": arquivos `<código>-down.wav` e `<código>-up.wav`
///     (código no padrão uiohook: 30 = A, 57 = espaço, 28 = Enter…),
///     mais `default-down.wav` / `default-up.wav` opcionais como fallback.
///  2. Pacotes do Mechvibes (config.json), tipo "single" ou "multi".
enum CustomPacks {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("TecTec/Pacotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func list() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    static let audioExts = ["wav", "aif", "aiff", "mp3", "m4a", "caf"]

    static func load(_ dir: URL) throws -> SoundBank {
        let configURL = dir.appendingPathComponent("config.json")
        if FileManager.default.fileExists(atPath: configURL.path) {
            return try loadMechvibes(dir, configURL)
        }
        return try loadPerKey(dir)
    }

    private static func find(_ dir: URL, _ stem: String) -> URL? {
        for ext in audioExts {
            let u = dir.appendingPathComponent("\(stem).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    private static func loadPerKey(_ dir: URL) throws -> SoundBank {
        var bank = SoundBank()
        for (mac, hook) in UIOHook.fromMac {
            guard let d = find(dir, "\(hook)-down") ?? find(dir, "\(hook)") else { continue }
            let down = try readMono(d)
            let up = try find(dir, "\(hook)-up").map(readMono)
            bank.keys[mac] = (SoundEngine.makeBuffer(down), up.map(SoundEngine.makeBuffer))
        }
        if let d = find(dir, "default-down") ?? find(dir, "default") {
            bank.fallback = (SoundEngine.makeBuffer(try readMono(d)), try find(dir, "default-up").map { SoundEngine.makeBuffer(try readMono($0)) })
        } else if let any = bank.keys.values.first {
            bank.fallback = any
        }
        guard bank.fallback != nil else { throw PackError.empty }
        return bank
    }

    private static func loadMechvibes(_ dir: URL, _ configURL: URL) throws -> SoundBank {
        let data = try Data(contentsOf: configURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let defines = json["defines"] as? [String: Any] else { throw PackError.badConfig }
        let type = (json["key_define_type"] as? String) ?? "single"
        var bank = SoundBank()
        let hookToMac = Dictionary(UIOHook.fromMac.map { ($0.value, $0.key) }, uniquingKeysWith: { a, _ in a })

        if type == "multi" {
            for (k, v) in defines {
                guard let hook = Int(k), let mac = hookToMac[hook], let file = v as? String, !file.isEmpty else { continue }
                let s = try readMono(dir.appendingPathComponent(file))
                bank.keys[mac] = (SoundEngine.makeBuffer(s), nil)
            }
        } else {
            guard let soundName = json["sound"] as? String else { throw PackError.badConfig }
            let all = try readMono(dir.appendingPathComponent(soundName))
            let sr = SoundEngine.sampleRate
            for (k, v) in defines {
                guard let hook = Int(k), let mac = hookToMac[hook], let arr = v as? [Double], arr.count >= 2 else { continue }
                let a = max(0, Int(arr[0] / 1000 * sr)), len = Int(arr[1] / 1000 * sr)
                let b = min(all.count, a + len)
                guard b > a else { continue }
                bank.keys[mac] = (SoundEngine.makeBuffer(Array(all[a..<b])), nil)
            }
        }
        bank.fallback = bank.keys[0] ?? bank.keys.values.first
        guard bank.fallback != nil else { throw PackError.empty }
        return bank
    }

    /// Lê qualquer arquivo de áudio, mixa para mono e reamostra para 48 kHz.
    static func readMono(_ url: URL) throws -> [Float] {
        if url.pathExtension.lowercased() == "ogg" { throw PackError.ogg }
        let file = try AVAudioFile(forReading: url)
        let fmt = file.processingFormat
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(file.length)) else { throw PackError.empty }
        try file.read(into: buf)
        let n = Int(buf.frameLength), ch = Int(fmt.channelCount)
        guard let data = buf.floatChannelData, n > 0 else { throw PackError.empty }
        var mono = [Float](repeating: 0, count: n)
        for c in 0..<ch { for i in 0..<n { mono[i] += data[c][i] / Float(ch) } }
        let ratio = fmt.sampleRate / SoundEngine.sampleRate
        if abs(ratio - 1) < 0.0001 { return mono }
        let outN = Int(Double(n) / ratio)
        return (0..<outN).map { i in
            let pos = Double(i) * ratio
            let j = Int(pos), f = Float(pos - Double(j))
            let a = mono[min(j, n - 1)], b = mono[min(j + 1, n - 1)]
            return a + (b - a) * f
        }
    }

    enum PackError: LocalizedError {
        case empty, badConfig, ogg
        var errorDescription: String? {
            switch self {
            case .empty: return "Nenhum som encontrado na pasta."
            case .badConfig: return "config.json inválido."
            case .ogg: return "Arquivos .ogg não são suportados pelo macOS. Converta para .wav ou .m4a."
            }
        }
    }
}
