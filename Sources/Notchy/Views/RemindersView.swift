import SwiftUI

struct RemindersView: View {
    @Bindable var reminders: RemindersManager
    @State private var showAddField = false
    @State private var newReminderTitle = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rappels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()

                Text("\(reminders.reminders.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showAddField.toggle()
                    }
                    if showAddField { addFieldFocused = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            if showAddField {
                HStack(spacing: 8) {
                    TextField("Nouveau rappel...", text: $newReminderTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))
                        .focused($addFieldFocused)
                        .onSubmit { addReminder() }

                    Button { addReminder() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if reminders.accessDenied || reminders.noListsAvailable {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: reminders.noListsAvailable ? "list.bullet.rectangle" : "lock.shield")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(reminders.noListsAvailable
                            ? "Ouvre Rappels et crée une liste"
                            : "Accès aux rappels requis")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        Button(reminders.noListsAvailable ? "Ouvrir Rappels" : "Ouvrir les Réglages") {
                            if reminders.noListsAvailable {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
                            } else {
                                reminders.openSettings()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
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
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("Tout est fait !")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(reminders.reminders) { reminder in
                            reminderRow(reminder)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
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

    private func reminderRow(_ reminder: SimpleReminder) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    reminders.toggleCompletion(reminder)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(reminder.listName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    if !reminder.dueDate.isEmpty {
                        Text("· \(reminder.dueDate)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
    }
}
