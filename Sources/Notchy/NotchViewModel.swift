import SwiftUI

enum RightTab: Int, CaseIterable, Identifiable {
    case calendar, reminders, notes, clipboard, terminal

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .calendar: L.calendar
        case .reminders: L.reminders
        case .notes: L.notes
        case .clipboard: "Clipboard"
        case .terminal: L.terminal
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .notes: "note.text"
        case .clipboard: "doc.on.clipboard"
        case .terminal: "terminal"
        }
    }
}

@Observable
final class NotchViewModel {
    // State
    var isExpanded = false
    var selectedTab: RightTab = .calendar

    // Notification banner (AirPods, etc.)
    var notificationText: String?
    var notificationIcon: String?
    var showNotification = false

    // Managers
    let music = MusicManager()
    let calendar = CalendarManager()
    let reminders = RemindersManager()
    let stickyNote = StickyNoteManager()
    let systemMonitor = SystemMonitorManager()
    let weather = WeatherManager()
    var timer = TimerManager()
    let clipboard = ClipboardManager()
    var settings = SettingsManager()
    let updater = UpdateManager()

    // Notch geometry
    var notchInfo: NotchInfo = ScreenHelper.detectNotch()

    // Sizing
    let expandedWidth: CGFloat = 700
    let expandedHeight: CGFloat = 320
    let collapsedCornerRadius: CGFloat = 12
    let expandedCornerRadius: CGFloat = 20
    let notificationWidth: CGFloat = 280
    let notificationHeight: CGFloat = 50

    var notchWidth: CGFloat { notchInfo.notchWidth }
    var notchHeight: CGFloat { notchInfo.notchHeight }

    // Compact mode
    var isCompactVisible: Bool {
        settings.compactMode == .musicOnly && music.hasTrack && !isExpanded
    }
    let compactWidth: CGFloat = 380
    let compactHeight: CGFloat = 40

    // Callbacks for AppDelegate
    var onExpandChanged: ((Bool) -> Void)?
    var isHovering = false

    // Timers
    private var collapseWorkItem: DispatchWorkItem?

    init() {
        music.settings = settings
        calendar.settings = settings
    }

    func expand() {
        cancelPendingCollapse()
        guard !isExpanded else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            isExpanded = true
        }
        onExpandChanged?(true)
        calendar.refresh()
        reminders.refresh()
    }

    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            isExpanded = false
        }
        onExpandChanged?(false)
    }

    func scheduleCollapse(delay: TimeInterval = 0.3) {
        cancelPendingCollapse()
        let item = DispatchWorkItem { [weak self] in
            self?.collapse()
        }
        collapseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancelPendingCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    // MARK: - Device notifications

    private func showDeviceNotification(name: String) {
        notificationText = name
        notificationIcon = name.lowercased().contains("airpods") ? "airpodspro" : "headphones"

        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            showNotification = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                self?.showNotification = false
            }
        }
    }
}
