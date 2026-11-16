import AVFoundation

/// Gravações reais de switches (projeto kbsim, licença MIT — ver Resources/Switches/LICENSE-kbsim.txt).
/// Cada switch tem, ao apertar: GENERIC_R0…R4 (uma por fileira do teclado), SPACE, ENTER, BACKSPACE;
/// e ao soltar: GENERIC, SPACE, ENTER, BACKSPACE.
enum SwitchType: String, CaseIterable {
    case linear = "Lineares"
    case tactile = "Táteis"
    case clicky = "Clicky"
    case special = "Clássicos especiais"
}

struct SwitchInfo {
    let id: String        // nome da pasta em Resources/Switches
    let name: String
    let type: SwitchType
    let sound: String     // descrição curta do som

    static let all: [SwitchInfo] = [
        .init(id: "cream", name: "NovelKeys Cream", type: .linear, sound: "POM autolubrificante, grave e levemente arranhado"),
        .init(id: "blackink", name: "Gateron Black Ink", type: .linear, sound: "pesado, carcaça fumê, thock profundo"),
        .init(id: "redink", name: "Gateron Red Ink", type: .linear, sound: "leve, mais agudo e clacky"),
        .init(id: "mxblack", name: "Cherry MX Black", type: .linear, sound: "o linear clássico pesado, seco"),
        .init(id: "alpaca", name: "Alpaca", type: .linear, sound: "suave e cremoso, molas leves"),
        .init(id: "turquoise", name: "Turquoise Tealios", type: .linear, sound: "lubrificado de fábrica, limpo e poppy"),
        .init(id: "holypanda", name: "Holy Panda", type: .tactile, sound: "bump forte e arredondado, marcante"),
        .init(id: "mxbrown", name: "Cherry MX Brown", type: .tactile, sound: "bump suave, o tátil de escritório"),
        .init(id: "mxblue", name: "Cherry MX Blue", type: .clicky, sound: "clique agudo da jaqueta, o barulhento clássico"),
        .init(id: "boxnavy", name: "Kailh Box Navy", type: .clicky, sound: "clique de barra de mola, alto e pesado"),
        .init(id: "bluealps", name: "SKCM Blue Alps", type: .clicky, sound: "Alps vintage dos anos 80, clique cristalino"),
        .init(id: "buckling", name: "Buckling Spring", type: .special, sound: "mola que flamba, o som do IBM Model M"),
        .init(id: "topre", name: "Topre", type: .special, sound: "eletrocapacitivo de borracha, thock abafado"),
    ]

    static let defaultID = "holypanda"

    static func byID(_ id: String) -> SwitchInfo? { all.first { $0.id == id } }
}

enum SwitchBank {
    static var folder: URL? { Bundle.main.resourceURL?.appendingPathComponent("Switches", isDirectory: true) }

    static func load(_ info: SwitchInfo) throws -> SoundBank {
        guard let base = folder?.appendingPathComponent(info.id) else { throw CustomPacks.PackError.empty }
        func read(_ sub: String, _ name: String) throws -> [Float] {
            try CustomPacks.readMono(base.appendingPathComponent(sub).appendingPathComponent("\(name).mp3"))
        }
        var press: [String: [Float]] = [:]
        for name in ["GENERIC_R0", "GENERIC_R1", "GENERIC_R2", "GENERIC_R3", "GENERIC_R4"] {
            press[name] = try read("press", name)
        }
        var release: [String: [Float]] = ["GENERIC": try read("release", "GENERIC")]
        // Teclas grandes: alguns switches (ex.: MX Blue) não têm gravação própria → usa a fileira de baixo.
        for name in ["SPACE", "ENTER", "BACKSPACE"] {
            press[name] = (try? read("press", name)) ?? press["GENERIC_R4"]
            release[name] = (try? read("release", name)) ?? release["GENERIC"]
        }

        // Nivela o volume entre switches (mantendo a diferença entre teclas).
        let peak = press.values.flatMap { $0 }.map(abs).max() ?? 1
        let gain = peak > 0 ? 0.85 / peak : 1
        let pBuf = press.mapValues { SoundEngine.makeBuffer($0.map { $0 * gain }) }
        let rBuf = release.mapValues { SoundEngine.makeBuffer($0.map { $0 * gain }) }

        var bank = SoundBank()
        var codes = Set(ABNT2.positions.keys)
        codes.insert(76)
        for code in codes {
            let (p, r): (String, String)
            switch code {
            case 49: (p, r) = ("SPACE", "SPACE")
            case 36, 76: (p, r) = ("ENTER", "ENTER")
            case 51: (p, r) = ("BACKSPACE", "BACKSPACE")
            default: (p, r) = ("GENERIC_R\(min(ABNT2.row(of: code), 4))", "GENERIC")
            }
            bank.keys[code] = (pBuf[p]!, rBuf[r])
        }
        bank.fallback = (pBuf["GENERIC_R3"]!, rBuf["GENERIC"])
        return bank
    }
}
