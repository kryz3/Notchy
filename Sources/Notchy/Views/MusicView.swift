import SwiftUI

/// Tap-only control — no hover highlight
struct TapIcon: View {
    let icon: String
    let size: CGFloat
    let color: Color
    let action: () -> Void

    init(_ icon: String, size: CGFloat = 13, color: Color = .white, action: @escaping () -> Void) {
        self.icon = icon; self.size = size; self.color = color; self.action = action
    }

    @State private var pressed = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size))
            .foregroundStyle(color)
            .opacity(pressed ? 0.4 : 1.0)
            .contentShape(Rectangle().inset(by: -6))
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { p in pressed = p }, perform: {})
    }
}

struct MusicView: View {
    @Bindable var music: MusicManager
    @State private var showQueue = false
    @State private var showVolume = false

    var body: some View {
        VStack(spacing: 8) {
            if showQueue && music.hasTrack {
                queueView
            } else {
                playerView
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Player

    private var playerView: some View {
        VStack(spacing: 8) {
            artworkWithGlow
            if music.hasTrack {
                VStack(spacing: 1) {
                    Text(music.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text(music.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                progressBar
                controlButtons
                secondaryButtons
            } else {
                noTrackView
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Artwork with glow

    private var artworkWithGlow: some View {
        ZStack {
            // Glow behind
            if let img = music.artwork, let c = music.artworkDominantColor {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .opacity(0.6)
                    .scaleEffect(1.1)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                Color(red: c.r, green: c.g, blue: c.b).opacity(0.3)
                            )
                            .blur(radius: 20)
                    )
            }

            // Actual artwork
            artworkImage
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: - Queue

    private var queueView: some View {
        VStack(spacing: 8) {
            HStack {
                TapIcon("chevron.left", size: 11, color: .white.opacity(0.5)) { showQueue = false }
                Text(music.album.isEmpty ? "File d'attente" : music.album)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Spacer()
            }

            HStack(spacing: 8) {
                if let art = music.artwork {
                    Image(nsImage: art).resizable().frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(music.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(music.artist).font(.system(size: 9)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                }
                Spacer()
                Text("En cours").font(.system(size: 9, weight: .medium)).foregroundStyle(.green)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))

            if music.albumTracks.isEmpty {
                Spacer()
                Text("Pas d'infos sur l'album").font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(Array(music.albumTracks.enumerated()), id: \.offset) { idx, track in
                            HStack(spacing: 8) {
                                Text("\(idx + 1)").font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.2)).frame(width: 16)
                                Text(track).font(.system(size: 11))
                                    .foregroundStyle(track == music.title ? .white : .white.opacity(0.5))
                                    .fontWeight(track == music.title ? .semibold : .regular).lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 3).padding(.horizontal, 6)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 20) {
                TapIcon("backward.fill", size: 12) { music.previousTrack() }
                TapIcon(music.isPlaying ? "pause.fill" : "play.fill", size: 16) { music.togglePlayPause() }
                TapIcon("forward.fill", size: 12) { music.nextTrack() }
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
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    music.seekTo(fraction: max(0, min(1, value.location.x / geo.size.width)))
                })
            }
            .frame(height: 14)

            HStack {
                Text(formatTime(music.elapsed)); Spacer(); Text(formatTime(music.duration))
            }
            .font(.system(size: 8, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.35))
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
            TapIcon("shuffle", size: 11, color: music.isShuffled ? .green : .white.opacity(0.35)) {
                music.toggleShuffle()
            }

            // Volume: click to mute/unmute, hover to show slider
            volumeControl

            TapIcon("list.bullet", size: 11, color: .white.opacity(0.35)) {
                showQueue.toggle()
                if showQueue { music.fetchAlbumTracks() }
            }
            TapIcon("arrow.up.right", size: 11, color: .white.opacity(0.35)) {
                music.openInMusic()
            }
            TapIcon(music.isFavorited ? "heart.fill" : "heart", size: 11,
                    color: music.isFavorited ? .pink : .white.opacity(0.35)) {
                music.toggleFavorite()
            }
        }
    }

    // MARK: - Volume

    private var volumeIcon: String {
        if music.isMuted || music.volume < 0.01 { return "speaker.slash.fill" }
        if music.volume < 0.33 { return "speaker.wave.1.fill" }
        if music.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var volumeControl: some View {
        ZStack(alignment: .top) {
            // Horizontal slider popup ABOVE the icon
            if showVolume {
                volumeSliderPopup
                    .offset(y: -34)
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Icon: click to mute
            Image(systemName: volumeIcon)
                .font(.system(size: 11))
                .foregroundStyle(music.isMuted ? .red.opacity(0.6) : .white.opacity(0.35))
                .onTapGesture { music.toggleMute() }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { showVolume = hovering }
        }
    }

    private var volumeSliderPopup: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.3))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15)).frame(height: 4)
                    Capsule().fill(.white.opacity(0.7))
                        .frame(width: max(0, geo.size.width * music.volume), height: 4)
                }
                .frame(height: 4).frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    music.setVolume(max(0, min(1, value.location.x / geo.size.width)))
                })
            }
            .frame(width: 80, height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.92))
                .shadow(color: .black.opacity(0.4), radius: 6)
        )
    }

    // MARK: - No track

    private var noTrackView: some View {
        VStack(spacing: 8) {
            Text("Rien en lecture").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            TapIcon("play.circle.fill", size: 28, color: .white.opacity(0.5)) { openAndPlayMusic() }
        }
    }

    private func openAndPlayMusic() {
        NSAppleScript(source: """
            tell application "Music"
                activate
                set shuffle enabled to true
                play (every track of library playlist 1)
            end tell
        """)?.executeAndReturnError(nil)
    }

    private func formatTime(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
