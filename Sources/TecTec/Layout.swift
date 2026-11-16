import Foundation

/// Layout físico ABNT2 (ISO brasileiro) usado para posicionar cada tecla no espaço estéreo.
/// Códigos são kVK_* do macOS (virtual key codes).
enum ABNT2 {
    /// (keyCode, largura em unidades de tecla). keyCode -1 = espaço vazio.
    private static let rows: [[(Int, Float)]] = [
        // Esc F1…F12
        [(53, 1), (-1, 0.5), (122, 1), (120, 1), (99, 1), (118, 1), (-1, 0.5), (96, 1), (97, 1), (98, 1), (100, 1), (-1, 0.5), (101, 1), (109, 1), (103, 1), (111, 1)],
        // ' 1 2 3 4 5 6 7 8 9 0 - = ⌫
        [(10, 1), (18, 1), (19, 1), (20, 1), (21, 1), (23, 1), (22, 1), (26, 1), (28, 1), (25, 1), (29, 1), (27, 1), (24, 1), (51, 2)],
        // ⇥ Q W E R T Y U I O P ´ [ ⏎
        [(48, 1.5), (12, 1), (13, 1), (14, 1), (15, 1), (17, 1), (16, 1), (32, 1), (34, 1), (31, 1), (35, 1), (33, 1), (30, 1), (36, 1.5)],
        // ⇪ A S D F G H J K L Ç ~ ]
        [(57, 1.75), (0, 1), (1, 1), (2, 1), (3, 1), (5, 1), (4, 1), (38, 1), (40, 1), (37, 1), (41, 1), (39, 1), (42, 1), (36, 1.25)],
        // ⇧ \ Z X C V B N M , . ; /? ⇧
        [(56, 1.25), (50, 1), (6, 1), (7, 1), (8, 1), (9, 1), (11, 1), (45, 1), (46, 1), (43, 1), (47, 1), (44, 1), (94, 1), (60, 1.75)],
        // fn ⌃ ⌥ ⌘ espaço ⌘ ⌥ ← ↓ →
        [(63, 1), (59, 1), (58, 1), (55, 1.25), (49, 5.5), (54, 1.25), (61, 1), (123, 1), (125, 1), (124, 1)],
    ]

    /// Posição normalizada: x em -1…1 (esq→dir), y em 0…1 (cima→baixo).
    static let positions: [UInt16: (x: Float, y: Float)] = {
        var map: [UInt16: (Float, Float)] = [:]
        let total: Float = 15
        for (r, row) in rows.enumerated() {
            var x: Float = 0
            for (code, w) in row {
                let center = x + w / 2
                if code >= 0, map[UInt16(code)] == nil {
                    map[UInt16(code)] = ((center / total) * 2 - 1, Float(r) / Float(rows.count - 1))
                }
                x += w
            }
        }
        map[126] = (map[125]?.0 ?? 0.86, 0.85) // ↑
        // Teclas extras (Home/End/PgUp/PgDn/Del/keypad) ficam à direita
        for code in [115, 116, 117, 119, 121, 114] { map[UInt16(code)] = (1.0, 0.3) }
        for code in [65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92] { map[UInt16(code)] = (1.0, 0.6) }
        return map
    }()

    static func pan(for keyCode: UInt16) -> Float { positions[keyCode]?.x ?? 0 }

    /// Fileira física (0 = F1…F12, 1 = números, 2 = QWERTY, 3 = ASDF, 4 = ZXCV, 5 = espaço).
    static let rows_: [UInt16: Int] = {
        var m: [UInt16: Int] = [:]
        for (r, row) in rows.enumerated() { for (code, _) in row where code >= 0 && m[UInt16(code)] == nil { m[UInt16(code)] = r } }
        return m
    }()
    static func row(of keyCode: UInt16) -> Int { rows_[keyCode] ?? 3 }

    /// Nome amigável, usado só no preview.
    static let letters: [Character: UInt16] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9, "B": 11,
        "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "O": 31, "U": 32, "I": 34, "P": 35,
        "L": 37, "J": 38, "K": 40, "N": 45, "M": 46, "Ç": 41, " ": 49, "\n": 36,
    ]
}

/// Mapeamento kVK (macOS) → códigos estilo libuiohook / scancode PC.
/// É o mesmo esquema que o Klack usa nos samples do site (ex.: 37 = K, 3675 = ⌘)
/// e que os pacotes do Mechvibes usam, então pacotes desses formatos funcionam.
enum UIOHook {
    static let fromMac: [UInt16: Int] = [
        53: 1, 18: 2, 19: 3, 20: 4, 21: 5, 23: 6, 22: 7, 26: 8, 28: 9, 25: 10, 29: 11, 27: 12, 24: 13, 51: 14,
        48: 15, 12: 16, 13: 17, 14: 18, 15: 19, 17: 20, 16: 21, 32: 22, 34: 23, 31: 24, 35: 25, 33: 26, 30: 27, 36: 28,
        59: 29, 0: 30, 1: 31, 2: 32, 3: 33, 5: 34, 4: 35, 38: 36, 40: 37, 37: 38, 41: 39, 39: 40, 10: 41,
        56: 42, 42: 43, 6: 44, 7: 45, 8: 46, 9: 47, 11: 48, 45: 49, 46: 50, 43: 51, 47: 52, 44: 53, 60: 54,
        58: 56, 49: 57, 57: 58,
        122: 59, 120: 60, 99: 61, 118: 62, 96: 63, 97: 64, 98: 65, 100: 66, 101: 67, 109: 68, 103: 87, 111: 88,
        50: 86, 94: 115,
        55: 3675, 54: 3676, 61: 3640, 62: 3613, 76: 3612,
        117: 3667, 115: 3655, 119: 3663, 116: 3657, 121: 3665,
        126: 57416, 123: 57419, 124: 57421, 125: 57424,
    ]
}
