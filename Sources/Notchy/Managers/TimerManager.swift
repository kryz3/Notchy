import Foundation

@Observable
final class TimerManager {
    var remainingSeconds: Int = 0
    var isRunning = false
    var isSettingTime = false
    var inputMinutes: String = "5"

    var displayTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    private var timer: Timer?
    private var totalSeconds: Int = 0

    func start(minutes: Int) {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        isRunning = true
        isSettingTime = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.stop()
                self.notify()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        totalSeconds = 0
    }

    private func notify() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \"Timer terminé !\" with title \"Notchy\" sound name \"Glass\""]
        try? process.run()
    }
}
