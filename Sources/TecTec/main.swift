import AppKit
import ServiceManagement
import Sparkle

final class Settings {
    private let d = UserDefaults.standard
    init() {
        d.register(defaults: [
            "enabled": true, "profile": SwitchInfo.defaultID, "spatial": true, "headphones": false,
            "pitch": true, "upSounds": true, "ignoreRepeats": true, "fixedVolume": true,
        ])
    }
    var enabled: Bool { get { d.bool(forKey: "enabled") } set { d.set(newValue, forKey: "enabled") } }
    var profile: String { get { d.string(forKey: "profile") ?? SwitchInfo.defaultID } set { d.set(newValue, forKey: "profile") } }
    /// Volume do TecTec (0…1 na escala em dB). Migra o "volume" linear da 1.0.0.
    var volumeLevel: Float {
        get {
            if d.object(forKey: "volumeLevel") != nil { return d.float(forKey: "volumeLevel") }
            if d.object(forKey: "volume") != nil { return Volume.level(fromLinear: d.float(forKey: "volume")) }
            return Volume.unity
        }
        set { d.set(newValue, forKey: "volumeLevel") }
    }
    /// O TecTec compensa as mudanças no volume do Mac para soar sempre igual.
    var fixedVolume: Bool { get { d.bool(forKey: "fixedVolume") } set { d.set(newValue, forKey: "fixedVolume") } }
    /// Volume do Mac (dB) de referência: o TecTec soa como se o Mac estivesse sempre nesse volume.
    var volumeAnchorDB: Float? {
        get { d.object(forKey: "volumeAnchorDB") == nil ? nil : d.float(forKey: "volumeAnchorDB") }
        set { if let v = newValue { d.set(v, forKey: "volumeAnchorDB") } else { d.removeObject(forKey: "volumeAnchorDB") } }
    }
    var spatial: Bool { get { d.bool(forKey: "spatial") } set { d.set(newValue, forKey: "spatial") } }
    var headphones: Bool { get { d.bool(forKey: "headphones") } set { d.set(newValue, forKey: "headphones") } }
    var pitch: Bool { get { d.bool(forKey: "pitch") } set { d.set(newValue, forKey: "pitch") } }
    var upSounds: Bool { get { d.bool(forKey: "upSounds") } set { d.set(newValue, forKey: "upSounds") } }
    var ignoreRepeats: Bool { get { d.bool(forKey: "ignoreRepeats") } set { d.set(newValue, forKey: "ignoreRepeats") } }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let sound = SoundEngine()
    private let keys = KeyMonitor()
    private let systemVolume = SystemVolume()
    private var statusItem: NSStatusItem!
    private var retryTimer: Timer?
    private var previewWork: [DispatchWorkItem] = []
    /// Atualizações via Sparkle: lê appcast.xml no GitHub e verifica sozinho (1x por dia).
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        sound.level = settings.volumeLevel
        systemVolume.onChange = { [weak self] in self?.updateCompensation() }
        systemVolume.onDeviceChange = { [weak self] in self?.resetVolumeAnchor() }
        updateCompensation()
        sound.spatial = settings.spatial
        sound.headphones = settings.headphones
        sound.pitchVariation = settings.pitch
        keys.ignoreRepeats = settings.ignoreRepeats
        loadProfile(settings.profile, preview: false)

        keys.onKey = { [weak self] code, down in
            guard let self, self.settings.enabled else { return }
            if !down && !self.settings.upSounds { return }
            self.sound.play(keyCode: code, isDown: down)
        }
        startMonitoring()
    }

    // MARK: - Permissão / monitor

    private func startMonitoring() {
        if keys.start() { retryTimer?.invalidate(); retryTimer = nil; updateIcon(); return }
        if !KeyMonitor.hasPermission { KeyMonitor.requestPermission() }
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.keys.start() { self.retryTimer?.invalidate(); self.retryTimer = nil; self.updateIcon() }
        }
    }

    private func updateIcon() {
        let img: NSImage?
        if keys.isRunning {
            img = Self.menuBarIcon
        } else {
            img = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "TecTec sem permissão")
            img?.isTemplate = true
        }
        statusItem.button?.image = img
        statusItem.button?.appearsDisabled = !settings.enabled
    }

    /// Ícone da barra de menus: tecla com Ç, desenhada como template (segue modo claro/escuro).
    static let menuBarIcon: NSImage = {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let key = rect.insetBy(dx: 1.4, dy: 1.4)
            let path = NSBezierPath(roundedRect: key, xRadius: 4.2, yRadius: 4.2)
            path.lineWidth = 1.6
            NSColor.black.setStroke()
            path.stroke()
            let font = NSFont.systemFont(ofSize: 10.5, weight: .bold)
            let str = NSAttributedString(string: "Ç", attributes: [.font: font, .foregroundColor: NSColor.black])
            let size = str.size()
            str.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - font.capHeight / 2 + font.descender + 0.8))
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "TecTec"
        return img
    }()

    // MARK: - Volume independente do Mac

    /// Cancela a mudança do volume do Mac: se ele subiu 10 dB, o TecTec abaixa 10 dB (e vice-versa,
    /// até o limite do reforço). Com o Mac no mudo não há o que fazer, então nada muda.
    private func updateCompensation() {
        guard settings.fixedVolume else { sound.compensationDB = 0; return }
        guard let now = systemVolume.decibels else { return }
        let anchor = settings.volumeAnchorDB ?? now
        if settings.volumeAnchorDB == nil { settings.volumeAnchorDB = now }
        sound.compensationDB = anchor - now
    }

    /// Volume de referência = o volume atual do Mac (o TecTec fica como está agora).
    private func resetVolumeAnchor() {
        settings.volumeAnchorDB = systemVolume.decibels
        updateCompensation()
    }

    // MARK: - Sons

    private func loadProfile(_ id: String, preview: Bool) {
        if id.hasPrefix("pack:") {
            let name = String(id.dropFirst(5))
            let dir = CustomPacks.folder.appendingPathComponent(name)
            do {
                sound.bank = try CustomPacks.load(dir)
            } catch {
                alert("Não consegui carregar o pacote “\(name)”", error.localizedDescription)
                loadProfile(SwitchInfo.defaultID, preview: false)
                return
            }
        } else {
            let info = SwitchInfo.byID(id) ?? SwitchInfo.byID(SwitchInfo.defaultID)!
            do {
                sound.bank = try SwitchBank.load(info)
            } catch {
                alert("Não consegui carregar o switch “\(info.name)”", error.localizedDescription)
                return
            }
            settings.profile = info.id
            if preview { playPreview() }
            return
        }
        settings.profile = id
        if preview { playPreview() }
    }

    /// Mesma ideia do demo do site do Klack: digita uma palavra com down/up espaçados.
    private func playPreview() {
        previewWork.forEach { $0.cancel() }
        previewWork = []
        var t = 0.0
        for ch in "TECTEC BRASIL\n" {
            guard let code = ABNT2.letters[ch] else { continue }
            let down = DispatchWorkItem { [weak self] in self?.sound.play(keyCode: code, isDown: true) }
            let up = DispatchWorkItem { [weak self] in self?.sound.play(keyCode: code, isDown: false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: down)
            DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.075, execute: up)
            previewWork += [down, up]
            t += ch == " " ? 0.32 : 0.16
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: keys.isRunning ? "TecTec" : "TecTec — sem permissão", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if !keys.isRunning {
            menu.addItem(item("⚠️ Permitir “Monitoramento de Entrada”…", #selector(openPermissions)))
            menu.addItem(item("Reiniciar TecTec", #selector(relaunch)))
        }

        let toggle = item("Sons ativados", #selector(toggleEnabled), key: "")
        toggle.state = settings.enabled ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        for type in SwitchType.allCases {
            let header = NSMenuItem(title: type.rawValue, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for p in SwitchInfo.all where p.type == type {
                let mi = item(p.name, #selector(selectProfile(_:)))
                mi.representedObject = p.id
                mi.state = settings.profile == p.id ? .on : .off
                mi.toolTip = p.sound
                let title = NSMutableAttributedString(string: p.name, attributes: [.font: NSFont.menuFont(ofSize: 0)])
                title.append(NSAttributedString(string: "  " + p.sound, attributes: [
                    .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor]))
                mi.attributedTitle = title
                mi.indentationLevel = 1
                menu.addItem(mi)
            }
        }
        menu.addItem(.separator())

        let packs = CustomPacks.list()
        let packsItem = NSMenuItem(title: "Pacotes personalizados", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for dir in packs {
            let id = "pack:" + dir.lastPathComponent
            let mi = item(dir.lastPathComponent, #selector(selectProfile(_:)))
            mi.representedObject = id
            mi.state = settings.profile == id ? .on : .off
            sub.addItem(mi)
        }
        if packs.isEmpty {
            let none = NSMenuItem(title: "Nenhum pacote ainda", action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        }
        sub.addItem(.separator())
        sub.addItem(item("Abrir pasta de pacotes…", #selector(openPacks)))
        packsItem.submenu = sub
        menu.addItem(packsItem)
        menu.addItem(item("Tocar prévia", #selector(preview), key: "p"))

        menu.addItem(.separator())
        menu.addItem(volumeItem())

        let opts = NSMenuItem(title: "Opções", action: nil, keyEquivalent: "")
        let om = NSMenu()
        om.addItem(check("Áudio espacial (posição da tecla)", settings.spatial, #selector(toggleSpatial)))
        om.addItem(check("Modo fone de ouvido (HRTF imersivo)", settings.headphones, #selector(toggleHeadphones)))
        let fixed = check("Volume fixo (ignora o volume do Mac)", settings.fixedVolume, #selector(toggleFixedVolume))
        fixed.toolTip = "O TecTec compensa quando você muda o volume do Mac, e o teclado continua soando igual. Ajuste o volume dele pela barra acima."
        om.addItem(fixed)
        om.addItem(check("Variação aleatória de tom", settings.pitch, #selector(togglePitch)))
        om.addItem(check("Som ao soltar a tecla", settings.upSounds, #selector(toggleUp)))
        om.addItem(check("Ignorar tecla segurada (repetição)", settings.ignoreRepeats, #selector(toggleRepeats)))
        om.addItem(.separator())
        om.addItem(check("Abrir ao iniciar o Mac", SMAppService.mainApp.status == .enabled, #selector(toggleLogin)))
        opts.submenu = om
        menu.addItem(opts)

        menu.addItem(.separator())
        let upd = NSMenuItem(title: "Procurar atualizações…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        upd.target = updater
        menu.addItem(upd)
        menu.addItem(item("Sobre o TecTec", #selector(about)))
        menu.addItem(item("Sair", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        mi.target = self
        return mi
    }

    private func check(_ title: String, _ on: Bool, _ sel: Selector) -> NSMenuItem {
        let mi = item(title, sel)
        mi.state = on ? .on : .off
        return mi
    }

    private var volumeLabel: NSTextField?
    private var lastVolumeTick = Date.distantPast

    private func volumeItem() -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 30))
        let low = NSImageView(frame: NSRect(x: 16, y: 7, width: 16, height: 16))
        low.image = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: nil)
        low.contentTintColor = .secondaryLabelColor
        let slider = NSSlider(value: Double(settings.volumeLevel), minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
        slider.frame = NSRect(x: 38, y: 5, width: 172, height: 20)
        slider.isContinuous = true
        // marquinha no som original (100%)
        slider.numberOfTickMarks = 4
        slider.allowsTickMarkValuesOnly = false
        slider.toolTip = "Volume do TecTec. 100% = som original; acima disso o TecTec reforça o som. Com “Volume fixo” ligado, mudar o volume do Mac não altera o TecTec."
        let label = NSTextField(labelWithString: "\(Volume.percent(settings.volumeLevel))%")
        label.frame = NSRect(x: 214, y: 6, width: 52, height: 18)
        label.alignment = .right
        label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        label.textColor = .secondaryLabelColor
        volumeLabel = label
        view.addSubview(low); view.addSubview(slider); view.addSubview(label)
        let mi = NSMenuItem()
        mi.view = view
        return mi
    }

    // MARK: - Ações

    @objc private func toggleEnabled() { settings.enabled.toggle(); updateIcon() }
    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        loadProfile(id, preview: true)
    }
    @objc private func preview() { playPreview() }
    @objc private func volumeChanged(_ s: NSSlider) {
        settings.volumeLevel = s.floatValue
        sound.level = s.floatValue
        volumeLabel?.stringValue = "\(Volume.percent(s.floatValue))%"
        // um "tec" enquanto arrasta, para ouvir o nível na hora
        if Date().timeIntervalSince(lastVolumeTick) > 0.12 {
            lastVolumeTick = Date()
            sound.play(keyCode: 40, isDown: true)
        }
    }
    @objc private func toggleSpatial() { settings.spatial.toggle(); sound.spatial = settings.spatial }
    @objc private func toggleHeadphones() { settings.headphones.toggle(); sound.headphones = settings.headphones }
    @objc private func toggleFixedVolume() {
        settings.fixedVolume.toggle()
        if settings.fixedVolume { resetVolumeAnchor() } else { updateCompensation() }
    }
    @objc private func togglePitch() { settings.pitch.toggle(); sound.pitchVariation = settings.pitch }
    @objc private func toggleUp() { settings.upSounds.toggle() }
    @objc private func toggleRepeats() { settings.ignoreRepeats.toggle(); keys.ignoreRepeats = settings.ignoreRepeats }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            alert("Não deu para alterar a abertura automática", "Mova o TecTec.app para a pasta Aplicativos e tente de novo.\n\n\(error.localizedDescription)")
        }
    }
    @objc private func openPacks() { NSWorkspace.shared.open(CustomPacks.folder) }
    @objc private func openPermissions() {
        KeyMonitor.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func relaunch() {
        let path = Bundle.main.bundlePath
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 0.6; /usr/bin/open \"$0\"", path]
        try? p.run()
        NSApp.terminate(nil)
    }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "TecTec",
            .credits: NSAttributedString(string: "Som de teclado mecânico em cada tecla, feito para o layout ABNT2.\nSons: gravações reais de switches do projeto kbsim (github.com/tplai/kbsim), licença MIT, © Thomas Lai."),
        ])
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
