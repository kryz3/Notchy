# Notchy

Transform your MacBook's notch into a Dynamic Island. Hover to reveal a productivity hub with music, calendar, reminders, notes, and a terminal.

![Notchy](screenshot.png)

## Features

**Music** — Control Apple Music or Spotify from the notch. Play/pause, skip, seek, shuffle, volume, favorite. Album artwork with dynamic glow.

**Calendar** — Today's events, navigate between days, create/delete events. Tap to open Calendar.app.

**Reminders** — View, create, check off and delete reminders.

**Notes** — Persistent sticky note with markdown preview + freehand drawing canvas.

**Clipboard** — Persistent clipboard history with quick copy.

**Terminal** — Built-in zsh with tab autocompletion and persistent history.

**System** — Weather, timer, battery/CPU/RAM/Bluetooth indicators, glassmorphism theme, accent colors, compact mode, FR/EN, auto-updates, launch at login.

## Install

1. Download `Notchy.dmg` from [Releases](https://github.com/kryz3/Notchy/releases)
2. Open the DMG and drag **Notchy.app** into **Applications**
3. Open Terminal and run:
   ```bash
   xattr -cr /Applications/Notchy.app
   ```
4. Launch Notchy from Applications

> The `xattr` command removes the macOS quarantine flag. This is required because the app is not signed with an Apple Developer certificate ($99/year).

Updates are automatic — check from Settings inside the app.

### Build from source

```bash
git clone https://github.com/kryz3/Notchy.git
cd Notchy
bash install.sh
```

Requires macOS 14+, Swift toolchain, and a MacBook with notch.

## License

MIT
