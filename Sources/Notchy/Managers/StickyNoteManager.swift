import Foundation

@Observable
final class StickyNoteManager {
    var text: String {
        didSet { save() }
    }

    private let key = "com.notchy.stickyNote"

    init() {
        text = UserDefaults.standard.string(forKey: key) ?? ""
    }

    private func save() {
        UserDefaults.standard.set(text, forKey: key)
    }
}
