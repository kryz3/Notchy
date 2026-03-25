import SwiftUI
import EventKit

struct CalendarView: View {
    @Bindable var calendar: CalendarManager
    @State private var showAddSheet = false
    @State private var newEventTitle = ""
    @State private var newEventTime = Date()
    @State private var selectedCalendarId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date navigation
            HStack(spacing: 6) {
                TapIcon("chevron.left", size: 11, color: .white.opacity(0.5)) {
                    calendar.goToPreviousDay()
                }

                if calendar.isToday {
                    Text("Aujourd'hui")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(dateString)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .onTapGesture { calendar.goToToday() }
                }

                TapIcon("chevron.right", size: 11, color: .white.opacity(0.5)) {
                    calendar.goToNextDay()
                }

                Spacer()

                if !calendar.isToday {
                    Button { calendar.goToToday() } label: {
                        Text("Auj.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }

                Text("\(calendar.events.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))

                TapIcon("plus.circle.fill", size: 16, color: .white.opacity(0.5)) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        if selectedCalendarId.isEmpty, let first = calendar.writableCalendars.first {
                            selectedCalendarId = first.calendarIdentifier
                        }
                        showAddSheet.toggle()
                    }
                }
            }

            // Quick add form
            if showAddSheet {
                quickAddForm
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Events list — always in a ScrollView to prevent layout jumps
            ScrollView(.vertical, showsIndicators: false) {
                if calendar.events.isEmpty {
                    VStack(spacing: 6) {
                        Spacer(minLength: 30)
                        Image(systemName: "calendar")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("Aucun événement")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 6) {
                        ForEach(calendar.events, id: \.eventIdentifier) { event in
                            eventRow(event)
                                .onTapGesture { calendar.openInCalendar(event) }
                        }
                    }
                }
            }
        }
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = Calendar.current.isDate(calendar.selectedDate, equalTo: Date(), toGranularity: .year)
            ? "EEEE d MMMM" : "EEEE d MMMM yyyy"
        return fmt.string(from: calendar.selectedDate).capitalized
    }

    private var quickAddForm: some View {
        VStack(spacing: 8) {
            TextField("Titre", text: $newEventTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))
                .onSubmit { createEvent() }

            HStack(spacing: 10) {
                DatePicker("", selection: $newEventTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(width: 90)
                Spacer()
                Button("Ajouter") { createEvent() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white))
            }

            // Inline calendar picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(calendar.writableCalendars, id: \.calendarIdentifier) { cal in
                        Button {
                            selectedCalendarId = cal.calendarIdentifier
                        } label: {
                            HStack(spacing: 4) {
                                Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 8, height: 8)
                                Text(cal.title).font(.system(size: 10)).lineLimit(1)
                            }
                            .foregroundStyle(selectedCalendarId == cal.calendarIdentifier ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedCalendarId == cal.calendarIdentifier ? .white.opacity(0.15) : .white.opacity(0.05))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
    }

    private func createEvent() {
        guard !newEventTitle.isEmpty else { return }
        calendar.createEvent(
            title: newEventTitle,
            startDate: newEventTime,
            calendarId: selectedCalendarId.isEmpty ? nil : selectedCalendarId
        )
        newEventTitle = ""
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showAddSheet = false
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Sans titre")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if event.isAllDay {
                    Text("Toute la journée").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                } else {
                    Text(timeRange(event)).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            if isOngoing(event) {
                Text("En cours")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(.green.opacity(0.15)))
            }

            Image(systemName: "arrow.up.right")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
        .contentShape(Rectangle())
    }

    private func timeRange(_ event: EKEvent) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private func isOngoing(_ event: EKEvent) -> Bool {
        guard !event.isAllDay else { return false }
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }
}
