# Ignis → Quickshell migration plan

Target: Quickshell 0.3.2 (`pacman -S quickshell`, extra repo). Config lives here,
symlinked to `~/.config/quickshell` (same pattern as `~/.config/ignis`).

Goals: feature parity with the current Ignis setup, no work on the UI thread that
can block (every shell-out is an async `Process`), bounded memory (capped
notification history, lazily-loaded popups), and keeping it easy to extend.

---

## 1. Current Ignis feature inventory

Source: `~/dotfiles/ignis` (fork of linkfrg's example config + custom modules).
**Custom** = written by you, not from the upstream example.

### Bar (one per monitor, top, exclusive zone, layer namespace `ignis_BAR_<n>`, blurred via `rules.lua`)
| # | Feature | Details | Origin |
|---|---|---|---|
| B1 | Workspaces | Existing Hyprland workspaces as buttons; labels mapped to hotkeys (1–9, 10→`0`, 11→`O`, 12→`C`, 13→`N`, 14→`M`, 15→`T`); active highlighted; click switches; scroll up/down = prev/next, stops at 10 | modified |
| B2 | Meeting-record button | D-Bus client for `org.meetingnotes.Service` (properties IsRecording / CurrentMeeting / PickerActive; methods PickAndStartRecording, CancelPick, StartManualRecording(addr), StopRecording(force), ToggleManualRecording; signals CommandFailed, RecordingDegraded). States: idle / picking (pulse) / active+mm:ss timer / auto (provider-started) / error flash 4 s / unavailable. Left-click: pick ↔ cancel ↔ stop (manual) or menu (auto). Right-click menu: pick on screen, record focused, list of up to 12 Hyprland windows `[ws] class — title`, stop/force stop, open `http://127.0.0.1:8636` | **custom** |
| B3 | Now-playing label (centre) | MPRIS; prefers a Playing player, else first; `artist - title`, ellipsized at 40 chars; hidden without players | **custom** |
| B4 | Voice-to-text button | Toggles `uv run ~/dotfiles/scripts/voice_to_text.py`; icon/tooltip/active class follow running state; click again terminates | **custom** |
| B5 | System tray | SNI items; left-click activate, right-click menu, tooltip | upstream |
| B6 | Keyboard layout | First 2 letters of Hyprland main keyboard keymap; click = next layout | upstream |
| B7 | Battery | Icon + % + small bar per UPower battery (none on this desktop → hidden) | upstream |
| B8 | Status pill | Indicator icons: screen recorder (blinks unless paused), voice-to-text, Wi-Fi / Ethernet (only the relevant one shown), VPN (when connected), speaker volume icon, mic (when muted), DND; clock `HH:MM`. Click toggles the control center on this monitor; pill gets `active` class while open | modified |
| B9 | Pinned apps (`Apps`) | Pinned apps + launcher button. **Defined but not placed in the bar** | upstream, unused |

### Control center (`ignis_CONTROL_CENTER`, right-side slide-in, click-outside closes)
| # | Feature | Details |
|---|---|---|
| C1 | Quick-settings grid (2 per row, expandable menus under the row) | Wi-Fi (toggle radio, scan, AP list with strength + connected tick, connect via graphical prompt, “Network Settings” → `nm-connection-editor`); Ethernet (per-device connect/disconnect); **VPN** (list NM VPN connections, toggle, label = active VPN); Bluetooth (power toggle, discovery while open, device list connect/disconnect, label = connected device / “N pairs”); DND (Silent/Noisy); Dark mode; Screen recording (menu: record audio switch + Internal/Mic/Both dropdown → start; button stops when active) |
| C2 | Volume sliders | Speaker + microphone: mute button, slider, expandable device list with default tick, “Sound Settings” → `pavucontrol` |
| C3 | Brightness | Backlight slider (hidden: no backlight on this machine) |
| C4 | User row | Avatar (`/var/lib/AccountsService/icons/$USER`), username, uptime (60 s poll), Settings button, Power button |
| C5 | Media cards | One card per MPRIS player; background = album art with colours extracted from the art (Material palette per player); player icon (Spotify/Firefox/Chrome/generic); title/artist; play/pause; seek slider; prev/next |
| C6 | Notification center | Count, “Clear all”, history list (newest first), close per notification |

### Notifications
| # | Feature | Details |
|---|---|---|
| N1 | Notification daemon | Ignis owns `org.freedesktop.Notifications`; history persisted to `~/.cache/ignis/notifications/` **with no cap** (root cause of the freezes) |
| N2 | Popups | Per monitor, top-right stack, slide-in/out animation, max popup count, popup timeout, DND suppresses popups |
| N3 | Layouts | Normal (icon/image, summary, body, close, action buttons); **grimblast** screenshot layout (image preview, “Open” via `xdg-open`, “Close”) |

### Other windows
| # | Feature | Details |
|---|---|---|
| W1 | App launcher (`ignis_LAUNCHER`) | Search desktop entries (top 5), Enter launches first, right-click menu (launch, desktop actions, pin/unpin), terminal apps via `kitty`, fallback “Visit URL” / “Search in Google” with default-browser icon. **No keybind points at it — Vicinae is used. Not ported.** |
| W2 | Music launcher (`ignis_MUSIC_LAUNCHER`, `Super+Shift+Space`) | **custom**. mpd library via `mpc`; modes All Songs / Artists / Albums / Playlists cycled with Tab / Shift-Tab; substring filter, top 20; actions: song = insert+next (fallback play last), artist = findadd+play from first added, album/playlist = clear+load+play; `notify-send` confirmation; reloads data on every open (currently **blocking**) |
| W3 | OSD (`ignis_OSD`) | Bottom overlay, speaker icon + volume bar, auto-hides after 3 s. Opened by volume keys via `goignis open-window ignis_OSD` |
| W4 | Power menu (`ignis_POWERMENU`, `Super+Shift+Alt+M`, `Alt+F4`) | Power off, Reboot, Suspend (`systemctl suspend && hyprlock`), Sign out (`hyprctl dispatch exit 0`); dimmed overlay, click-outside closes |
| W5 | Settings window (`ignis_SETTINGS`) | Pages: Notifications (DND, max popups, popup timeout), Recorder (save folder, filename pattern), Appearance (wallpaper preview, dark-mode switch, wallpaper picker → regenerate colours), User (avatar picker), About (OS logo, OS, versions, session, compositor, kernel); remembers last page. **Not ported — replaced by config.json** |

### Services / integrations
| # | Feature | Details |
|---|---|---|
| S1 | Material You theming | Python `materialyoucolor` from wallpaper → colours for SCSS + Jinja templates rendered to `~/.cache/ignis/material/{,dark_}{colors-hyprland.conf,colors-kitty.conf,gtk.css,colors.scss,swaylock}`; then `pkill -SIGUSR1 kitty`, reload GTK theme via gsettings flip, reload CSS |
| S2 | Consumers of those files | `hypr/default/colors.lua`, `hypr/hyprlock.conf`, `kitty/kitty.conf` (all read `dark_*` variants) |
| S3 | Artwall hook | `hypr/scripts/artwall.py` → `ignis run-python … generate_colors(<lock image>)` |
| S4 | Screen recorder | Ignis RecorderService (gpu-screen-recorder + portal); keybinds `Super+R/Shift+R/T/Shift+T` → `scripts/recording.py start/continue/stop/pause` |
| S5 | Startup side-effects (`config.py`) | gsettings gtk-theme `Material`, icon-theme `Papirus`, font `JetBrains Mono Regular 11`; `hyprctl reload`; monkey-patch for MPRIS art crashes |
| S6 | Hyprland glue | `exec.lua`: `sleep 1 && ignis init`; `rules.lua`: blur `ignis_BAR*`, no_anim for popups/control center |

---

## 2. Quickshell building blocks (0.3.x)

| Need | Quickshell module | Gap? |
|---|---|---|
| Layer-shell windows per monitor | `PanelWindow`, `Variants { model: Quickshell.screens }`, `WlrLayershell.namespace` | — (also fixes monitor hot-plug, which Ignis did not handle) |
| Workspaces, windows, keyboard layout, dispatch | `Quickshell.Hyprland` (`Hyprland.workspaces`, `focusedWorkspace`, `toplevels`, `rawEvent`, `dispatch()`) | layout name via `activelayout` raw event |
| Tray | `Quickshell.Services.SystemTray` + `QsMenuAnchor` | — |
| Volume / devices | `Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink/Source`, `PwObjectTracker`, `preferredDefaultAudioSink`) | — |
| MPRIS | `Quickshell.Services.Mpris` | position needs a `Timer` calling `positionChanged()` while visible |
| Notifications | `Quickshell.Services.Notifications.NotificationServer` | persistence is ours to write (good: capped) |
| Battery | `Quickshell.Services.UPower` | — |
| Wi-Fi / Ethernet | `Quickshell.Networking` | **VPN not covered** → `nmcli` |
| Bluetooth | `Quickshell.Bluetooth` | — |
| Desktop entries | `DesktopEntries` (core) | pins stored by us |
| Colour from album art | `ColorQuantizer` (core) | — |
| Processes / files / IPC | `Quickshell.Io`: `Process`, `StdioCollector`, `SplitParser`, `FileView` + `JsonAdapter`, `IpcHandler`, `Socket` | — |
| Generic D-Bus | **none** | bridge process (see S-meeting) |
| Backlight | **none** | `brightnessctl` + `FileView` on sysfs (moot on this desktop) |
| Polkit agent, idle inhibitor, screencopy, lockscreen (PAM) | available | optional extras later |

`goignis toggle-window X` becomes `qs ipc call <target> <function>`, served by `IpcHandler` objects.

---

## 3. Target layout

```
quickshell/
  shell.qml                 # ShellRoot: instantiates everything, LazyLoaders for popups
  PLAN.md
  config/
    Config.qml              # singleton: FileView+JsonAdapter → ~/.local/state/quickshell/config.json
                            #   schema in §8
  theme/
    Theme.qml               # singleton: FileView on ~/.cache/quickshell/material/colors.json (watchChanges)
    Style.qml               # radii, spacing, fonts
  services/                 # singletons, no UI
    Time.qml  Audio.qml  Media.qml  Network.qml  Vpn.qml  Bt.qml
    Notifs.qml              # NotificationServer + capped, debounced persistence
    MeetingNotes.qml        # talks to scripts/meetingnotes-bridge
    VoiceToText.qml  Recorder.qml  Mpd.qml  Material.qml  Brightness.qml
  components/               # reusable widgets
    IconButton.qml  QsToggle.qml  ExpandMenu.qml  MaterialSlider.qml
    NotificationCard.qml  PopupLayer.qml  ListRow.qml
  modules/
    bar/        Bar.qml Workspaces.qml MeetingRecordButton.qml NowPlaying.qml
                VoiceToTextButton.qml Tray.qml KbLayout.qml Battery.qml StatusPill.qml
    controlcenter/ ControlCenter.qml QuickSettings.qml qs/*.qml VolumeSlider.qml
                Brightness.qml UserRow.qml MediaCard.qml NotificationCenter.qml
    notifications/ Popups.qml
    musiclauncher/ MusicLauncher.qml
    osd/        Osd.qml
    powermenu/  PowerMenu.qml
  scripts/
    meetingnotes-bridge.py  # gi/Gio: JSON lines out, commands in
    material.py             # wallpaper → colors.json + templates (your existing generator)
  templates/                # colors-hyprland.conf, colors-kitty.conf, gtk.css, swaylock
```

Extension pattern (replaces “add a Python module”): new data source = a singleton in
`services/`; new widget = a QML file in the relevant `modules/` folder that binds to
it; new keybind entry point = an `IpcHandler` in that module.

### Efficiency rules (the reason for the move)
1. **Never block**: all shell commands are `Process` objects; no synchronous reads of
   large files on startup.
2. **Bounded state**: notification history capped (default 200), persisted with a
   debounced (≥1 s) write of ≤ cap entries; `transient` / agent-manager spam not stored.
3. **Lazy UI**: control center, music launcher, power menu are `LazyLoader`s,
   created on first open, and `ListView`s (virtualised) for any list that can grow.
4. **Timers only when visible**: MPRIS position, uptime, elapsed-timer ticks run only
   while their widget is shown.

---

## 4. Feature → implementation mapping

| Ignis | Quickshell implementation |
|---|---|
| B1 Workspaces | `Repeater` over `Hyprland.workspaces` sorted by id (skip negative/special); label from hotkey map; `focused` → active; `WheelHandler` → `Hyprland.dispatch("workspace e±1")` with the ≤10 guard |
| B2 Meeting button | `MeetingNotes` singleton runs `scripts/meetingnotes-bridge.py` as a long-lived `Process`. Bridge (Python + Gio, out-of-process so it can never stall the UI) watches the bus name + properties + signals and prints one JSON object per change; reads `{"call":"StopRecording","args":[true]}` lines on stdin. QML keeps `available/isRecording/pickerActive/isManual/title/startTime/lastError` properties, same state machine and CSS-class equivalents as states. Menu = `PopupWindow` built from `Hyprland.toplevels` (`[ws] class — title`, max 12). Elapsed timer `Timer` only while recording. Bridge auto-restarts (`Process.running` rebinding) if it exits |
| B3 Now playing | `Media` singleton: `activePlayer` = first `Mpris.players` with `isPlaying`, else first; label binds `trackArtist`/`trackTitle`, `elide: Text.ElideRight` at ~40ch |
| B4 Voice-to-text | `VoiceToText` singleton: `Process { command: ["uv","run",".../voice_to_text.py"] }`; `running` drives icon/active state; toggle = `running = !running` (stop sends SIGTERM); `IpcHandler { target: "voice" }` so `Super+G` can call it and the bar stays in sync (today the keybind bypasses Ignis and the bar never shows it) |
| B5 Tray | `Repeater` over `SystemTray.items`; `IconImage { source: modelData.icon }`; left `activate()`, right `QsMenuAnchor { menu: modelData.menu }.open()`; tooltip |
| B6 Kb layout | `Hyprland.rawEvent` filter `activelayout` → store layout name; initial value via `Process ["hyprctl","-j","devices"]`; click → `Hyprland.dispatch("switchxkblayout main next")` |
| B7 Battery | `UPower.displayDevice`; `visible: isLaptopBattery`; icon by percentage/state |
| B8 Status pill | `Row` of conditional icons bound to `Recorder.active/paused`, `VoiceToText.running`, `Network` (wifi vs wired logic ported 1:1), `Vpn.connected`, `Audio.sink.audio.volume/muted`, `Audio.source.audio.muted`, `Config.dnd`; clock from `Time` singleton (`SystemClock { precision: SystemClock.Minutes }`, no 1 s poll). Click → `ControlCenter.toggle(screen)` |
| B9 Pinned apps | **Dropped** |
| C1 Quick settings | `QsToggle` component (icon, label, active, optional `ExpandMenu`). Wi-Fi: `Quickshell.Networking` device `networks`, `scan`, connect; password prompt via `nmcli dev wifi connect … --ask` in a small `TextField` dialog. Ethernet: wired devices connect/disconnect. **VPN**: `Vpn` singleton = `nmcli -t -f NAME,TYPE,ACTIVE con show` on start + long-lived `nmcli monitor` Process to refresh; toggle with `nmcli con up/down id <name>`. Bluetooth: `Bluetooth.defaultAdapter.enabled/discovering`, `devices` with `connect()/disconnect()`. DND/Dark mode: `Config` props. Record: menu with audio switch + `ComboBox` → `Recorder.start(audio)` |
| C2 Volume | `MaterialSlider` bound to `Pipewire.defaultAudioSink.audio.volume` (and source); device list = `Pipewire.nodes` filtered `isSink`/`!isStream`, click sets `Pipewire.preferredDefaultAudioSink`; `PwObjectTracker` on defaults; “Sound Settings” → `pavucontrol` |
| C3 Brightness | `Brightness` singleton: `visible` only if `/sys/class/backlight/*` exists (check via `Process ls`); set via `brightnessctl s N` (debounced) |
| C4 User row | Avatar `Image` from `Config.avatar` with fallback icon; `$USER` via `Quickshell.env("USER")`; uptime from `FileView /proc/uptime` reloaded every 60 s while open; buttons open Settings / PowerMenu |
| C5 Media cards | `Repeater` over `Mpris.players`; background `Image { source: trackArtUrl }` + gradient; `ColorQuantizer { source: trackArtUrl; depth: 2 }` → accent colours per card (replaces per-player SCSS generation); player icon from `desktopEntry`/`identity`; seek `Slider` bound to `position/length`, `Timer` → `positionChanged()` only while visible; `canGoNext/canGoPrevious/canPlay` visibility |
| C6 Notification center | `ListView` over `Notifs.history` (newest first), count label, Clear all |
| N1 Daemon | `Notifs` singleton: `NotificationServer { keepOnReload: true; imageSupported; actionsSupported; bodyMarkupSupported; persistenceSupported }`. `onNotification`: `n.tracked = true`, append to history model; if `history.length > Config.historyCap` drop oldest. Persistence: `FileView` + `JsonAdapter` at `~/.local/state/quickshell/notifications.json` (summary/body/app/icon/time/urgency only — no image blobs), write via 1 s debounce `Timer`. Rules list (e.g. `appName === "agent-manager"` → popup only, never history) |
| N2 Popups | One `PanelWindow` per screen (top-right, `exclusionMode: Ignore`, mask = content), `ListView` of active popups with add/remove `Transition`s; `Timer` per popup = `Config.popupTimeout` (respect `expireTimeout` if set); `maxPopups` drops oldest; DND suppresses popups but still records |
| N3 Layouts | `NotificationCard` with `Loader` switching on `appName === "grimblast"` → screenshot layout (`Image` of `image`/icon path, Open → `xdg-open`) |
| W1 Launcher | **Dropped** — Vicinae is used instead |
| W2 Music launcher | `Mpd` singleton: four `Process` + `StdioCollector`s (`mpc listall`, `list artist`, `list album`, `lsplaylists`) refreshed **asynchronously** on open (results reused until done); mode bar with Tab/Shift-Tab via `Keys.onTabPressed/onBacktabPressed`; JS substring filter, top 20, `ListView`; same `mpc` command strings as today run via `Process`/`execDetached`; `IpcHandler { target: "music" }` |
| W3 OSD | Bottom `PanelWindow` (`WlrLayer.Overlay`); shows automatically on `Pipewire.defaultAudioSink.audio` volume/mute change (keys no longer need to call the shell), hides via 3 s restart-able `Timer`; also `IpcHandler { target: "osd"; function show() }` for compatibility |
| W4 Power menu | Full-screen `PanelWindow` with dim background, 4 buttons → `Quickshell.execDetached([...])`; Esc closes; `IpcHandler { target: "power" }` |
| W5 Settings | **Replaced by `config.json`** (§8), hot-reloaded by `Config` via `FileView { watchChanges: true }`. Wallpaper → colours: `qs ipc call theme generate <path>`. The control-center Settings button opens `config.json` in `$EDITOR` (kitty) |
| S1 Theming | `scripts/material.py` (keeps your existing `materialyoucolor` logic + Jinja templates, run as a `Process`, never in-process) writes `~/.cache/quickshell/material/colors.json` and the same template outputs; `Theme` singleton watches the JSON with `FileView { watchChanges: true }` so colours hot-swap with no CSS recompilation. Then kitty `SIGUSR1` + gsettings GTK flip as today. |
| S2 Consumers | Phase 1 writes to **both** `~/.cache/ignis/material/` and `~/.cache/quickshell/material/` so hyprland/hyprlock/kitty keep working; final phase repoints `colors.lua`, `hyprlock.conf`, `kitty.conf` and drops the old path |
| S3 Artwall | `sync_ignis_colors` → `qs ipc call theme generate <path>` |
| S4 Recorder | `Recorder` singleton wrapping `gpu-screen-recorder -w portal -f 60 -a <audio> -o <dir>/<strftime name>.mp4` as a `Process`; pause/continue = `SIGUSR2`, stop = `SIGINT` (`Process.signal()`); `IpcHandler { target: "recorder"; start/stop/pause/continue }`; keybinds call `qs ipc call recorder start` etc.; notify on save |
| S5 Startup side-effects | Move gsettings lines into `hypr/default/exec.lua` (they don't belong to the bar); drop `hyprctl reload`; drop MPRIS monkey-patch |
| S6 Hyprland glue | `exec.lua`: `qs` (no sleep needed); `rules.lua`: namespaces `quickshell:bar*` blur, `quickshell:notifications*` / `quickshell:controlcenter` no_anim; keybinds `goignis …` → `qs ipc call …` |

---

## 5. Phases

Each phase ends with something usable. Ignis keeps running until phase 4.

**Phase 0 – Setup (30 min)**
- `pacman -S quickshell`; `ln -s ~/dotfiles/quickshell ~/.config/quickshell`.
- `shell.qml` skeleton, `Config`, `Theme` (read existing Ignis colour JSON once to bootstrap), `Time`.
- Develop with `qs -p ~/dotfiles/quickshell` alongside Ignis; Ignis still owns the
  notification bus name and SNI watcher, so `Notifs` and `Tray` are behind a
  `Config.ownDaemons` flag that stays `false` until cutover.

**Phase 1 – Bar core**
B1 workspaces, B3 now-playing, B6 kb layout, B7 battery, B8 status pill (all indicators
except recorder/voice), clock. Per-monitor `Variants`. Disable Ignis bar
(comment `Bar(monitor)` in `config.py`) and run the Quickshell bar daily.

**Phase 2 – Custom bar features**
B2 meeting-record button + `meetingnotes-bridge.py`, B4 voice-to-text with IPC, S4
recorder service + IPC + keybind changes, recorder/voice indicators in the pill.

**Phase 3 – Overlays**
W3 OSD (auto on volume change), W4 power menu, W2 music launcher (async).
Swap the corresponding keybinds; remove those windows from Ignis.

**Phase 4 – Notifications + tray (cutover)**
N1–N3 and B5 tray. Stop Ignis (`exec.lua` no longer starts it), flip `ownDaemons`.
From here Ignis is gone except for theming.

**Phase 5 – Control center**
C1–C6 (Wi-Fi, Ethernet, VPN via nmcli, Bluetooth, DND, dark mode, record menu, volume
+ device menus, brightness, user row, media cards, notification center).

**Phase 6 – Theming + cleanup**
S1 `material.py` + `IpcHandler { target: "theme" }`; S3 artwall;
S2 repoint hyprland/hyprlock/kitty; S5/S6 cleanup; delete `~/.config/ignis` symlink
(keep `~/dotfiles/ignis` in git history).

**Verification per phase**: `qs log` clean; RSS and CPU sampled after 1 h
(`ps -o rss,%cpu -C qs`) — target < 250 MB, ~0 % idle; fire 1,000 test
notifications (`for i in $(seq 1000); do notify-send t $i; done`) and confirm the
history stays at the cap and the UI stays responsive.

---

## 6. Risks / notes
- **Quickshell API churn**: still pre-1.0; pin the version in `pacman.conf` `IgnorePkg`
  or re-test after upgrades.
- **No generic D-Bus in QML**: the meeting-notes bridge is the one piece of Python
  that stays; it's isolated in its own process so it can't freeze the shell.
- **VPN** isn't in `Quickshell.Networking` yet → `nmcli`; revisit if a later release adds it.
- **Wi-Fi password entry**: Ignis used NM's graphical agent; we need a small prompt
  or rely on `nm-applet`/polkit agent. Quickshell's `Services.Polkit` could also replace
  whatever polkit agent you run today.
- **Notification spam source**: agent-manager sent ~79k “Errored” notifications;
  worth fixing at the source as well as capping here.

## 7. Decisions (2026-10-09)
1. **App launcher (W1): dropped.** Vicinae (`Super+Space` in `keybinds.lua`) is the launcher.
2. **Pinned apps (B9): dropped.**
3. **Settings window (W5): replaced by `config.json`** (see §8). No GUI.
4. **Theming: keep the existing Python `materialyoucolor` pipeline** (moved to
   `scripts/material.py`), so colours look identical. matugen not adopted.

## 8. `config.json`

Path: `~/dotfiles/quickshell/config.json` (in git, so it travels with the dotfiles).
Edits apply live; unknown or missing keys fall back to the defaults in `Config.qml`.
Runtime toggles from the UI (DND, dark mode) write back to the same file.

```json
{
  "notifications": {
    "dnd": false,
    "popupTimeoutMs": 5000,
    "maxPopups": 3,
    "historyCap": 200,
    "noHistoryApps": ["agent-manager"]
  },
  "appearance": {
    "darkMode": true,
    "wallpaper": "/home/tyler/Pictures/Wallpaper/..."
  },
  "user": {
    "avatar": "/var/lib/AccountsService/icons/tyler"
  },
  "recorder": {
    "directory": "~/Videos",
    "filename": "%Y-%m-%d_%H-%M-%S",
    "fps": 60
  },
  "bar": {
    "workspaceLabels": {"10": "0", "11": "O", "12": "C", "13": "N", "14": "M", "15": "T"},
    "maxScrollWorkspace": 10,
    "nowPlayingMaxChars": 40
  },
  "meetingNotes": {
    "webUrl": "http://127.0.0.1:8636",
    "maxMenuWindows": 12
  },
  "voiceToText": {
    "command": ["uv", "run", "/home/tyler/dotfiles/scripts/voice_to_text.py"]
  },
  "apps": {
    "terminal": "kitty",
    "soundSettings": "pavucontrol",
    "networkSettings": "nm-connection-editor"
  }
}
```

The About page is dropped (it was informational only); `qs --version` / `fastfetch` cover it.

## 9. Status

- **2026-10-09** – Phase 0 + Phase 1 written (`shell.qml`, `config/`, `theme/`,
  `services/{Time,Media,Audio,Net,Vpn}`, `components/`, `modules/bar/`). Symlinked
  `~/.config/quickshell -> ~/dotfiles/quickshell`. Not yet run: the `quickshell`
  package needs Qt 6.12 and the system was on 6.11.2 (partial upgrade) — needs
  `sudo pacman -Syu`. Theme reads Ignis's `user_options.json` live until phase 6.
  Pill click (control center) and tray tooltips come in later phases.
- Hyprland runs a Lua config: dispatchers are Lua (`hl.dsp.focus({ workspace = N })`);
  Ignis's `hyprctl dispatch exit 0` sign-out is already broken → use `hl.dsp.exit()`.
- **2026-10-09** – Phase 1 running (after `pacman -Syu`). Ignis bar disabled in
  `ignis/config.py` and Ignis's tray made lazy (`modules/bar/widgets/tray.py`), so
  Quickshell owns `org.kde.StatusNotifierWatcher` (Ignis's watcher dropped item object
  paths, hiding most icons from other hosts). Gotcha: QML properties can't be named
  `on<Upper>…` (read as signal handlers) → Material `on*` colours are `Theme.fg*`.
- **2026-10-09** – Phase 2 written: `scripts/meetingnotes-bridge.py` +
  `services/MeetingNotes`, `modules/bar/MeetingButton` (menu via `components/PopupMenu`,
  `components/Tooltip`), `services/VoiceToText` (IPC `voice`), `modules/bar/VoiceButton`,
  `services/Recorder` (IPC `recorder`), recorder/voice blink indicators in the pill.
  Keybinds `Super+R/Shift+R/T/Shift+T/G` now call `qs ipc call …`. `qs ipc` only finds
  an instance started as plain `qs` (not `qs -p ~/dotfiles/quickshell`).
- **2026-10-09** – Dropped B4 voice-to-text (user uses the Handy app) and the
  `Super+R/Shift+R/T/Shift+T/G` keybinds. `services/Recorder` stays only for the
  control-center Record toggle (phase 5).
- **2026-10-10** – Phase 4 (notifications) done ahead of phase 3: `services/Notifs`
  (NotificationServer, history capped + 1 s debounced save to
  `Quickshell.statePath("notifications.json")`, keys `instanceId:id` so hot reloads
  don't duplicate resent notifications), `components/NotificationCard` (normal +
  grimblast layouts), `modules/notifications/Popups` (every screen, hover pauses,
  critical stays). IPC `notifs`: toggleDnd/setDnd/clear/count. DND lives in
  `config.json` (carried over as on). Ignis no longer creates its NotificationService
  (popups, notification center, DND toggle removed). `exec.lua` now starts `qs`;
  Ignis kept running for OSD / power menu / music launcher / control center until
  phases 3 and 5 — so it is **not** stopped yet.
- **2026-10-10** – Phase 5 (control center) done: `modules/controlcenter/` (QuickSettings
  with Wi-Fi / Wired / VPN / Bluetooth / DND / Dark / Record + drop-down menus,
  VolumeRow ×2 with device pickers, UserRow, MediaCard per player, NotificationCenter),
  shared components (Toggle, Switch, Slider, Expander, MenuRow, MenuHeader,
  PasswordField, Separator). Opened from the pill or `qs ipc call controlcenter toggle`.
  Windows are created by `ControlCenterLoader` (LazyLoader) only while open — hidden
  windows cost ~70 MB. Dark toggle still asks Ignis to regenerate colours
  (`services/ThemeControl`) until phase 6; power button opens the Ignis power menu
  until phase 3. No brightness slider (no backlight on this machine). Ignis no longer
  creates its control center.
- Memory: qs ≈ 310 MB idle / ≈ 375 MB after first control-center open (stable across
  opens); ~50 MB is NVIDIA driver mappings. Qt software renderer saves ~150 MB but
  breaks MultiEffect icon recolouring — not used.
- **2026-10-10** – Phase 3 done: `modules/overlays/` — Osd (bottom of focused screen,
  3 s), PowerMenu (dimmed, 2×2, arrows/Tab/Enter/Esc; Sign out = `hl.dsp.exit()`),
  MusicLauncher (async `services/Mpd`, Tab modes, Up/Down/Enter, same mpc commands),
  all LazyLoaded on the focused screen via `services/Panels`. IPC: `osd popup` (not
  `show` — collides with the `qs ipc show` subcommand), `power toggle`, `music toggle`.
  Volume keys call `osd popup` explicitly (no auto-show, so the F9 Handy volume dip
  stays silent). Ignis now has no windows: it only runs MaterialService for colour
  generation (phase 6).
- **2026-10-10** – Phase 6 done; **Ignis no longer runs.** `scripts/material.py`
  (ported MaterialService; verified identical output) writes
  `~/.cache/quickshell/material/{colors.json,colors-hyprland.conf,colors-kitty.conf}`
  and reloads kitty + Hyprland. Seeded from Ignis's palette (byte-identical files), so
  nothing changed visually; `source` is empty until `qs ipc call theme generate <img>`
  is run, so the Dark toggle reports "no source image" until then. Only the hyprland
  and kitty templates were ported (gtk.css / colors.scss / swaylock had no consumers;
  the `Material` GTK theme isn't installed). Repointed `hypr/default/colors.lua`,
  `hypr/hyprlock.conf`, `kitty/kitty.conf`; artwall's hook is now `SYNC_COLORS`
  (still off) → `qs ipc call theme generate`. `exec.lua`: no `ignis init`; gsettings
  icon theme + font moved there. Pre-existing: `hyprland.lua` sets `active_border`
  after requiring `default/colors`, overriding the Material border colour.
- **Dashboard (2026-10-14)**: Caelestia-style drop-down under the bar centre
  (`modules/dashboard/`), tabs Dashboard (user/uptime, clock, calendar, CPU/mem/disk
  rings, now playing) · Media (cover, seek, shuffle/loop, player picker) ·
  Performance (CPU/GPU with graphs, memory, storage, network). Opens on hovering
  the bar centre (200 ms delay), closes when the pointer leaves; click or
  `qs ipc call dashboard toggle|tab N` pins it. `SysStats` polls /proc, df and
  nvidia-smi every 2 s only while open. No weather tab, lyrics or visualiser.
  CPU temp needs a CPU hwmon (k10temp is blacklisted by zenpower3-dkms here).
