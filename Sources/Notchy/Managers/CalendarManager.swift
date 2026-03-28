import EventKit
import AppKit

@Observable
final class CalendarManager {
    var events: [EKEvent] = []
    var selectedDate: Date = Date()
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    var availableCalendars: [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// Only writable calendars for event creation
    var writableCalendars: [EKCalendar] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var settings: SettingsManager?

    private var store = EKEventStore()

    init() {
        requestAccess()
    }

    func requestAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status

        switch status {
        case .fullAccess, .authorized:
            fetchEvents()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        self?.store = EKEventStore()
                        self?.authorizationStatus = .fullAccess
                        self?.fetchEvents()
                    }
                }
            }
        default:
            break
        }
    }

    func fetchEvents() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let hidden = settings?.hiddenCalendarIds ?? []
        events = store.events(matching: predicate)
            .filter { !hidden.contains($0.calendar.calendarIdentifier) }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        fetchEvents()
    }

    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        fetchEvents()
    }

    func goToToday() {
        selectedDate = Date()
        fetchEvents()
    }

    func createEvent(title: String, startDate: Date, durationMinutes: Int = 60, calendarId: String? = nil) {
        let event = EKEvent(eventStore: store)
        event.title = title
        // Combine selected date with chosen time
        let cal = Calendar.current
        let dateComponents = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = cal.dateComponents([.hour, .minute], from: startDate)
        var merged = dateComponents
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        event.startDate = cal.date(from: merged) ?? startDate
        event.endDate = event.startDate.addingTimeInterval(Double(durationMinutes) * 60)

        if let id = calendarId, let c = store.calendar(withIdentifier: id), c.allowsContentModifications {
            event.calendar = c
        } else if let def = store.defaultCalendarForNewEvents, def.allowsContentModifications {
            event.calendar = def
        } else if let writable = writableCalendars.first {
            event.calendar = writable
        } else {
            Log.info("[Calendar] No writable calendar found!")
            return
        }
        do {
            try store.save(event, span: .thisEvent)
            Log.info("[Calendar] Event created: \(title)")
        } catch {
            Log.info("[Calendar] Save failed: \(error)")
        }
        fetchEvents()
    }

    func openInCalendar(_ event: EKEvent) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    func deleteEvent(_ event: EKEvent) {
        do {
            try store.remove(event, span: .thisEvent)
            Log.info("[Calendar] Deleted: \(event.title ?? "")")
        } catch {
            Log.info("[Calendar] Delete failed: \(error)")
        }
        fetchEvents()
    }

    func refresh() {
        store = EKEventStore()
        // Reset to today if the selected date is in the past (e.g. app ran overnight)
        if selectedDate < Calendar.current.startOfDay(for: Date()) {
            selectedDate = Date()
        }
        fetchEvents()
    }
}
