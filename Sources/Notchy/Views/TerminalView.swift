import SwiftUI
import AppKit

// NSTextField wrapper to capture Tab key for autocompletion
struct TerminalTextField: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var onSubmit: () -> Void
    var onTab: () -> Void
    var onArrowUp: () -> Void = {}
    var onArrowDown: () -> Void = {}

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.font = font
        tf.textColor = .white
        tf.focusRingType = .none
        tf.placeholderString = ""
        tf.delegate = context.coordinator
        tf.cell?.lineBreakMode = .byTruncatingTail
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: TerminalTextField
        init(_ parent: TerminalTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if selector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            if selector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }
            if selector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            return false
        }
    }
}

struct TerminalView: View {
    @State private var commandHistory: [(command: String, output: String)] = []
    @State private var currentCommand = ""
    @State private var isRunning = false
    @State private var workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var completionHints: [String] = []
    @State private var historyIndex: Int = -1

    private static let historyKey = "com.notchy.terminalHistory"

    private var savedCommands: [String] {
        UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
    }

    private func saveToHistory(_ cmd: String) {
        var history = savedCommands
        // Don't duplicate last entry
        if history.last != cmd {
            history.append(cmd)
            // Keep last 100
            if history.count > 100 { history = Array(history.suffix(100)) }
            UserDefaults.standard.set(history, forKey: Self.historyKey)
        }
        historyIndex = -1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("Terminal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()

                Text(shortenedPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)

                Button {
                    commandHistory = []
                    completionHints = []
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            // Output
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(commandHistory.enumerated()), id: \.offset) { idx, entry in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("$")
                                        .foregroundStyle(.green.opacity(0.7))
                                    Text(entry.command)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .font(.system(size: 11, design: .monospaced))

                                if !entry.output.isEmpty {
                                    Text(entry.output)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .textSelection(.enabled)
                                }
                            }
                            .id(idx)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: commandHistory.count) { _, _ in
                    if let last = commandHistory.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            // Completion hints
            if !completionHints.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(completionHints, id: \.self) { hint in
                            Button {
                                applyCompletion(hint)
                            } label: {
                                Text(hint)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 22)
            }

            // Input
            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.7))

                TerminalTextField(
                    text: $currentCommand,
                    font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    onSubmit: { runCommand() },
                    onTab: { tabComplete() },
                    onArrowUp: { navigateHistory(direction: -1) },
                    onArrowDown: { navigateHistory(direction: 1) }
                )

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)))
        }
    }

    private var shortenedPath: String {
        workingDirectory.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    // MARK: - History navigation (arrow up/down)

    private func navigateHistory(direction: Int) {
        let history = savedCommands
        guard !history.isEmpty else { return }

        if direction < 0 {
            // Up: go back in history
            if historyIndex < 0 {
                historyIndex = history.count - 1
            } else if historyIndex > 0 {
                historyIndex -= 1
            }
            currentCommand = history[historyIndex]
        } else {
            // Down: go forward
            if historyIndex >= 0 && historyIndex < history.count - 1 {
                historyIndex += 1
                currentCommand = history[historyIndex]
            } else {
                historyIndex = -1
                currentCommand = ""
            }
        }
    }

    // MARK: - Tab completion

    private func tabComplete() {
        let parts = currentCommand.components(separatedBy: " ")
        let partial = parts.last ?? ""
        guard !partial.isEmpty else { return }

        let dir: String
        let prefix: String

        if partial.contains("/") {
            let components = (partial as NSString)
            var dirPart = components.deletingLastPathComponent
            prefix = components.lastPathComponent

            if dirPart.hasPrefix("~") {
                dirPart = dirPart.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
            } else if !dirPart.hasPrefix("/") {
                dirPart = (workingDirectory as NSString).appendingPathComponent(dirPart)
            }
            dir = dirPart
        } else {
            dir = workingDirectory
            prefix = partial
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dir)
            let matches = contents.filter { $0.hasPrefix(prefix) }.sorted()

            if matches.count == 1 {
                applyCompletion(matches[0])
                completionHints = []
            } else if matches.count > 1 {
                completionHints = Array(matches.prefix(10))
            }
        } catch {}
    }

    private func applyCompletion(_ match: String) {
        var parts = currentCommand.components(separatedBy: " ")
        let partial = parts.last ?? ""

        if partial.contains("/") {
            let dirPart = (partial as NSString).deletingLastPathComponent
            parts[parts.count - 1] = dirPart.isEmpty ? match : dirPart + "/" + match
        } else {
            parts[parts.count - 1] = match
        }

        // Add / if it's a directory
        let fullPath: String
        let resolved = parts.last ?? ""
        if resolved.hasPrefix("/") {
            fullPath = resolved
        } else if resolved.hasPrefix("~") {
            fullPath = resolved.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        } else {
            fullPath = (workingDirectory as NSString).appendingPathComponent(resolved)
        }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
            if !parts[parts.count - 1].hasSuffix("/") {
                parts[parts.count - 1] += "/"
            }
        }

        currentCommand = parts.joined(separator: " ")
        completionHints = []
    }

    // MARK: - Run command

    private func runCommand() {
        let cmd = currentCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        currentCommand = ""
        completionHints = []
        isRunning = true
        saveToHistory(cmd)

        // Handle cd
        if cmd == "cd" || cmd.hasPrefix("cd ") {
            let path = cmd == "cd" ? "~" : String(cmd.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let resolved: String
            if path.hasPrefix("/") {
                resolved = path
            } else if path == "~" || path.hasPrefix("~/") {
                resolved = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
            } else {
                resolved = (workingDirectory as NSString).appendingPathComponent(path)
            }

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue {
                workingDirectory = resolved
                commandHistory.append((command: cmd, output: ""))
            } else {
                commandHistory.append((command: cmd, output: "cd: no such directory: \(path)"))
            }
            isRunning = false
            return
        }

        // Handle clear
        if cmd == "clear" {
            commandHistory = []
            isRunning = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()
            let errPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", cmd]
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            process.standardOutput = pipe
            process.standardError = errPipe

            var output = ""
            do {
                try process.run()
                process.waitUntilExit()

                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                output = (stdout + stderr).trimmingCharacters(in: .whitespacesAndNewlines)

                let lines = output.components(separatedBy: "\n")
                if lines.count > 50 {
                    output = lines.prefix(50).joined(separator: "\n") + "\n... (\(lines.count - 50) more lines)"
                }
            } catch {
                output = "Error: \(error.localizedDescription)"
            }

            DispatchQueue.main.async {
                commandHistory.append((command: cmd, output: output))
                isRunning = false
            }
        }
    }
}
