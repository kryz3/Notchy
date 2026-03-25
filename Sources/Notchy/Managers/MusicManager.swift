import AppKit

// MARK: - MediaRemote bridge (private framework)

private typealias MRGetNowPlayingInfo = @convention(c) (DispatchQueue, @escaping (CFDictionary) -> Void) -> Void
private typealias MRSendCommand = @convention(c) (UInt32, CFDictionary?) -> Bool
private typealias MRRegisterNotifications = @convention(c) (DispatchQueue) -> Void
private typealias MRGetIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

private let kTogglePlayPause: UInt32 = 2
private let kNextTrack: UInt32 = 4
private let kPreviousTrack: UInt32 = 5

private struct MRBridge {
    let getNowPlayingInfo: MRGetNowPlayingInfo
    let sendCommand: MRSendCommand
    let registerNotifications: MRRegisterNotifications
    let getIsPlaying: MRGetIsPlaying

    static func load() -> MRBridge? {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let url = NSURL(fileURLWithPath: path) as CFURL?,
              let bundle = CFBundleCreate(kCFAllocatorDefault, url) else { return nil }

        func sym<T>(_ name: String) -> T? {
            guard let ptr = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }

        guard let get: MRGetNowPlayingInfo = sym("MRMediaRemoteGetNowPlayingInfo"),
              let send: MRSendCommand = sym("MRMediaRemoteSendCommand"),
              let reg: MRRegisterNotifications = sym("MRMediaRemoteRegisterForNowPlayingNotifications"),
              let playing: MRGetIsPlaying = sym("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        else { return nil }

        return MRBridge(getNowPlayingInfo: get, sendCommand: send, registerNotifications: reg, getIsPlaying: playing)
    }
}

// MARK: - MusicManager

@Observable
final class MusicManager {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artwork: NSImage?
    var isPlaying: Bool = false
    var duration: Double = 0
    var elapsed: Double = 0
    var playbackRate: Double = 1.0
    var isFavorited: Bool = false
    var isShuffled: Bool = false
    var albumTracks: [String] = []
    var volume: Double = 0.5
    var isMuted: Bool = false
    private var volumeBeforeMute: Double = 0.5
    private var volumeCooldown: Date = .distantPast

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }

    var hasTrack: Bool { !title.isEmpty }

    private var bridge: MRBridge?
    private var mediaRemoteWorks = true
    private var favoriteCooldown: Date = .distantPast
    private var playPauseCooldown: Date = .distantPast
    private var progressTimer: Timer?
    private var pollTimer: Timer?

    init() {
        bridge = MRBridge.load()
        if bridge != nil {
            Log.info("[Music] MediaRemote loaded")
            bridge?.registerNotifications(DispatchQueue.main)
            setupNotifications()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.poll() }
    }

    // MARK: Controls

    func togglePlayPause() {
        isPlaying.toggle()
        playPauseCooldown = Date().addingTimeInterval(3)
        if bridge != nil { _ = bridge?.sendCommand(kTogglePlayPause, nil) }
        else { runAS("tell application \"Music\" to playpause") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.poll() }
    }

    func nextTrack() {
        if bridge != nil { _ = bridge?.sendCommand(kNextTrack, nil) }
        else { runAS("tell application \"Music\" to next track") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.poll() }
    }

    func previousTrack() {
        if bridge != nil { _ = bridge?.sendCommand(kPreviousTrack, nil) }
        else { runAS("tell application \"Music\" to previous track") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.poll() }
    }

    func toggleShuffle() {
        runAS("tell application \"Music\" to set shuffle enabled to not shuffle enabled")
        isShuffled.toggle()
    }

    func toggleFavorite() {
        let newState = !isFavorited
        isFavorited = newState
        favoriteCooldown = Date().addingTimeInterval(4) // ignore poll for 4s
        let source = "tell application \"Music\" to set favorited of current track to \(newState)"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let err = error { Log.info("[Music] Favorite error: \(err)") }
        }
    }

    func seekTo(fraction: Double) {
        guard duration > 0 else { return }
        let position = fraction * duration
        elapsed = position
        runAS("tell application \"Music\" to set player position to \(position)")
    }

    func setVolume(_ v: Double) {
        volume = v
        isMuted = v < 0.01
        volumeCooldown = Date().addingTimeInterval(3)
        let intVol = Int(v * 100)
        runAS("tell application \"Music\" to set sound volume to \(intVol)")
    }

    func toggleMute() {
        if isMuted {
            setVolume(volumeBeforeMute > 0.01 ? volumeBeforeMute : 0.5)
        } else {
            volumeBeforeMute = volume
            setVolume(0)
        }
    }

    /// Extract dominant color from artwork for glow effect
    var artworkDominantColor: (r: Double, g: Double, b: Double)? {
        guard let img = artwork, let tiff = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        // Sample center region
        let w = bitmap.pixelsWide
        let h = bitmap.pixelsHigh
        guard w > 0, h > 0 else { return nil }

        var totalR = 0.0, totalG = 0.0, totalB = 0.0
        var count = 0.0
        let step = max(1, min(w, h) / 10)

        for x in stride(from: w / 4, to: 3 * w / 4, by: step) {
            for y in stride(from: h / 4, to: 3 * h / 4, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                totalR += color.redComponent
                totalG += color.greenComponent
                totalB += color.blueComponent
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return (r: totalR / count, g: totalG / count, b: totalB / count)
    }

    func openInMusic() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
    }

    func fetchAlbumTracks() {
        guard !album.isEmpty else { albumTracks = []; return }
        let escaped = album.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Music"
            set output to ""
            set lf to ASCII character 10
            set trks to every track of library playlist 1 whose album is "\(escaped)"
            repeat with t in trks
                set output to output & name of t & lf
            end repeat
            return output
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                guard let str = result?.stringValue else { self?.albumTracks = []; return }
                self?.albumTracks = str.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
            }
        }
    }

    // MARK: - Polling

    private func poll() {
        // If MediaRemote never returned data, use AppleScript only
        guard mediaRemoteWorks, let bridge else {
            pollAppleScript()
            return
        }

        bridge.getNowPlayingInfo(DispatchQueue.main) { [weak self] cfDict in
            guard let self else { return }
            let info = cfDict as NSDictionary
            if !info.allKeys.isEmpty {
                self.parseMediaRemote(info)
            } else {
                // MediaRemote returns nothing — disable it permanently
                self.mediaRemoteWorks = false
                Log.info("[Music] MediaRemote disabled, using AppleScript only")
                self.pollAppleScript()
            }
        }
    }

    private func parseMediaRemote(_ info: NSDictionary) {
        title = findStr(info, ["Title"])
        artist = findStr(info, ["Artist"])
        album = findStr(info, ["Album"])
        duration = findNum(info, ["Duration"])
        elapsed = findNum(info, ["ElapsedTime", "Elapsed"])
        playbackRate = findNum(info, ["PlaybackRate"])
        if playbackRate == 0 && isPlaying { playbackRate = 1.0 }
        if let data = findData(info, ["ArtworkData", "Artwork"]) { artwork = NSImage(data: data) }
    }

    private func pollAppleScript() {
        let source = """
        tell application "System Events"
            if not (exists (processes whose name is "Music")) then return "NOT_RUNNING"
        end tell
        tell application "Music"
            if player state is not playing and player state is not paused then return "NO_TRACK"
            set t to name of current track
            set a to artist of current track
            set al to album of current track
            set d to duration of current track
            set p to player position
            set s to player state as text
            set sh to shuffle enabled
            set fv to false
            try
                set fv to favorited of current track
            end try
            set vol to sound volume
            return t & "|" & a & "|" & al & "|" & (d as text) & "|" & (p as text) & "|" & s & "|" & (sh as text) & "|" & (fv as text) & "|" & (vol as text)
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                guard let self, let str = result?.stringValue else { return }
                if str == "NOT_RUNNING" || str == "NO_TRACK" { return }

                let parts = str.components(separatedBy: "|")
                guard parts.count >= 6 else { return }

                let newTitle = parts[0]
                let titleChanged = newTitle != self.title
                if titleChanged { Log.info("[Music] \(newTitle) - \(parts[1])") }

                self.title = newTitle
                self.artist = parts[1]
                self.album = parts[2]
                self.duration = self.parseLocalizedDouble(parts[3])
                self.elapsed = self.parseLocalizedDouble(parts[4])
                let nowPlaying = parts[5] == "playing"
                if Date() > self.playPauseCooldown { self.isPlaying = nowPlaying }
                self.playbackRate = nowPlaying ? 1.0 : 0
                if parts.count > 6 { self.isShuffled = parts[6] == "true" }
                if parts.count > 7 && Date() > self.favoriteCooldown {
                    self.isFavorited = parts[7] == "true"
                }
                if parts.count > 8 && Date() > self.volumeCooldown {
                    self.volume = self.parseLocalizedDouble(parts[8]) / 100.0
                }

                if self.isPlaying { self.startProgressTimer() } else { self.stopProgressTimer() }
                if titleChanged { self.fetchArtwork() }
            }
        }
    }

    /// Parse doubles from French locale (comma separator)
    private func parseLocalizedDouble(_ s: String) -> Double {
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private func fetchArtwork() {
        let source = """
        tell application "Music"
            try
                return raw data of artwork 1 of current track
            end try
        end tell
        """
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if let desc = result, desc.descriptorType != typeNull {
                    let data = desc.data
                    if !data.isEmpty { self?.artwork = NSImage(data: data) }
                }
            }
        }
    }

    private func runAS(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: source)?.executeAndReturnError(nil)
        }
    }

    // MARK: - Helpers

    private func findStr(_ d: NSDictionary, _ keys: [String]) -> String {
        for (k, v) in d { if let ks = k as? String, keys.contains(where: { ks.contains($0) }), let vs = v as? String { return vs } }
        return ""
    }
    private func findNum(_ d: NSDictionary, _ keys: [String]) -> Double {
        for (k, v) in d { if let ks = k as? String, keys.contains(where: { ks.contains($0) }) {
            if let n = v as? Double { return n }; if let n = v as? NSNumber { return n.doubleValue }
        }}; return 0
    }
    private func findData(_ d: NSDictionary, _ keys: [String]) -> Data? {
        for (k, v) in d { if let ks = k as? String, keys.contains(where: { ks.contains($0) }), let data = v as? Data { return data } }
        return nil
    }

    private func setupNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .init("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in self?.poll() }
        nc.addObserver(forName: .init("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in self?.poll() }
    }

    private func startProgressTimer() {
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying, self.duration > 0 else { return }
            self.elapsed += 1.0
            if self.elapsed >= self.duration { self.elapsed = self.duration }
        }
    }

    private func stopProgressTimer() { progressTimer?.invalidate(); progressTimer = nil }
}
