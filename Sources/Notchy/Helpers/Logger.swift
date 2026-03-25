import Foundation

enum Log {
    private static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".notchy.log")

    static func info(_ msg: String) {
        let line = "\(timestamp()) \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let fh = try? FileHandle(forWritingTo: logURL) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
        // Also print for terminal launches
        print(msg)
    }

    static func clear() {
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
