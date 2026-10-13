import SwiftUI
import AppKit

private let accent = Color(red: 0.94, green: 0.32, blue: 0.36)
private func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light })
}
private let canvas = adaptive(NSColor(white: 0.975, alpha: 1), NSColor(red: 0.105, green: 0.105, blue: 0.12, alpha: 1))
private let surface = adaptive(.white, NSColor(red: 0.135, green: 0.135, blue: 0.15, alpha: 1))
private let sidebarColor = adaptive(NSColor(white: 0.945, alpha: 1), NSColor(red: 0.12, green: 0.12, blue: 0.135, alpha: 1))

private enum Page: String, CaseIterable, Identifiable {
    case buttons = "Pulsanti", launcher = "Launcher", mouse = "Mouse", permissions = "Permessi"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .buttons: return "gamecontroller"
        case .launcher: return "arrow.up.and.down.and.arrow.left.and.right"
        case .mouse: return "cursorarrow.motionlines"
        case .permissions: return "lock.shield"
        }
    }
    var subtitle: String {
        switch self {
        case .buttons: return "Assegna applicazioni e shortcut ai pulsanti del controller."
        case .launcher: return "Quattro direzioni. Due app per direzione."
        case .mouse: return "Personalizza il movimento del cursore."
        case .permissions: return "Gestisci l’accesso di Punto al sistema."
        }
    }
}
enum Theme: String, CaseIterable {
    case dark = "Scuro", light = "Chiaro", system = "Sistema"
    var appearance: NSAppearance? {
        switch self {
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        case .system: return nil
        }
    }
}
struct ButtonSetting: Identifiable {
    let id: Int
    let name: String
    let glyph: String
    let group: String
    let action: Int
    let primary: String
    let hold: String?
    let appPath: String?
    var color: Color {
        switch id {
        case 0: return .pink
        case 1: return .blue
        case 2: return .red
        case 3: return .mint
        default: return .secondary
        }
    }
}
final class SettingsModel: ObservableObject {
    let controller: PadMacUIController
    @Published var connected = false
    @Published var enabled = false
    @Published var trusted = false
    @Published var speed = 1100.0
    @Published var deadzone = 0.12
    @Published var buttons: [ButtonSetting] = []
    @Published var theme = Theme.dark
    @Published var launcherApps: [[String]] = Array(repeating: ["", ""], count: 4)
    @Published var launcherVisible = false
    @Published var launcherDirection = -1
    @Published var launcherSlot = -1
    private var lastSnapshot: NSDictionary?
    private var timer: Timer?
    init(controller: PadMacUIController, pollInterval: Double = 0.15) {
        self.controller = controller
        theme = Theme(rawValue: UserDefaults.standard.string(forKey: "uiTheme") ?? "") ?? .dark
        NSApp.appearance = theme.appearance
        refresh()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    deinit { timer?.invalidate() }
    func refresh() {
        let raw = controller.settingsSnapshot() as NSDictionary
        if lastSnapshot?.isEqual(raw) == true { return }
        lastSnapshot = raw
        connected = raw["connected"] as? Bool ?? false
        enabled = raw["enabled"] as? Bool ?? false
        trusted = raw["trusted"] as? Bool ?? false
        speed = raw["speed"] as? Double ?? 1100
        deadzone = raw["deadzone"] as? Double ?? 0.12
        launcherVisible = raw["launcherVisible"] as? Bool ?? false
        launcherDirection = raw["launcherDirection"] as? Int ?? -1
        launcherSlot = raw["launcherSlot"] as? Int ?? -1
        launcherApps = (0..<4).map { direction in
            let stored = raw["launcherApps"] as? [[String]] ?? []
            return (0..<2).map { slot in direction < stored.count && slot < stored[direction].count ? stored[direction][slot] : "" }
        }
        buttons = (raw["buttons"] as? [[String: Any]] ?? []).compactMap { row in
            guard let id = row["id"] as? Int, let name = row["name"] as? String else { return nil }
            return ButtonSetting(id: id, name: name, glyph: row["glyph"] as? String ?? "•",
                                 group: row["group"] as? String ?? "Altri pulsanti", action: row["action"] as? Int ?? 0,
                                 primary: row["primary"] as? String ?? "Nessuna azione",
                                 hold: row["hold"] as? String, appPath: row["appPath"] as? String)
        }
    }
    func setTheme(_ theme: Theme) { self.theme = theme; UserDefaults.standard.set(theme.rawValue, forKey: "uiTheme"); NSApp.appearance = theme.appearance }
    func toggle() { controller.toggleControl(); refresh() }
    func setSpeed(_ value: Double) { speed = (value / 25).rounded() * 25; controller.setMouseSpeed(speed, deadzone: deadzone) }
    func setDeadzone(_ value: Double) { deadzone = (value * 100).rounded() / 100; controller.setMouseSpeed(speed, deadzone: deadzone) }
    func assign(_ action: Int, to id: Int) { controller.assignAction(action, forButton: id); refresh() }
    func recordHold(_ id: Int) { controller.recordHold(forButton: id); refresh() }
    func removeHold(_ id: Int) { controller.removeHold(forButton: id); refresh() }
    func configureLauncher(_ direction: Int, slot: Int) { controller.configureLauncherDirection(direction, slot: slot); refresh() }
    func clearLauncher(_ direction: Int, slot: Int) { controller.clearLauncherDirection(direction, slot: slot); refresh() }
}

@objc(PadMacUI) final class PadMacUI: NSObject {
    @objc static func makeWindow(controller: PadMacUIController) -> NSWindow {
        let model = SettingsModel(controller: controller)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Punto"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 900, height: 600)
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        window.setFrameAutosaveName("PadMacSettingsCompact")
        return window
    }
    @objc static func makeLauncher(controller: PadMacUIController) -> NSPanel {
        let model = SettingsModel(controller: controller, pollInterval: 0.03)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: min(560, screen.width - 48), height: min(400, screen.height - 48)),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: PuntoLauncherView(model: model))
        return panel
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var page: Page = .buttons
    @State private var search = ""
    @State private var group = "Tutti"
    @State private var showHelp = false
    init(model: SettingsModel) {
        self.model = model
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--ui-page"), index + 1 < args.count {
            let pages: [String: Page] = ["mouse": .mouse, "buttons": .buttons, "launcher": .launcher, "permissions": .permissions]
            _page = State(initialValue: pages[args[index + 1]] ?? .buttons)
        }
        if let index = args.firstIndex(of: "--ui-group"), index + 1 < args.count {
            let value = args[index + 1]
            if ["Tutti", "Simboli", "Dorsali", "Altri pulsanti"].contains(value) { _group = State(initialValue: value) }
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                if page == .buttons { buttonSettings }
                else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if page == .mouse { mouseSettings }
                            else if page == .launcher { launcherSettings }
                            else { permissions }
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.background(canvas)
        }.tint(accent).frame(minWidth: 900, minHeight: 560).background(canvas)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                    .frame(width: 34, height: 34).accessibilityHidden(true)
                Text("Punto").font(.system(size: 17, weight: .semibold))
            }.padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 9) {
                Text("IMPOSTAZIONI").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundColor(.secondary).padding(.horizontal, 10)
                VStack(spacing: 3) {
                    ForEach(Page.allCases) { item in
                        Button { page = item } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.icon).font(.system(size: 14)).foregroundColor(page == item ? accent : .secondary).frame(width: 19)
                                Text(item.rawValue).font(.system(size: 12, weight: page == item ? .semibold : .regular))
                                Spacer()
                            }.foregroundColor(.primary).padding(.horizontal, 10).padding(.vertical, 10)
                                .background(page == item ? Color.primary.opacity(0.075) : .clear).cornerRadius(7).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    Image(systemName: "gamecontroller").foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DualSense").font(.system(size: 11, weight: .medium))
                        HStack(spacing: 5) {
                            Circle().fill(model.connected ? Color.green : Color.secondary).frame(width: 5, height: 5)
                            Text(model.connected ? "Collegato" : "Non collegato").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                Divider()
                HStack(spacing: 6) {
                    Text("OPTIONS").font(.system(size: 8, weight: .medium, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 3).background(Color.primary.opacity(0.06)).cornerRadius(4)
                    Text("Attiva / sospendi").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Menu {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Button { model.setTheme(theme) } label: {
                            if theme == model.theme { Label(theme.rawValue, systemImage: "checkmark") } else { Text(theme.rawValue) }
                        }
                    }
                } label: {
                    Label("Tema: \(model.theme.rawValue.lowercased())", systemImage: model.theme == .dark ? "moon" : "sun.max")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }.menuStyle(.borderlessButton).tint(.secondary)
            }.padding(.horizontal, 8)
        }.padding(.horizontal, 12).padding(.top, 49).padding(.bottom, 19).frame(width: 186).background(sidebarColor)
    }
    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(page.rawValue).font(.system(size: 21, weight: .semibold))
                Text(page.subtitle).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer(minLength: 5)
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle().fill(model.enabled ? Color.green : Color.secondary).frame(width: 5, height: 5)
                    Text(model.enabled ? "Attivo" : "Sospeso").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Button(action: model.toggle) {
                    Label(model.enabled ? "Sospendi" : "Attiva", systemImage: model.enabled ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .medium)).padding(.horizontal, 3).padding(.vertical, 2)
                }.buttonStyle(.borderedProminent).controlSize(.regular).help("Attiva o sospendi il controllo del Mac")
            }
        }.padding(.horizontal, 24).padding(.top, 46).padding(.bottom, 20)
    }
    private var buttonSettings: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(.secondary)
                    TextField("Cerca pulsanti, app o shortcut…", text: $search).textFieldStyle(.plain).font(.system(size: 12))
                    if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }.buttonStyle(.plain) }
                }.padding(9).card(radius: 6)
                Menu {
                    ForEach(["Tutti", "Simboli", "Dorsali", "Altri pulsanti"], id: \.self) { value in
                        Button { group = value } label: {
                            if value == group { Label(value, systemImage: "checkmark") } else { Text(value) }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "line.3.horizontal.decrease").foregroundColor(.secondary); Text(group).font(.system(size: 11)); Spacer() }
                        .padding(.horizontal, 9)
                }.menuStyle(.borderlessButton).tint(.primary).frame(width: 143, height: 33).card(radius: 6)
            }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16)
            HStack(spacing: 12) {
                Text("PULSANTE").frame(width: 180, alignment: .leading)
                Text("AZIONE PRINCIPALE").frame(maxWidth: .infinity, alignment: .leading)
                Text("PRESSIONE LUNGA · 0,45 S").frame(maxWidth: .infinity, alignment: .leading)
            }.font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                .padding(.horizontal, 38).padding(.bottom, 10)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if filteredButtons.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "magnifyingglass").font(.system(size: 24)).foregroundColor(.secondary)
                            Text("Nessun risultato").font(.system(size: 13, weight: .medium))
                            Text("Prova un altro nome o cambia gruppo.").font(.system(size: 11)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(32)
                    }
                    ForEach(["Simboli", "Dorsali", "Altri pulsanti"], id: \.self) { section in
                        let rows = filteredButtons.filter { $0.group == section }
                        if !rows.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).padding(.leading, 2)
                                VStack(spacing: 0) {
                                    ForEach(Array(rows.enumerated()), id: \.element.id) { offset, setting in
                                        buttonRow(setting)
                                        if offset < rows.count - 1 { Divider().padding(.leading, 14) }
                                    }
                                }.card(radius: 8)
                            }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 20)
            }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundColor(.secondary)
                Text("Frecce → Launcher · Options → attiva / sospendi · Salvataggio automatico")
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Spacer(minLength: 0)
                Button { showHelp.toggle() } label: { Image(systemName: "questionmark.circle").foregroundColor(.secondary) }.buttonStyle(.plain)
                    .help("Come funzionano tap e pressione lunga")
                    .popover(isPresented: $showHelp) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tap e pressione lunga").font(.system(size: 14, weight: .semibold))
                            Text("Senza pressione lunga assegnata, la shortcut viene premuta subito e resta attiva fino al rilascio del pulsante.")
                            Text("Con una pressione lunga assegnata, un tap esegue l’azione principale al rilascio. Superati 0,45 secondi si attiva solo la shortcut lunga, mantenuta fino al rilascio.")
                            Text("Cambiare un’assegnazione sospende il controllo per sicurezza. Premi Attiva per riprendere.").foregroundColor(.secondary)
                        }.font(.system(size: 12)).lineSpacing(3).padding(22).frame(width: 360)
                    }
            }.font(.system(size: 11)).padding(.horizontal, 24).padding(.vertical, 13)
        }
    }
    private var filteredButtons: [ButtonSetting] {
        model.buttons.filter { setting in
            setting.id < 15 && (group == "Tutti" || setting.group == group) &&
            (search.isEmpty || "\(setting.name) \(setting.primary) \(setting.hold ?? "")".localizedCaseInsensitiveContains(search))
        }
    }
    private func buttonRow(_ setting: ButtonSetting) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Text(setting.glyph).font(.system(size: setting.id < 4 ? 22 : 11, weight: .medium, design: .rounded))
                    .foregroundColor(setting.color).frame(width: 28, height: 28).background(Color.primary.opacity(0.035)).cornerRadius(6)
                Text(setting.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }.frame(width: 180, alignment: .leading)
            Menu {
                Button("Registra shortcut…") { model.assign(12, to: setting.id) }
                Button("Scegli applicazione…") { model.assign(11, to: setting.id) }
                Divider()
                if setting.id == 6 || setting.id == 7 {
                    Button(setting.id == 7 ? "Click sinistro (predefinito)" : "Click destro (predefinito)") { model.assign(0, to: setting.id) }
                }
                Button("Nessuna azione") { model.assign(10, to: setting.id) }
            } label: {
                HStack(spacing: 7) {
                    if setting.action == 11, let path = setting.appPath {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 15, height: 15)
                    } else {
                        Image(systemName: setting.action == 12 ? "command" : (setting.id == 6 || setting.id == 7) && setting.action == 0 ? "computermouse" : "minus.circle").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Text(setting.primary).font(.system(size: 11, weight: setting.action == 12 ? .medium : .regular)).lineLimit(1)
                        .foregroundColor(setting.action == 10 || setting.action == 0 && setting.id != 6 && setting.id != 7 ? .secondary : .primary)
                    Spacer(minLength: 0)
                }.frame(height: 20).padding(.horizontal, 8).padding(.vertical, 4)
            }.menuStyle(.borderlessButton).tint(setting.action == 10 || setting.action == 0 && setting.id != 6 && setting.id != 7 ? .secondary : .primary)
                .frame(height: 30).background(Color.primary.opacity(0.035)).cornerRadius(5)
                .frame(maxWidth: .infinity).help("Configura l’azione principale di \(setting.name)")
            Menu {
                Button(setting.hold == nil ? "Registra shortcut lunga…" : "Registra nuova shortcut…") { model.recordHold(setting.id) }
                if setting.hold != nil { Divider(); Button("Rimuovi shortcut lunga") { model.removeHold(setting.id) } }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: setting.hold == nil ? "plus" : "hand.tap").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(setting.hold ?? "Non assegnata").font(.system(size: 11, weight: setting.hold == nil ? .regular : .medium)).lineLimit(1).foregroundColor(setting.hold == nil ? .secondary : .primary)
                    Spacer(minLength: 0)
                }.frame(height: 20).padding(.horizontal, 8).padding(.vertical, 4)
            }.menuStyle(.borderlessButton).tint(setting.hold == nil ? .secondary : .primary)
                .frame(height: 30).background(Color.primary.opacity(0.035)).cornerRadius(5)
                .frame(maxWidth: .infinity).help("Registra o rimuovi la shortcut per la pressione lunga")
        }.padding(.horizontal, 14).padding(.vertical, 10)
            .help(setting.id == 12 || setting.id == 14 ? "La disponibilità di questo pulsante dipende da macOS e dal firmware." : setting.name)
    }
    private var launcherSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Navigazione direzionale", detail: "Una freccia apre subito l’app. Ripremila mentre l’overlay è visibile per aprire la seconda.")
            HStack(spacing: 18) {
                Label("Apertura automatica · nessuna conferma", systemImage: "bolt.fill")
                Label("○ chiude l’overlay", systemImage: "xmark.circle")
            }.font(.system(size: 11)).foregroundColor(.secondary)
            ForEach(0..<4, id: \.self) { direction in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 9) {
                        Text(["↑", "→", "↓", "←"][direction]).font(.system(size: 21, weight: .medium)).foregroundColor(accent)
                        Text(["Su", "Destra", "Giù", "Sinistra"][direction]).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("MAX 2 APP").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { slot in
                            let path = model.launcherApps[direction][slot]
                            Menu {
                                Button(path.isEmpty ? "Scegli applicazione…" : "Cambia applicazione…") { model.configureLauncher(direction, slot: slot) }
                                if !path.isEmpty { Divider(); Button("Rimuovi applicazione") { model.clearLauncher(direction, slot: slot) } }
                            } label: {
                                HStack(spacing: 9) {
                                    if !path.isEmpty { Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 20, height: 20) }
                                    else { Image(systemName: "plus.app").font(.system(size: 17)).foregroundColor(.secondary) }
                                    Text(path.isEmpty ? "App \(slot + 1) · Scegli applicazione…" : "\(slot + 1) · \(FileManager.default.displayName(atPath: path))")
                                        .font(.system(size: 11)).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.padding(11)
                            }.menuStyle(.borderlessButton).tint(path.isEmpty ? .secondary : .primary).frame(height: 39)
                                .background(Color.primary.opacity(0.035)).cornerRadius(6).frame(maxWidth: .infinity)
                        }
                    }
                }.padding(18).card(radius: 8)
            }
            Text("Il controllo deve essere attivo. L’overlay scompare dopo 1,2 s. Le frecce aprono le app; ✕ e ○ non eseguono le shortcut mentre è visibile. Le precedenti assegnazioni delle frecce sono conservate ma non vengono eseguite; eventuali app già assegnate sono migrate nello slot 1.")
                .font(.system(size: 10)).foregroundColor(.secondary).lineSpacing(3)
        }
    }
    private var mouseSettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Joystick destro", detail: "Il movimento usa accelerazione progressiva per migliorare la precisione.")
            VStack(alignment: .leading, spacing: 22) {
                sliderSetting("Velocità", description: "Velocità massima del cursore", value: String(format: "%.0f pt/s", model.speed)) {
                    Slider(value: Binding(get: { model.speed }, set: model.setSpeed), in: 200...2600)
                }
                Divider()
                sliderSetting("Zona morta", description: "Ignora i piccoli movimenti a riposo", value: String(format: "%.0f %%", model.deadzone * 100)) {
                    Slider(value: Binding(get: { model.deadzone }, set: model.setDeadzone), in: 0.03...0.4)
                }
            }.padding(20).card(radius: 8)
            heading("Touchpad", detail: "Scorri un dito per muovere il mouse. Sollevalo per riposizionarlo.")
            HStack {
                Text("Sensibilità").font(.system(size: 12))
                Spacer()
                Text("0,8 pt / unità").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }.padding(18).card(radius: 8)
            heading("Click e trascinamento", detail: "R2 è il click sinistro, L2 il destro. Mantieni premuto per trascinare.")
            HStack {
                Label("Le assegnazioni sono modificabili nella sezione Pulsanti.", systemImage: "computermouse").font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Button("Pulsanti") { page = .buttons }.buttonStyle(.bordered).controlSize(.small)
            }.padding(18).card(radius: 8)
        }
    }
    private func sliderSetting<Content: View>(_ title: String, description: String, value: String, @ViewBuilder slider: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(description).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.primary.opacity(0.05)).cornerRadius(5)
            }
            slider()
        }
    }
    private var permissions: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Accessibilità", detail: "Necessaria per controllare mouse e tastiera tramite il controller.")
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: model.trusted ? "checkmark.shield" : "lock.shield").font(.system(size: 27)).foregroundColor(model.trusted ? .green : accent)
                VStack(alignment: .leading, spacing: 9) {
                    Text(model.trusted ? "Punto è autorizzato" : "Autorizzazione necessaria").font(.system(size: 13, weight: .medium))
                    Text("Privacy e sicurezza → Accessibilità → Punto").font(.system(size: 11)).foregroundColor(.secondary)
                    Button("Apri impostazioni Accessibilità") { model.controller.openAccessibility(); model.refresh() }.buttonStyle(.bordered).controlSize(.small)
                }
                Spacer()
            }.padding(20).card(radius: 8)
            heading("Connessione e sicurezza", detail: "Punto elabora gli input localmente e parte sempre sospeso.")
            VStack(alignment: .leading, spacing: 17) {
                instruction("cable.connector", title: "USB o Bluetooth", detail: "Usa un cavo USB dati. Per l’abbinamento Bluetooth, tieni premuti PS + Create fino al lampeggio.")
                Divider()
                instruction("keyboard", title: "Monitoraggio input", detail: "Autorizzalo nelle impostazioni di Privacy e sicurezza se macOS lo richiede.")
                Divider()
                instruction("pause.circle", title: "Options sospende il controllo", detail: "Sospensione, disconnessione e uscita normale rilasciano tutte le shortcut mantenute.")
            }.padding(20).card(radius: 8)
        }
    }
    private func instruction(_ icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(3)
            }
        }
    }
    private func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .medium))
            Text(detail).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}
private extension View {
    func card(radius: CGFloat = 8) -> some View {
        self.background(surface).clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }
}
