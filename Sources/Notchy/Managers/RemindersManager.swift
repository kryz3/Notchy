import AppKit

struct SimpleReminder: Identifiable {
    let id: String
    let title: String
    let listName: String
    let dueDate: String
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
        // Use ASCII character 10 (linefeed) as separator — \n doesn't work in AppleScript strings
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
                    set rDue to (due date of r) as text
                end try
                set output to output & rId & "||" & rName & "||" & rList & "||" & rDue & lf
            end repeat
            return output
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            let result = script?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let err = error {
                    Log.info("[Reminders] Fetch error: \(err)")
                    if let errNum = err["NSAppleScriptErrorNumber"] as? Int, errNum == -1743 {
                        self?.accessDenied = true
                    }
                    return
                }

                guard let str = result?.stringValue, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self?.reminders = []
                    Log.info("[Reminders] Empty result")
                    return
                }

                let lines = str.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
                self?.reminders = lines.compactMap { line in
                    let parts = line.components(separatedBy: "||")
                    guard parts.count >= 3 else { return nil }
                    return SimpleReminder(
                        id: parts[0].trimmingCharacters(in: .whitespaces),
                        title: parts[1].trimmingCharacters(in: .whitespaces),
                        listName: parts[2].trimmingCharacters(in: .whitespaces),
                        dueDate: parts.count > 3 ? parts[3].trimmingCharacters(in: .whitespaces) : ""
                    )
                }
                Log.info("[Reminders] Loaded \(self?.reminders.count ?? 0)")
            }
        }
    }

    func createReminder(title: String) {
        Log.info("[Reminders] Creating: '\(title)'")
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

            DispatchQueue.main.async {
                if let err = error {
                    Log.info("[Reminders] Create error: \(err)")
                    // Fallback: try without specifying list
                    self?.createReminderFallback(title: title)
                } else {
                    Log.info("[Reminders] Created OK")
                    self?.fetchReminders()
                }
            }
        }
    }

    private func createReminderFallback(title: String) {
        let escaped = title.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Reminders"
            set targetList to first list
            tell targetList
                make new reminder with properties {name:"\(escaped)"}
            end tell
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if let err = error {
                    Log.info("[Reminders] Fallback create error: \(err)")
                } else {
                    Log.info("[Reminders] Fallback created OK")
                }
                self?.fetchReminders()
            }
        }
    }

    func toggleCompletion(_ reminder: SimpleReminder) {
        let source = """
        tell application "Reminders"
            set r to (first reminder whose id is "\(reminder.id)")
            set completed of r to true
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

            if let err = error {
                Log.info("[Reminders] Count error: \(err)")
                DispatchQueue.main.async { self?.noListsAvailable = true }
                return
            }

            let count = countResult?.int32Value ?? 0
            if count == 0 {
                var createError: NSDictionary?
                NSAppleScript(source: """
                    tell application "Reminders"
                        make new list with properties {name:"Notchy"}
                    end tell
                """)?.executeAndReturnError(&createError)

                if createError != nil {
                    Log.info("[Reminders] Cannot create list")
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
