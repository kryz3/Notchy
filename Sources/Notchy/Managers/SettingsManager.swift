import AppKit

enum NotchTheme: String, CaseIterable {
    case solid = "Solid"
    case glass = "Glass"
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

    var musicPlayer: MusicPlayerSource {
        didSet { UserDefaults.standard.set(musicPlayer.rawValue, forKey: "notchy.musicPlayer") }
    }

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "notchy.language")
            L.lang = language
        }
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
        let mpRaw = UserDefaults.standard.string(forKey: "notchy.musicPlayer") ?? MusicPlayerSource.auto.rawValue
        musicPlayer = MusicPlayerSource(rawValue: mpRaw) ?? .auto
        let langRaw = UserDefaults.standard.string(forKey: "notchy.language") ?? AppLanguage.fr.rawValue
        let resolvedLang = AppLanguage(rawValue: langRaw) ?? .fr
        language = resolvedLang
        L.lang = resolvedLang
        queueSize = UserDefaults.standard.object(forKey: "notchy.queueSize") as? Int ?? 5
        terminalHistorySize = UserDefaults.standard.object(forKey: "notchy.terminalHistorySize") as? Int ?? 100
        musicHistorySize = UserDefaults.standard.object(forKey: "notchy.musicHistorySize") as? Int ?? 5
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
