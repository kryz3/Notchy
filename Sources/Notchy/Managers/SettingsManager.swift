import AppKit

enum NotchTheme: String, CaseIterable {
    case solid = "Solid"
    case glass = "Glass"
}

enum AccentColor: String, CaseIterable {
    case white = "White"
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case red = "Red"
    case yellow = "Yellow"
    case sand = "Sand"

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .white:  return (1.0, 1.0, 1.0)
        case .blue:   return (0.3, 0.55, 1.0)
        case .purple: return (0.65, 0.4, 1.0)
        case .green:  return (0.3, 0.85, 0.45)
        case .orange: return (1.0, 0.6, 0.2)
        case .pink:   return (1.0, 0.4, 0.6)
        case .red:    return (1.0, 0.3, 0.3)
        case .yellow: return (1.0, 0.85, 0.2)
        case .sand:   return (0.82, 0.72, 0.55)
        }
    }
}

enum CompactStyle: String, CaseIterable {
    case off = "Off"
    case musicOnly = "Music"
}

enum MusicPlayerSource: String, CaseIterable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case auto = "Auto"
}

@Observable
final class SettingsManager {
    var theme: NotchTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "notchy.theme") }
    }

    var queueSize: Int {
        didSet { UserDefaults.standard.set(queueSize, forKey: "notchy.queueSize") }
    }

    var terminalHistorySize: Int {
        didSet { UserDefaults.standard.set(terminalHistorySize, forKey: "notchy.terminalHistorySize") }
    }

    var musicHistorySize: Int {
        didSet { UserDefaults.standard.set(musicHistorySize, forKey: "notchy.musicHistorySize") }
    }

    var accentColor: AccentColor {
        didSet { UserDefaults.standard.set(accentColor.rawValue, forKey: "notchy.accent") }
    }

    var compactMode: CompactStyle {
        didSet { UserDefaults.standard.set(compactMode.rawValue, forKey: "notchy.compact") }
    }

    var musicPlayer: MusicPlayerSource {
        didSet { UserDefaults.standard.set(musicPlayer.rawValue, forKey: "notchy.musicPlayer") }
    }

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "notchy.language")
            L.lang = language
        }
    }

    var hiddenCalendarIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenCalendarIds), forKey: "notchy.hiddenCalendars")
        }
    }

    var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "notchy.showBattery") }
    }
    var showCPU: Bool {
        didSet { UserDefaults.standard.set(showCPU, forKey: "notchy.showCPU") }
    }
    var showRAM: Bool {
        didSet { UserDefaults.standard.set(showRAM, forKey: "notchy.showRAM") }
    }
    var showBluetooth: Bool {
        didSet { UserDefaults.standard.set(showBluetooth, forKey: "notchy.showBluetooth") }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "notchy.launchAtLogin")
            if launchAtLogin { installLaunchAgent() } else { removeLaunchAgent() }
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "notchy.theme") ?? NotchTheme.solid.rawValue
        theme = NotchTheme(rawValue: raw) ?? .solid
        let acRaw = UserDefaults.standard.string(forKey: "notchy.accent") ?? AccentColor.white.rawValue
        accentColor = AccentColor(rawValue: acRaw) ?? .white
        let compRaw = UserDefaults.standard.string(forKey: "notchy.compact") ?? CompactStyle.off.rawValue
        compactMode = CompactStyle(rawValue: compRaw) ?? .off
        let mpRaw = UserDefaults.standard.string(forKey: "notchy.musicPlayer") ?? MusicPlayerSource.auto.rawValue
        musicPlayer = MusicPlayerSource(rawValue: mpRaw) ?? .auto
        let langRaw = UserDefaults.standard.string(forKey: "notchy.language") ?? AppLanguage.fr.rawValue
        let resolvedLang = AppLanguage(rawValue: langRaw) ?? .fr
        language = resolvedLang
        L.lang = resolvedLang
        queueSize = UserDefaults.standard.object(forKey: "notchy.queueSize") as? Int ?? 5
        terminalHistorySize = UserDefaults.standard.object(forKey: "notchy.terminalHistorySize") as? Int ?? 100
        musicHistorySize = UserDefaults.standard.object(forKey: "notchy.musicHistorySize") as? Int ?? 5
        showBattery = UserDefaults.standard.bool(forKey: "notchy.showBattery")
        showCPU = UserDefaults.standard.bool(forKey: "notchy.showCPU")
        showRAM = UserDefaults.standard.bool(forKey: "notchy.showRAM")
        showBluetooth = UserDefaults.standard.bool(forKey: "notchy.showBluetooth")
        let hiddenCals = UserDefaults.standard.stringArray(forKey: "notchy.hiddenCalendars") ?? []
        hiddenCalendarIds = Set(hiddenCals)
        launchAtLogin = UserDefaults.standard.bool(forKey: "notchy.launchAtLogin")
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Launch Agent

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.notchy.app.plist")
    }

    private var appPath: String {
        Bundle.main.bundlePath
    }

    private func installLaunchAgent() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.notchy.app</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        do {
            let dir = launchAgentURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try plist.write(to: launchAgentURL, atomically: true, encoding: .utf8)
            Log.info("[Settings] LaunchAgent installed at \(launchAgentURL.path)")
        } catch {
            Log.info("[Settings] Failed to install LaunchAgent: \(error)")
        }
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: launchAgentURL)
        Log.info("[Settings] LaunchAgent removed")
    }
}
