import AppKit

enum PomodoroState: String {
    case idle, work, shortBreak, longBreak
}

@Observable
final class PomodoroManager {
    var state: PomodoroState = .idle
    var remainingSeconds: Int = 25 * 60
    var sessionsCompleted: Int = 0

    var workMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var sessionsBeforeLong = 4

    var isRunning: Bool { state != .idle }

    var displayTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var progress: Double {
        let total = totalSeconds
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(total))
    }

    var stateLabel: String {
        switch state {
        case .idle: return ""
        case .work: return "Focus"
        case .shortBreak: return "Pause"
        case .longBreak: return "Long Break"
        }
    }

    private var timer: Timer?

    private var totalSeconds: Int {
        switch state {
        case .idle: return workMinutes * 60
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    func startWork() {
        state = .work
        remainingSeconds = workMinutes * 60
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remainingSeconds = workMinutes * 60
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        advanceState()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.timer?.invalidate()
                self.timer = nil
                self.notify()
                self.advanceState()
            }
        }
    }

    private func advanceState() {
        switch state {
        case .work:
            sessionsCompleted += 1
            if sessionsCompleted % sessionsBeforeLong == 0 {
                state = .longBreak
                remainingSeconds = longBreakMinutes * 60
            } else {
                state = .shortBreak
                remainingSeconds = shortBreakMinutes * 60
            }
            startTimer()
        case .shortBreak, .longBreak:
            state = .work
            remainingSeconds = workMinutes * 60
            startTimer()
        case .idle:
            break
        }
    }

    private func notify() {
        let notification = NSUserNotification()
        notification.title = "Notchy"
        notification.informativeText = state == .work
            ? "Session terminée ! Pause."
            : "Pause finie ! C'est reparti."
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
