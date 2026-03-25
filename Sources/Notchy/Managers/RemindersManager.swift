import AppKit

struct SimpleReminder: Identifiable, Equatable {
    let id: String
    let title: String
    let listName: String
    let dueDate: String

    static func == (lhs: SimpleReminder, rhs: SimpleReminder) -> Bool { lhs.id == rhs.id }
}

@Observable
final class RemindersManager {
    var reminders: [SimpleReminder] = []
    var accessDenied = false
    var noListsAvailable = false

    init() {
        ensureListExists()
    }

    func fetchReminders() {
        let source = """
        tell application "Reminders"
            set lf to ASCII character 10
            set output to ""
            repeat with r in (every reminder whose completed is false)
                set rName to name of r
                set rId to id of r
                set rList to name of container of r
                set rDue to ""
                try
                    set d to due date of r
                    if d is not missing value then
                        set rDue to short date string of d
                    end if
                end try
                set output to output & rId & "||" & rName & "||" & rList & "||" & rDue & lf
            end repeat
            return output
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let err = error {
                    Log.info("[Reminders] Fetch error: \(err)")
                    if let n = err["NSAppleScriptErrorNumber"] as? Int, n == -1743 { self?.accessDenied = true }
                    return
                }

                guard let str = result?.stringValue, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self?.reminders = []
                    return
                }

                let lines = str.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
                self?.reminders = lines.compactMap { line in
                    let parts = line.components(separatedBy: "||")
                    guard parts.count >= 3 else { return nil }
                    let due = parts.count > 3 ? parts[3].trimmingCharacters(in: .whitespaces) : ""
                    return SimpleReminder(
                        id: parts[0].trimmingCharacters(in: .whitespaces),
                        title: parts[1].trimmingCharacters(in: .whitespaces),
                        listName: parts[2].trimmingCharacters(in: .whitespaces),
                        dueDate: due == "missing value" ? "" : due
                    )
                }
                Log.info("[Reminders] Loaded \(self?.reminders.count ?? 0)")
            }
        }
    }

    func createReminder(title: String) {
        let escaped = title.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Reminders"
            tell default list
                make new reminder with properties {name:"\(escaped)"}
            end tell
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let err = error {
                // Fallback to first list
                let fallback = """
                tell application "Reminders"
                    tell first list
                        make new reminder with properties {name:"\(escaped)"}
                    end tell
                end tell
                """
                NSAppleScript(source: fallback)?.executeAndReturnError(nil)
            }
            DispatchQueue.main.async { self?.fetchReminders() }
        }
    }

    func completeReminder(_ reminder: SimpleReminder) {
        let source = """
        tell application "Reminders"
            set r to (first reminder whose id is "\(reminder.id)")
            set completed of r to true
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            NSAppleScript(source: source)?.executeAndReturnError(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self?.fetchReminders() }
        }
    }

    func deleteReminder(_ reminder: SimpleReminder) {
        let source = """
        tell application "Reminders"
            delete (first reminder whose id is "\(reminder.id)")
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            NSAppleScript(source: source)?.executeAndReturnError(nil)
            DispatchQueue.main.async { self?.fetchReminders() }
        }
    }

    private func ensureListExists() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let countResult = NSAppleScript(source: "tell application \"Reminders\" to count of lists")?
                .executeAndReturnError(&error)
            let count = countResult?.int32Value ?? 0
            if count == 0 {
                var createError: NSDictionary?
                NSAppleScript(source: "tell application \"Reminders\" to make new list with properties {name:\"Notchy\"}")?
                    .executeAndReturnError(&createError)
                if createError != nil {
                    DispatchQueue.main.async { self?.noListsAvailable = true }
                    return
                }
            }
            DispatchQueue.main.async { self?.fetchReminders() }
        }
    }

    func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
    }

    func refresh() { fetchReminders() }
}
