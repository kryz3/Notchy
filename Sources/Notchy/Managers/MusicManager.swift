import AppKit

// MARK: - Track types

struct QueueTrack: Identifiable, Equatable {
    let id: Int
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

enum ActivePlayer: String {
    case appleMusic = "Music"
    case spotify = "Spotify"
    case none = ""
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
    var activePlayer: ActivePlayer = .none
    var trackURI = ""       // Spotify URI of current track
    var isRepeating = false // Spotify repeat toggle
    var trackNumber = 0     // Track position in album
    var canPlayByURI: Bool { activePlayer == .spotify && !trackURI.isEmpty }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }
    var hasTrack: Bool { !title.isEmpty }
    var hasQueue: Bool { !queueTracks.isEmpty && !isAutoplay }

    var settings: SettingsManager?

    private var progressTimer: Timer?
    private var pollTimer: Timer?
    private var favoriteCooldown: Date = .distantPast
    private var playPauseCooldown: Date = .distantPast
    private var volumeCooldown: Date = .distantPast
    private var volumeBeforeMute: Double = 0.5

    init() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in self?.poll() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.poll() }
    }

    // MARK: - Detect active player

    private func detectPlayer() -> ActivePlayer {
        let pref = settings?.musicPlayer ?? .auto

        switch pref {
        case .appleMusic: return .appleMusic
        case .spotify: return .spotify
        case .auto:
            // Check which app is running and playing
            let check = { (name: String) -> Bool in
                var error: NSDictionary?
                let result = NSAppleScript(source: "tell application \"System Events\" to return exists (processes whose name is \"\(name)\")")?
                    .executeAndReturnError(&error)
                return result?.booleanValue ?? false
            }
            // Prefer whichever is currently playing, else whichever is running
            if check("Spotify") && check("Music") {
                // Both running — check which is playing
                var err: NSDictionary?
                let spotState = NSAppleScript(source: "tell application \"Spotify\" to return player state as text")?
                    .executeAndReturnError(&err).stringValue ?? ""
                if spotState == "playing" { return .spotify }
                return .appleMusic
            }
            if check("Spotify") { return .spotify }
            if check("Music") { return .appleMusic }
            return .none
        }
    }

    private var app: String { activePlayer.rawValue }

    // MARK: - Controls

    func togglePlayPause() {
        isPlaying.toggle()
        playPauseCooldown = Date().addingTimeInterval(3)
        runAS("tell application \"\(app)\" to playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.poll() }
    }

    func nextTrack() {
        runAS("tell application \"\(app)\" to next track")
        scheduleRefresh()
    }

    func previousTrack() {
        runAS("tell application \"\(app)\" to previous track")
        scheduleRefresh()
    }

    func toggleShuffle() {
        if activePlayer == .spotify {
            runAS("tell application \"Spotify\" to set shuffling to not shuffling")
        } else {
            runAS("tell application \"Music\" to set shuffle enabled to not shuffle enabled")
        }
        isShuffled.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.fetchQueue() }
    }

    func toggleFavorite() {
        guard activePlayer == .appleMusic else { return } // Spotify has no scriptable favorite
        let newState = !isFavorited
        isFavorited = newState
        favoriteCooldown = Date().addingTimeInterval(4)
        runAS("tell application \"Music\" to set favorited of current track to \(newState)")
    }

    var canFavorite: Bool { activePlayer == .appleMusic }
    var canRepeat: Bool { activePlayer == .spotify }

    func toggleRepeat() {
        guard activePlayer == .spotify else { return }
        isRepeating.toggle()
        runAS("tell application \"Spotify\" to set repeating to \(isRepeating)")
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
        runAS("tell application \"\(app)\" to set sound volume to \(Int(v * 100))")
    }

    func seekTo(fraction: Double) {
        guard duration > 0 else { return }
        elapsed = fraction * duration
        if activePlayer == .spotify {
            // Spotify: player position is in seconds
            runAS("tell application \"Spotify\" to set player position to \(elapsed)")
        } else {
            runAS("tell application \"Music\" to set player position to \(elapsed)")
        }
    }

    func openInPlayer() {
        let path = activePlayer == .spotify
            ? "/Applications/Spotify.app"
            : "/System/Applications/Music.app"
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func playTrackFromHistory(_ track: HistoryTrack) {
        if activePlayer == .appleMusic {
            let escaped = track.title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            runJXA("const m=Application('Music');const t=m.playlists['Musique'].tracks.whose({name:'\(escaped)'})[0];if(t)t.play();")
        }
        // Spotify: can't play specific track by name via AppleScript
        scheduleRefresh()
    }

    func playAlbumTrack(_ track: AlbumTrack) {
        guard activePlayer == .appleMusic else { return }
        let escaped = albumName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        runJXA("const m=Application('Music');const ts=m.playlists['Musique'].tracks.whose({album:'\(escaped)'});if(ts.length>\(track.id))ts[\(track.id)].play();")
        scheduleRefresh()
    }

    func playFullAlbum() {
        guard activePlayer == .appleMusic else { return }
        let escaped = albumName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        runJXA("const m=Application('Music');const ts=m.playlists['Musique'].tracks.whose({album:'\(escaped)'});if(ts.length>0)ts[0].play();")
        scheduleRefresh()
    }

    // MARK: - Fetch queue (Apple Music only via JXA)

    func fetchQueue() {
        guard activePlayer == .appleMusic else {
            queueTracks = []
            return
        }
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
                self.queueTracks = []; return
            }
            let lines = output.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
            if let first = lines.first, first.hasPrefix("PL:") {
                self.playlistName = String(first.dropFirst(3))
            }
            self.queueTracks = lines.dropFirst().compactMap { line in
                let isCurrent = line.hasPrefix(">>>")
                let cleaned = String(line.dropFirst(3))
                let parts = cleaned.components(separatedBy: "|||")
                guard parts.count >= 3, let idx = Int(parts[0]) else { return nil }
                return QueueTrack(id: idx, title: parts[1], artist: parts[2], isCurrent: isCurrent)
            }
        }
    }

    // MARK: - Fetch album tracks (Apple Music only)

    func fetchAlbumTracks() {
        albumName = album
        guard activePlayer == .appleMusic, !album.isEmpty else { albumTracks = []; return }
        let source = """
        tell application "Music"
            set al to album of current track
            set lf to ASCII character 10
            set output to ""
            set trks to (every track of library playlist 1 whose album is al)
            if (count of trks) is 0 then
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
                    self?.albumTracks = []; return
                }
                self.albumTracks = str.components(separatedBy: CharacterSet.newlines)
                    .filter { !$0.isEmpty }
                    .enumerated().map { AlbumTrack(id: $0.offset, title: $0.element) }
            }
        }
    }

    // MARK: - Polling

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.poll() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in self?.fetchQueue() }
    }

    private func poll() {
        let detected = detectPlayer()
        if detected != activePlayer {
            activePlayer = detected
            Log.info("[Music] Active player: \(activePlayer.rawValue)")
        }
        guard activePlayer != .none else { return }

        if activePlayer == .spotify {
            pollSpotify()
        } else {
            pollAppleMusic()
        }
    }

    // MARK: - Apple Music poll

    private func pollAppleMusic() {
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
                if titleChanged { self.addToHistory(); Log.info("[Music] \(newTitle) - \(parts[1])") }

                self.title = newTitle; self.artist = parts[1]; self.album = parts[2]
                self.duration = self.parseNum(parts[3])
                self.elapsed = self.parseNum(parts[4])
                let nowPlaying = parts[5] == "playing"
                if Date() > self.playPauseCooldown { self.isPlaying = nowPlaying }
                if parts.count > 6 { self.isShuffled = parts[6] == "true" }
                if parts.count > 7 && Date() > self.favoriteCooldown { self.isFavorited = parts[7] == "true" }
                if parts.count > 8 && Date() > self.volumeCooldown {
                    let v = self.parseNum(parts[8]) / 100.0; self.volume = v; self.isMuted = v < 0.01
                }
                if parts.count > 9 { self.isAutoplay = parts[9] != "true" }

                if self.isPlaying { self.startProgressTimer() } else { self.stopProgressTimer() }
                if titleChanged { self.fetchAppleMusicArtwork(); self.fetchQueue() }
            }
        }
    }

    // MARK: - Spotify poll

    private func pollSpotify() {
        let source = """
        tell application "System Events"
            if not (exists (processes whose name is "Spotify")) then return "NOT_RUNNING"
        end tell
        tell application "Spotify"
            if player state is stopped then return "NO_TRACK"
            set t to name of current track
            set a to artist of current track
            set al to album of current track
            set d to duration of current track
            set p to player position
            set s to player state as text
            set sh to shuffling
            set vol to sound volume
            set artURL to artwork url of current track
            set uri to spotify url of current track
            set rep to repeating
            set tn to track number of current track
            return t & "|" & a & "|" & al & "|" & (d as text) & "|" & (p as text) & "|" & s & "|" & (sh as text) & "|" & (vol as text) & "|" & artURL & "|" & uri & "|" & (rep as text) & "|" & (tn as text)
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
                if titleChanged { self.addToHistory(); Log.info("[Spotify] \(newTitle) - \(parts[1])") }

                self.title = newTitle; self.artist = parts[1]; self.album = parts[2]
                // Spotify: duration is in MILLISECONDS
                self.duration = self.parseNum(parts[3]) / 1000.0
                self.elapsed = self.parseNum(parts[4])
                let nowPlaying = parts[5] == "playing"
                if Date() > self.playPauseCooldown { self.isPlaying = nowPlaying }
                if parts.count > 6 { self.isShuffled = parts[6] == "true" }
                self.isFavorited = false
                if parts.count > 7 && Date() > self.volumeCooldown {
                    let v = self.parseNum(parts[7]) / 100.0; self.volume = v; self.isMuted = v < 0.01
                }
                if parts.count > 9 { self.trackURI = parts[9] }
                if parts.count > 10 { self.isRepeating = parts[10] == "true" }
                if parts.count > 11 { self.trackNumber = Int(self.parseNum(parts[11])) }
                self.isAutoplay = false // Spotify: no queue via scripting, but shuffle/controls work

                if self.isPlaying { self.startProgressTimer() } else { self.stopProgressTimer() }
                if titleChanged {
                    if parts.count > 8, let url = URL(string: parts[8]) {
                        self.fetchSpotifyArtwork(url: url)
                    }
                }
            }
        }
    }

    // MARK: - Artwork

    private func fetchAppleMusicArtwork() {
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

    private func fetchSpotifyArtwork(url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                if let data, let img = NSImage(data: data) {
                    self?.artwork = img
                }
            }
        }.resume()
    }

    // MARK: - History

    private func addToHistory() {
        guard !title.isEmpty else { return }
        history.insert(HistoryTrack(title: title, artist: artist, album: album), at: 0)
        let max = (settings?.musicHistorySize ?? 5) * 3
        if history.count > max { history = Array(history.prefix(max)) }
    }

    // MARK: - Helpers

    private func parseNum(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
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
                DispatchQueue.main.async { completion(String(data: data, encoding: .utf8) ?? "") }
            } catch {}
        }
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
