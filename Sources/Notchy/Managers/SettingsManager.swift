import Foundation

enum NotchTheme: String, CaseIterable {
    case solid = "Solid"
    case glass = "Glass"
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

    init() {
        let raw = UserDefaults.standard.string(forKey: "notchy.theme") ?? NotchTheme.solid.rawValue
        theme = NotchTheme(rawValue: raw) ?? .solid
        queueSize = UserDefaults.standard.object(forKey: "notchy.queueSize") as? Int ?? 5
        terminalHistorySize = UserDefaults.standard.object(forKey: "notchy.terminalHistorySize") as? Int ?? 100
        musicHistorySize = UserDefaults.standard.object(forKey: "notchy.musicHistorySize") as? Int ?? 5
    }
}
