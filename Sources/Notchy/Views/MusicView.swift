import SwiftUI

struct TapIcon: View {
    let icon: String; let size: CGFloat; let color: Color; let action: () -> Void
    init(_ icon: String, size: CGFloat = 13, color: Color = .white, action: @escaping () -> Void) {
        self.icon = icon; self.size = size; self.color = color; self.action = action
    }
    @State private var pressed = false
    var body: some View {
        Image(systemName: icon).font(.system(size: size)).foregroundStyle(color)
            .opacity(pressed ? 0.4 : 1.0)
            .contentShape(Rectangle().inset(by: -6))
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { p in pressed = p }, perform: {})
    }
}

enum MusicSubView { case player, queue, album }

struct MusicView: View {
    @Bindable var music: MusicManager
    @State private var subView: MusicSubView = .player
    @State private var showVolume = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 8) {
            switch subView {
            case .player: playerView
            case .queue: queueView
            case .album: albumView
            }
        }
        .padding(.top, 2)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: subView)
    }

    // MARK: - Player

    private var playerView: some View {
        VStack(spacing: 8) {
            // Artwork — tap to show album
            artworkWithGlow
                .onTapGesture {
                    music.fetchAlbumTracks()
                    subView = .album
                }

            if music.hasTrack {
                VStack(spacing: 1) {
                    Text(music.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(music.artist).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                progressBar
                controlButtons
                secondaryButtons
            } else {
                Text(L.nothingPlaying).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                TapIcon("play.circle.fill", size: 28, color: .white.opacity(0.5)) { shufflePlay() }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Album view

    private var albumView: some View {
        VStack(spacing: 8) {
            HStack {
                TapIcon("chevron.left", size: 11, color: .white.opacity(0.5)) { subView = .player }
                Text(music.albumName.isEmpty ? "Album" : music.albumName)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                Spacer()
            }

            if music.albumTracks.isEmpty {
                // Album not in library (streaming) — show fallback
                Spacer()
                VStack(spacing: 8) {
                    if let img = music.artwork {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text(music.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    Text(L.albumNotInLibrary)
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                    TapIcon("arrow.up.right.circle", size: 16, color: .white.opacity(0.4)) {
                        music.openInMusic()
                    }
                }
                Spacer()
            } else {
                HStack {
                    Spacer()
                    TapIcon("play.fill", size: 10, color: .white.opacity(0.5)) {
                        music.playFullAlbum()
                        subView = .player
                    }
                    Text(L.playAll).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(music.albumTracks) { track in
                            HStack(spacing: 8) {
                                Text("\(track.id + 1)").font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.2)).frame(width: 18)
                                Text(track.title).font(.system(size: 11))
                                    .foregroundStyle(track.title == music.title ? .white : .white.opacity(0.55))
                                    .fontWeight(track.title == music.title ? .semibold : .regular).lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 4).padding(.horizontal, 6)
                            .background(track.title == music.title ? RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)) : nil)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                music.playAlbumTrack(track)
                                subView = .player
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            miniControls
        }
    }

    // MARK: - Queue & History

    private var queueView: some View {
        VStack(spacing: 8) {
            HStack {
                TapIcon("chevron.left", size: 11, color: .white.opacity(0.5)) { subView = .player }

                if music.hasQueue {
                    Text(music.playlistName)
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                }

                Spacer()

                // Tabs only if queue is available
                if music.hasQueue {
                    HStack(spacing: 0) {
                        tabBtn(L.upNext, selected: !showHistory) { showHistory = false }
                        tabBtn(L.history, selected: showHistory) { showHistory = true }
                    }
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06)))
                } else {
                    Text(L.history)
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
            }

            if music.hasQueue && !showHistory {
                // Up next list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(music.queueTracks) { track in
                            trackRow(track.title, track.artist, current: track.isCurrent)
                        }
                    }
                }
            } else {
                // History (default when no queue)
                historyList
            }

            Spacer(minLength: 0)
            miniControls
        }
    }

    private func tabBtn(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label).font(.system(size: 10, weight: .medium))
            .foregroundStyle(selected ? .white : .white.opacity(0.35))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(selected ? RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)) : nil)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { action() } }
    }

    private var historyList: some View {
        Group {
            let visible = Array(music.history.prefix(music.settings?.musicHistorySize ?? 5))
            if visible.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clock").font(.system(size: 20)).foregroundStyle(.white.opacity(0.2))
                    Text(L.noHistory).font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(visible) { track in
                            trackRow(track.title, track.artist, current: false, dimmed: true)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    music.playTrackFromHistory(track)
                                    subView = .player
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared components

    private func trackRow(_ title: String, _ artist: String, current: Bool, dimmed: Bool = false) -> some View {
        HStack(spacing: 8) {
            if current {
                Image(systemName: "play.fill").font(.system(size: 7)).foregroundStyle(.green).frame(width: 14)
            } else {
                Color.clear.frame(width: 14, height: 1)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11, weight: current ? .semibold : .regular))
                    .foregroundStyle(current ? .white : .white.opacity(dimmed ? 0.4 : 0.55)).lineLimit(1)
                Text(artist).font(.system(size: 9))
                    .foregroundStyle(.white.opacity(current ? 0.5 : (dimmed ? 0.2 : 0.25))).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(current ? RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)) : nil)
    }

    private var miniControls: some View {
        HStack(spacing: 20) {
            TapIcon("backward.fill", size: 12) { music.previousTrack() }
            TapIcon(music.isPlaying ? "pause.fill" : "play.fill", size: 16) { music.togglePlayPause() }
            TapIcon("forward.fill", size: 12) { music.nextTrack() }
        }
    }

    // MARK: - Artwork with glow

    private var artworkWithGlow: some View {
        ZStack {
            if let img = music.artwork {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 130, height: 130).blur(radius: 35).opacity(0.7).scaleEffect(1.3)
            }
            artworkImage.frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(width: 140, height: 140)
    }

    @ViewBuilder
    private var artworkImage: some View {
        if let artwork = music.artwork {
            Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05))
                Image(systemName: "music.note").font(.system(size: 32)).foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15)).frame(height: 3)
                    Capsule().fill(.white.opacity(0.8))
                        .frame(width: max(0, geo.size.width * music.progress), height: 3)
                }
                .frame(height: 3).frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    music.seekTo(fraction: max(0, min(1, v.location.x / geo.size.width)))
                })
            }
            .frame(height: 14)
            HStack {
                Text(fmt(music.elapsed)); Spacer(); Text(fmt(music.duration))
            }.font(.system(size: 8, weight: .medium).monospacedDigit()).foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 24) {
            TapIcon("backward.fill", size: 13) { music.previousTrack() }
            TapIcon(music.isPlaying ? "pause.fill" : "play.fill", size: 18) { music.togglePlayPause() }
            TapIcon("forward.fill", size: 13) { music.nextTrack() }
        }
    }

    private var secondaryButtons: some View {
        HStack(spacing: 14) {
            TapIcon("shuffle", size: 11,
                    color: music.isAutoplay ? .white.opacity(0.12) : (music.isShuffled ? .green : .white.opacity(0.35))) {
                if !music.isAutoplay { music.toggleShuffle() }
            }
            volumeControl
            TapIcon("list.bullet", size: 11, color: .white.opacity(0.35)) {
                subView = .queue
                showHistory = !music.hasQueue
                if music.hasQueue { music.fetchQueue() }
            }
            TapIcon("arrow.up.right", size: 11, color: .white.opacity(0.35)) { music.openInMusic() }
            TapIcon(music.isFavorited ? "heart.fill" : "heart", size: 11,
                    color: music.isFavorited ? .pink : .white.opacity(0.35)) { music.toggleFavorite() }
        }
    }

    // MARK: - Volume

    private var volumeControl: some View {
        let icon = music.isMuted ? "speaker.slash.fill"
            : music.volume < 0.33 ? "speaker.wave.1.fill"
            : music.volume < 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"

        return Image(systemName: icon).font(.system(size: 11))
            .foregroundStyle(music.isMuted ? .red.opacity(0.6) : .white.opacity(0.35))
            .frame(width: 16, height: 16).contentShape(Rectangle().inset(by: -4))
            .onTapGesture { music.toggleMute() }
            .overlay(alignment: .top) {
                if showVolume {
                    HStack(spacing: 5) {
                        Image(systemName: "speaker.fill").font(.system(size: 7)).foregroundStyle(.white.opacity(0.3))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.15)).frame(height: 3)
                                Capsule().fill(.white.opacity(0.7))
                                    .frame(width: max(0, geo.size.width * music.volume), height: 3)
                            }.frame(height: 3).frame(maxHeight: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                                music.setVolume(max(0, min(1, v.location.x / geo.size.width)))
                            })
                        }.frame(width: 70, height: 16)
                        Image(systemName: "speaker.wave.3.fill").font(.system(size: 7)).foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.92)).shadow(color: .black.opacity(0.3), radius: 5))
                    .offset(y: -32)
                    .onHover { h in if h { withAnimation(.easeInOut(duration: 0.12)) { showVolume = true } } }
                }
            }
            .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { showVolume = h } }
    }

    private func shufflePlay() {
        NSAppleScript(source: """
            tell application "Music"
                activate
                set shuffle enabled to true
                play (every track of library playlist 1)
            end tell
        """)?.executeAndReturnError(nil)
    }

    private func fmt(_ s: Double) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }
}
