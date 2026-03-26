import AppKit

struct AppShortcut: Identifiable, Codable {
    var id: String { path }
    let path: String
    let name: String
}

@Observable
final class AppShortcutsManager {
    var shortcuts: [AppShortcut] = []

    private let key = "com.notchy.appShortcuts"

    init() {
        load()
        if shortcuts.isEmpty {
            // Default shortcuts
            shortcuts = [
                AppShortcut(path: "/System/Applications/Safari.app", name: "Safari"),
                AppShortcut(path: "/Applications/Spotify.app", name: "Spotify"),
                AppShortcut(path: "/System/Applications/Notes.app", name: "Notes"),
                AppShortcut(path: "/System/Applications/Utilities/Terminal.app", name: "Terminal"),
            ].filter { FileManager.default.fileExists(atPath: $0.path) }
            save()
        }
    }

    func launch(_ shortcut: AppShortcut) {
        NSWorkspace.shared.open(URL(fileURLWithPath: shortcut.path))
    }

    func add(path: String) {
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        guard !shortcuts.contains(where: { $0.path == path }) else { return }
        shortcuts.append(AppShortcut(path: path, name: name))
        save()
    }

    func remove(_ shortcut: AppShortcut) {
        shortcuts.removeAll { $0.path == shortcut.path }
        save()
    }

    func icon(for shortcut: AppShortcut) -> NSImage? {
        NSWorkspace.shared.icon(forFile: shortcut.path)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppShortcut].self, from: data) else { return }
        shortcuts = decoded
    }
}
