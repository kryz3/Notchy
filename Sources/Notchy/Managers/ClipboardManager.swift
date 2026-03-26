import AppKit

struct ClipItem: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date

    var preview: String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count > 80 { return String(clean.prefix(80)) + "..." }
        return clean
    }

    var timeAgo: String {
        let s = Int(Date().timeIntervalSince(timestamp))
        if s < 60 { return "now" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}

@Observable
final class ClipboardManager {
    var items: [ClipItem] = []
    var maxItems = 20

    private var pollTimer: Timer?
    private var lastChangeCount: Int = 0
    private let storageKey = "com.notchy.clipboard"

    init() {
        loadFromDisk()
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string), !text.isEmpty else { return }
        if items.first?.text == text { return }

        items.insert(ClipItem(text: text, timestamp: Date()), at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        saveToDisk()
    }

    private func saveToDisk() {
        let data = items.map { ["text": $0.text, "time": $0.timestamp.timeIntervalSince1970] as [String: Any] }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadFromDisk() {
        guard let arr = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] else { return }
        items = arr.compactMap { dict in
            guard let text = dict["text"] as? String,
                  let time = dict["time"] as? Double else { return nil }
            return ClipItem(text: text, timestamp: Date(timeIntervalSince1970: time))
        }
    }

    func copyToClipboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        lastChangeCount = pb.changeCount // prevent re-adding
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    func clear() {
        items.removeAll()
        saveToDisk()
    }
}
