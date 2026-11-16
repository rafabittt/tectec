import AppKit
import CoreGraphics

/// Escuta teclas do sistema todo via CGEventTap em modo *listen-only*
/// (precisa da permissão "Monitoramento de Entrada"; não altera nem bloqueia eventos).
/// Campos de senha (Secure Input) não chegam aqui — o macOS os esconde.
final class KeyMonitor {
    var onKey: ((UInt16, Bool) -> Void)?
    var ignoreRepeats = true

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var pressed = Set<UInt16>()

    var isRunning: Bool { tap != nil }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }
    static func requestPermission() { _ = CGRequestListenEventAccess() }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                          eventsOfInterest: CGEventMask(mask), callback: tapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    // Bits "device-dependent" de cada modificador (lado esquerdo/direito).
    private static let modifierBits: [UInt16: UInt64] = [
        56: 0x02, 60: 0x04,        // shift esq/dir
        59: 0x01, 62: 0x2000,      // control
        58: 0x20, 61: 0x40,        // option
        55: 0x08, 54: 0x10,        // command
        63: 0x800000,              // fn (maskSecondaryFn)
    ]

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch type {
        case .keyDown:
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if isRepeat && ignoreRepeats { return }
            if pressed.contains(code) && !isRepeat { return }
            pressed.insert(code)
            onKey?(code, true)
        case .keyUp:
            pressed.remove(code)
            onKey?(code, false)
        case .flagsChanged:
            if code == 57 { // caps lock: cada evento = um toque completo
                onKey?(code, true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.onKey?(code, false) }
                return
            }
            guard let bit = Self.modifierBits[code] else { return }
            let down = event.flags.rawValue & bit != 0
            if down { pressed.insert(code) } else { pressed.remove(code) }
            onKey?(code, down)
        default:
            break
        }
    }
}

private func tapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        monitor.reenable()
    } else {
        monitor.handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
