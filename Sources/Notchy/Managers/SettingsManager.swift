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

    init() {
        let raw = UserDefaults.standard.string(forKey: "notchy.theme") ?? NotchTheme.solid.rawValue
        theme = NotchTheme(rawValue: raw) ?? .solid
    }
}
