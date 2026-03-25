import AppKit

// MARK: - MediaRemote bridge

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

// MARK: - Track types

struct QueueTrack: Identifiable, Equatable {
    let id: Int // playlist index
    let title: String
    let artist: String
    let isCurrent: Bool
    static func == (l: QueueTrack, r: QueueTrack) -> Bool { l.id == r.id && l.isCurrent == r.isCurrent }
}

struct HistoryTrack: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
}

struct AlbumTrack: Identifiable {
    let id: Int
    let title: String
}

// MARK: - MusicManager

@Observable
final class MusicManager {
    var title = ""
    var artist = ""
    var album = ""
    var artwork: NSImage?
    var isPlaying = false
    var duration: Double = 0
    var elapsed: Double = 0
    var playbackRate: Double = 1.0
    var isFavorited = false
    var isShuffled = false
    var isMuted = false
    var volume: Double = 0.5
    var isAutoplay = false
    var playlistName = ""
    var queueTracks: [QueueTrack] = []
    var history: [HistoryTrack] = []
    var albumTracks: [AlbumTrack] = []
    var albumName = ""

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }
    var hasTrack: Bool { !title.isEmpty }

    var settings: SettingsManager?

    private var bridge: MRBridge?
    private var mediaRemoteWorks = true
    private var progressTimer: Timer?
    private var pollTimer: Timer?
    private var favoriteCooldown: Date = .distantPast
    private var playPauseCooldown: Date = .distantPast
    private var volumeCooldown: Date = .distantPast
    private var volumeBeforeMute: Double = 0.5
    private var lastPolledTitle = ""

    init() {
        bridge = MRBridge.load()
        if bridge != nil {
            bridge?.registerNotifications(DispatchQueue.main)
            setupNotifications()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in self?.poll() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.poll() }
    }

    // MARK: - Controls

    func togglePlayPause() {
        isPlaying.toggle()
        playPauseCooldown = Date().addingTimeInterval(3)
        runAS("tell application \"Music\" to playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.poll() }
    }

    func nextTrack() {
        runAS("tell application \"Music\" to next track")
        scheduleRefresh()
    }

    func previousTrack() {
        runAS("tell application \"Music\" to previous track")
        scheduleRefresh()
    }

    func toggleShuffle() {
        runAS("tell application \"Music\" to set shuffle enabled to not shuffle enabled")
        isShuffled.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.fetchQueue() }
    }

    func toggleFavorite() {
        let newState = !isFavorited
        isFavorited = newState
        favoriteCooldown = Date().addingTimeInterval(4)
        runAS("tell application \"Music\" to set favorited of current track to \(newState)")
    }

    func toggleMute() {
        if isMuted {
            setVolume(volumeBeforeMute > 0.01 ? volumeBeforeMute : 0.5)
        } else {
            volumeBeforeMute = volume
            setVolume(0)
        }
    }

    func setVolume(_ v: Double) {
        volume = v
        isMuted = v < 0.01
        volumeCooldown = Date().addingTimeInterval(3)
        runAS("tell application \"Music\" to set sound volume to \(Int(v * 100))")
    }

    func seekTo(fraction: Double) {
        guard duration > 0 else { return }
        elapsed = fraction * duration
        runAS("tell application \"Music\" to set player position to \(elapsed)")
    }

    func openInMusic() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
    }

    func playTrackFromHistory(_ track: HistoryTrack) {
        let escaped = track.title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        runJXA("const m=Application('Music');const t=m.playlists['Musique'].tracks.whose({name:'\(escaped)'})[0];if(t)t.play();")
        scheduleRefresh()
    }

    func playAlbumTrack(_ track: AlbumTrack) {
        let escaped = albumName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        runJXA("const m=Application('Music');const ts=m.playlists['Musique'].tracks.whose({album:'\(escaped)'});if(ts.length>\(track.id))ts[\(track.id)].play();")
        scheduleRefresh()
    }

    func playFullAlbum() {
        let escaped = albumName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        runJXA("const m=Application('Music');const ts=m.playlists['Musique'].tracks.whose({album:'\(escaped)'});if(ts.length>0)ts[0].play();")
        scheduleRefresh()
    }

    /// Whether queue data is available (not autoplay, not shuffle)
    var hasQueue: Bool { !queueTracks.isEmpty && !isAutoplay }

    // MARK: - Fetch queue (JXA)

    func fetchQueue() {
        let count = settings?.queueSize ?? 5
        let jxa = """
        const m=Application('Music');let out='';
        try{const ct=m.currentTrack();const pl=m.currentPlaylist();const plName=pl.name();
        const ctId=ct.databaseID();const tracks=pl.tracks();const total=tracks.length;
        let idx=-1;for(let i=0;i<total;i++){if(tracks[i].databaseID()===ctId){idx=i;break;}}
        out+='PL:'+plName+'\\n';
        const end=Math.min(total,idx+\(count)+1);
        for(let i=idx;i<end;i++){out+=(i===idx?'>>>':'   ')+i+'|||'+tracks[i].name()+'|||'+tracks[i].artist()+'\\n';}
        }catch(e){out='ERROR:'+e.message;}out;
        """
        runJXACapture(jxa) { [weak self] output in
            guard let self else { return }
            if output.contains("ERROR") || output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Queue not available — clear it
                self.queueTracks = []
                return
            }
            let lines = output.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
            if let first = lines.first, first.hasPrefix("PL:") {
                self.playlistName = String(first.dropFirst(3))
            }
            let parsed: [QueueTrack] = lines.dropFirst().compactMap { line in
                let isCurrent = line.hasPrefix(">>>")
                let cleaned = String(line.dropFirst(3))
                let parts = cleaned.components(separatedBy: "|||")
                guard parts.count >= 3, let idx = Int(parts[0]) else { return nil }
                return QueueTrack(id: idx, title: parts[1], artist: parts[2], isCurrent: isCurrent)
            }
            self.queueTracks = parsed
        }
    }

    // MARK: - Fetch album tracks (via AppleScript search — works for streaming too)

    func fetchAlbumTracks() {
        albumName = album
        guard !album.isEmpty else { albumTracks = []; return }
        // Use search which works for both library and streaming tracks
        let source = """
        tell application "Music"
            set al to album of current track
            set lf to ASCII character 10
            set output to ""
            -- Try library first
            set trks to (every track of library playlist 1 whose album is al)
            if (count of trks) is 0 then
                -- Fallback: search
                set trks to (search library playlist 1 for al only albums)
            end if
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
                guard let self, let str = result?.stringValue, !str.isEmpty else {
                    self?.albumTracks = []
                    return
                }
                let tracks = str.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
                self.albumTracks = tracks.enumerated().map { AlbumTrack(id: $0.offset, title: $0.element) }
            }
        }
    }

    // MARK: - Polling

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.poll() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in self?.fetchQueue() }
    }

    private func poll() {
        guard mediaRemoteWorks, let bridge else { pollAppleScript(); return }
        bridge.getNowPlayingInfo(DispatchQueue.main) { [weak self] cfDict in
            let info = cfDict as NSDictionary
            if !info.allKeys.isEmpty { self?.parseMediaRemote(info); return }
            self?.mediaRemoteWorks = false
            self?.pollAppleScript()
        }
    }

    private func parseMediaRemote(_ info: NSDictionary) {
        title = findStr(info, ["Title"]); artist = findStr(info, ["Artist"]); album = findStr(info, ["Album"])
        duration = findNum(info, ["Duration"]); elapsed = findNum(info, ["ElapsedTime", "Elapsed"])
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
            set hasPlaylist to "false"
            try
                set plName to name of current playlist
                set hasPlaylist to "true"
            end try
            return t & "|" & a & "|" & al & "|" & (d as text) & "|" & (p as text) & "|" & s & "|" & (sh as text) & "|" & (fv as text) & "|" & (vol as text) & "|" & hasPlaylist
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

                if titleChanged {
                    // Add to history
                    if !self.title.isEmpty {
                        self.history.insert(HistoryTrack(title: self.title, artist: self.artist, album: self.album), at: 0)
                        let max = (self.settings?.musicHistorySize ?? 5) * 3
                        if self.history.count > max { self.history = Array(self.history.prefix(max)) }
                    }
                    Log.info("[Music] \(newTitle) - \(parts[1])")
                }

                self.title = newTitle
                self.artist = parts[1]
                self.album = parts[2]
                self.duration = self.parseNum(parts[3])
                self.elapsed = self.parseNum(parts[4])
                let nowPlaying = parts[5] == "playing"
                if Date() > self.playPauseCooldown { self.isPlaying = nowPlaying }
                self.playbackRate = nowPlaying ? 1.0 : 0
                if parts.count > 6 { self.isShuffled = parts[6] == "true" }
                if parts.count > 7 && Date() > self.favoriteCooldown { self.isFavorited = parts[7] == "true" }
                if parts.count > 8 && Date() > self.volumeCooldown {
                    let v = self.parseNum(parts[8]) / 100.0
                    self.volume = v; self.isMuted = v < 0.01
                }
                if parts.count > 9 { self.isAutoplay = parts[9] != "true" }

                if self.isPlaying { self.startProgressTimer() } else { self.stopProgressTimer() }
                if titleChanged {
                    self.fetchArtwork()
                    // Always try to refresh queue on track change
                    self.fetchQueue()
                }
            }
        }
    }

    private func fetchArtwork() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: "tell application \"Music\" to return raw data of artwork 1 of current track")?
                .executeAndReturnError(&error)
            DispatchQueue.main.async {
                if let desc = result, desc.descriptorType != typeNull, !desc.data.isEmpty {
                    self?.artwork = NSImage(data: desc.data)
                }
            }
        }
    }

    // MARK: - Helpers

    private func parseNum(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private func findStr(_ d: NSDictionary, _ keys: [String]) -> String {
        for (k, v) in d { if let ks = k as? String, keys.contains(where: { ks.contains($0) }), let vs = v as? String { return vs } }; return ""
    }
    private func findNum(_ d: NSDictionary, _ keys: [String]) -> Double {
        for (k, v) in d { if let ks = k as? String, keys.contains(where: { ks.contains($0) }) {
            if let n = v as? Double { return n }; if let n = v as? NSNumber { return n.doubleValue }
        }}; return 0
    }
    private func findData(_ d: NSDictionary, _ keys: [String]) -> Data? {
        for (k, v) in d { if let ks = k as? String, keys.contains(where: { ks.contains($0) }), let d = v as? Data { return d } }; return nil
    }

    private func runAS(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async { NSAppleScript(source: source)?.executeAndReturnError(nil) }
    }
    private func runJXA(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-l", "JavaScript", "-e", script]
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            try? p.run(); p.waitUntilExit()
        }
    }
    private func runJXACapture(_ script: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process(); let pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-l", "JavaScript", "-e", script]
            p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
            do {
                try p.run(); p.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async { completion(output) }
            } catch {}
        }
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
            self.elapsed += 1.0; if self.elapsed >= self.duration { self.elapsed = self.duration }
        }
    }
    private func stopProgressTimer() { progressTimer?.invalidate(); progressTimer = nil }
}
