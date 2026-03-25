import SwiftUI

struct RemindersView: View {
    @Bindable var reminders: RemindersManager
    @State private var showAddField = false
    @State private var newReminderTitle = ""
    @State private var completingIds: Set<String> = []
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.reminders).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("\(reminders.reminders.count)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                TapIcon("plus.circle.fill", size: 16, color: .white.opacity(0.5)) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showAddField.toggle()
                    }
                    if showAddField { addFieldFocused = true }
                }
            }

            if showAddField {
                HStack(spacing: 8) {
                    TextField(L.newReminder, text: $newReminderTitle)
                        .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))
                        .focused($addFieldFocused)
                        .onSubmit { addReminder() }
                    TapIcon("arrow.up.circle.fill", size: 20, color: .white.opacity(0.6)) { addReminder() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if reminders.accessDenied || reminders.noListsAvailable {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: reminders.noListsAvailable ? "list.bullet.rectangle" : "lock.shield")
                            .font(.system(size: 24)).foregroundStyle(.white.opacity(0.3))
                        Text(reminders.noListsAvailable ? L.openReminders : L.accessRequired)
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center)
                        Button(reminders.noListsAvailable ? L.openReminderApp : L.openSettings) {
                            if reminders.noListsAvailable {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
                            } else { reminders.openSettings() }
                        }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.15)))
                    }
                    Spacer()
                }
                Spacer()
            } else if reminders.reminders.isEmpty && !showAddField {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(.system(size: 24)).foregroundStyle(.white.opacity(0.2))
                        Text(L.allDone).font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(reminders.reminders) { reminder in
                            ReminderRow(
                                reminder: reminder,
                                isCompleting: completingIds.contains(reminder.id),
                                onComplete: { completeReminder(reminder) },
                                onDelete: { deleteReminder(reminder) }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: reminders.reminders.map(\.id))
                }
            }
        }
    }

    private func addReminder() {
        let title = newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        reminders.createReminder(title: title)
        newReminderTitle = ""
        addFieldFocused = true
    }

    private func completeReminder(_ reminder: SimpleReminder) {
        completingIds.insert(reminder.id)
        reminders.completeReminder(reminder)
        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                completingIds.remove(reminder.id)
                reminders.reminders.removeAll { $0.id == reminder.id }
            }
        }
    }

    private func deleteReminder(_ reminder: SimpleReminder) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reminders.reminders.removeAll { $0.id == reminder.id }
        }
        reminders.deleteReminder(reminder)
    }
}

// MARK: - Reminder Row with hover delete

struct ReminderRow: View {
    let reminder: SimpleReminder
    let isCompleting: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var deleteHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(isCompleting ? .blue : .white.opacity(0.4))
                .scaleEffect(isCompleting ? 1.15 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isCompleting)
                .contentShape(Circle().inset(by: -4))
                .onTapGesture { if !isCompleting { onComplete() } }

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCompleting ? .white.opacity(0.4) : .white)
                    .strikethrough(isCompleting)
                    .lineLimit(1)

                if !reminder.listName.isEmpty || !reminder.dueDate.isEmpty {
                    HStack(spacing: 4) {
                        Text(reminder.listName).font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        if !reminder.dueDate.isEmpty {
                            Text("· \(reminder.dueDate)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
            }

            Spacer()

            // Delete button on hover
            if isHovered && !isCompleting {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(deleteHovered ? .red : .white.opacity(0.3))
                    .scaleEffect(deleteHovered ? 1.1 : 1.0)
                    .onHover { deleteHovered = $0 }
                    .onTapGesture { onDelete() }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = h }
        }
    }
}
