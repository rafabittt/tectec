import AudioToolbox
import CoreAudio
import Foundation

/// Acompanha o volume do Mac (saída padrão) em decibéis, para o TecTec compensar e soar sempre igual.
/// Avisa em `onChange` quando o volume, o mudo ou o dispositivo de saída mudam.
final class SystemVolume {
    var onChange: (() -> Void)?
    /// Trocou o dispositivo de saída (ex.: conectou um fone).
    var onDeviceChange: (() -> Void)?
    private var device = AudioObjectID(kAudioObjectUnknown)
    private let queue = DispatchQueue.main
    private lazy var deviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.onChange?() }
    private lazy var defaultListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.attach()
        self?.onDeviceChange?()
        self?.onChange?()
    }

    private static let watched: [AudioObjectPropertySelector] = [
        kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyVolumeDecibels,
        kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute,
    ]

    init() {
        var a = Self.addr(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, queue, defaultListener)
        attach()
    }

    /// Atenuação atual do Mac em dB (0 = volume máximo, negativo = mais baixo). nil = mudo ou volume zero.
    var decibels: Float? {
        if read(kAudioDevicePropertyMute, UInt32.self) == 1 { return nil }
        // 1) o próprio aparelho informa em dB (mais exato)
        if let db: Float32 = read(kAudioDevicePropertyVolumeDecibels, Float32.self, element: kAudioObjectPropertyElementMain) { return db }
        if let db: Float32 = read(kAudioDevicePropertyVolumeDecibels, Float32.self, element: 1) { return db }
        // 2) volume "virtual" em escala 0…1 (ex.: Bluetooth); curva aproximada de volume perceptual
        if let v: Float32 = read(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, Float32.self) {
            return v <= 0.001 ? nil : 40 * log10(v)
        }
        return 0   // sem controle de volume (ex.: HDMI): nada a compensar
    }

    private func attach() {
        for sel in Self.watched {
            var a = Self.addr(sel, kAudioDevicePropertyScopeOutput)
            if device != kAudioObjectUnknown { AudioObjectRemovePropertyListenerBlock(device, &a, queue, deviceListener) }
        }
        var a = Self.addr(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)
        var d = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &d)
        device = d
        guard d != kAudioObjectUnknown else { return }
        for sel in Self.watched {
            var a = Self.addr(sel, kAudioDevicePropertyScopeOutput)
            if AudioObjectHasProperty(d, &a) { AudioObjectAddPropertyListenerBlock(d, &a, queue, deviceListener) }
        }
    }

    private func read<T>(_ sel: AudioObjectPropertySelector, _: T.Type, element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> T? {
        guard device != kAudioObjectUnknown else { return nil }
        var a = Self.addr(sel, kAudioDevicePropertyScopeOutput, element)
        guard AudioObjectHasProperty(device, &a) else { return nil }
        let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { value.deallocate() }
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(device, &a, 0, nil, &size, value) == noErr ? value.pointee : nil
    }

    private static func addr(_ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope,
                             _ el: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: el)
    }
}
