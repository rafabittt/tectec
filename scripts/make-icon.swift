// Gera Resources/AppIcon.icns: tecla amarela com Ç sobre fundo escuro.
// Uso: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    // Fundo no grid de ícones do macOS (824 px com margem de 100).
    let bg = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: bg, xRadius: 185 * s, yRadius: 185 * s).fill()
    // Tecla
    let key = NSRect(x: 232 * s, y: 232 * s, width: 560 * s, height: 560 * s)
    NSColor(srgbRed: 1, green: 0xD4 / 255, blue: 0x3B / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: key, xRadius: 124 * s, yRadius: 124 * s).fill()
    // Ç
    let font = NSFont.systemFont(ofSize: 380 * s, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255, alpha: 1)]
    let str = NSAttributedString(string: "Ç", attributes: attrs)
    let size = str.size()
    // centraliza pela caixa do "C" (a cedilha desce abaixo da linha de base)
    let capH = font.capHeight
    let x = key.midX - size.width / 2
    let baseline = key.midY - capH / 2 + 30 * s
    str.draw(at: NSPoint(x: x, y: baseline + font.descender))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(1024).write(to: root.appendingPathComponent("Resources/icon-1024.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try p.run(); p.waitUntilExit()
print("Ícone gerado em Resources/AppIcon.icns")
