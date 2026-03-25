import AppKit

@Observable
final class UpdateManager {
    static let currentVersion = "1.0.0"
    static let repoOwner = "kryz3"
    static let repoName = "Notchy"

    var latestVersion: String?
    var downloadURL: String?
    var isChecking = false
    var isUpdating = false
    var updateAvailable = false
    var checkedOnce = false
    var updateProgress: String = ""
    var error: String?

    // MARK: - Check for updates

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        error = nil
        updateAvailable = false

        let urlStr = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlStr) else { isChecking = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false

                if let err {
                    self.error = err.localizedDescription
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    // No release yet or repo not found — we're up to date
                    self.updateAvailable = false
                    self.latestVersion = Self.currentVersion
                    self.checkedOnce = true
                    return
                }

                let remote = tagName.replacingOccurrences(of: "v", with: "")
                self.latestVersion = remote

                // Find DMG asset
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                           let url = asset["browser_download_url"] as? String {
                            self.downloadURL = url
                            break
                        }
                    }
                }

                self.updateAvailable = self.isNewer(remote: remote, local: Self.currentVersion)

                self.checkedOnce = true
                if self.updateAvailable {
                    Log.info("[Update] New version available: \(remote)")
                } else {
                    Log.info("[Update] Up to date (\(Self.currentVersion))")
                }
            }
        }.resume()
    }

    // MARK: - Download and install

    func performUpdate() {
        guard let downloadURL, let url = URL(string: downloadURL) else { return }
        isUpdating = true
        updateProgress = L.lang == .fr ? "Téléchargement..." : "Downloading..."

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("notchy-update")
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dmgPath = tempDir.appendingPathComponent("Notchy.dmg")

        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, err in
            DispatchQueue.main.async {
                guard let self else { return }

                if let err {
                    self.error = err.localizedDescription
                    self.isUpdating = false
                    return
                }

                guard let tempURL else {
                    self.error = "Download failed"
                    self.isUpdating = false
                    return
                }

                do {
                    try FileManager.default.moveItem(at: tempURL, to: dmgPath)
                    self.updateProgress = L.lang == .fr ? "Installation..." : "Installing..."
                    self.installFromDMG(dmgPath: dmgPath, tempDir: tempDir)
                } catch {
                    self.error = error.localizedDescription
                    self.isUpdating = false
                }
            }
        }.resume()
    }

    private func installFromDMG(dmgPath: URL, tempDir: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let mountPoint = tempDir.appendingPathComponent("mount").path

            // Mount DMG
            let mount = Process()
            mount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            mount.arguments = ["attach", dmgPath.path, "-mountpoint", mountPoint, "-nobrowse", "-quiet"]
            try? mount.run()
            mount.waitUntilExit()

            guard mount.terminationStatus == 0 else {
                DispatchQueue.main.async {
                    self?.error = "Failed to mount DMG"
                    self?.isUpdating = false
                }
                return
            }

            // Find .app in mounted DMG
            let appSource = "\(mountPoint)/Notchy.app"
            let appDest = "/Applications/Notchy.app"

            guard FileManager.default.fileExists(atPath: appSource) else {
                // Unmount
                let unmount = Process()
                unmount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                unmount.arguments = ["detach", mountPoint, "-quiet"]
                try? unmount.run()
                unmount.waitUntilExit()

                DispatchQueue.main.async {
                    self?.error = "Notchy.app not found in DMG"
                    self?.isUpdating = false
                }
                return
            }

            // Replace app
            try? FileManager.default.removeItem(atPath: appDest)
            do {
                try FileManager.default.copyItem(atPath: appSource, toPath: appDest)
            } catch {
                DispatchQueue.main.async {
                    self?.error = "Install failed: \(error.localizedDescription)"
                    self?.isUpdating = false
                }
                // Unmount
                let unmount = Process()
                unmount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                unmount.arguments = ["detach", mountPoint, "-quiet"]
                try? unmount.run()
                unmount.waitUntilExit()
                return
            }

            // Unmount
            let unmount = Process()
            unmount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmount.arguments = ["detach", mountPoint, "-quiet"]
            try? unmount.run()
            unmount.waitUntilExit()

            // Clean
            try? FileManager.default.removeItem(at: tempDir)

            // Relaunch
            DispatchQueue.main.async {
                self?.updateProgress = L.lang == .fr ? "Relancement..." : "Restarting..."
                Log.info("[Update] Updated to \(self?.latestVersion ?? "?"), relaunching")

                // Launch the new app and quit this one
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = [appDest]
                    try? task.run()

                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    // MARK: - Version comparison

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
