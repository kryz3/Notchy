# Notchy

Transform your MacBook's notch into a Dynamic Island. Hover to reveal a productivity hub with music, calendar, reminders, notes, and a terminal.

![Notchy](screenshot.png)

## Features

**Music** — Control Apple Music directly from the notch. Play/pause, skip, seek, shuffle, volume, favorite. Album artwork with dynamic glow. View album tracklist.

**Calendar** — See today's events, navigate between days, create and delete events with calendar picker. Tap an event to open Calendar.app.

**Reminders** — View and check off reminders, create and delete with animations.

**Notes** — Persistent sticky note with markdown preview, plus a freehand drawing canvas with colors and stroke sizes.

**Terminal** — Built-in zsh with tab autocompletion and persistent command history.

**System** — Clock display, audio device notifications (AirPods), glassmorphism theme option, launch at login.

## Install

Download the latest `Notchy.dmg` from [Releases](https://github.com/kryz3/Notchy/releases), open it and drag **Notchy.app** into **Applications**.

### Build from source

```bash
git clone https://github.com/kryz3/Notchy.git
cd Notchy
bash build.sh
open Notchy.app
```

To generate the DMG: `bash make-dmg.sh`

Requires macOS 14+, Swift toolchain, and a MacBook with notch.

## License

MIT
