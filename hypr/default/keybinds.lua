local terminal = "alacritty"
local fileManager = "thunar"
local menu = "vicinae toggle"
local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + SHIFT + L", hl.dsp.exit())
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))

hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/keep-windows-onscreen.py --once"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind("F11", hl.dsp.window.fullscreen())

hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("goignis toggle-window ignis_MUSIC_LAUNCHER"))
hl.bind(mainMod .. " + SHIFT + ALT + M", hl.dsp.exec_cmd("goignis toggle-window ignis_POWERMENU"))
hl.bind("ALT + F4", hl.dsp.exec_cmd("goignis toggle-window ignis_POWERMENU"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/ignis/scripts/recording.py start"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/ignis/scripts/recording.py continue"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/ignis/scripts/recording.py stop"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/ignis/scripts/recording.py pause"))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("GRIMBLAST_HIDE_CURSOR=0 grimblast --notify --freeze copysave area"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("GRIMBLAST_HIDE_CURSOR=0 grimblast --notify --freeze copysave output"))
hl.bind("PRINT", hl.dsp.exec_cmd("GRIMBLAST_HIDE_CURSOR=0 grimblast --notify --freeze copysave output"))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "d" }))

local workspaceKeys = {
    ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5,
    ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 10,
    O = 11, C = 12, N = 13, M = 14, T = 15, D = 16,
}

for key, workspace in pairs(workspaceKeys) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5 && goignis open-window ignis_OSD"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5 && goignis open-window ignis_OSD"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t && goignis open-window ignis_OSD"))

hl.bind(mainMod .. " + minus", hl.dsp.exec_cmd("/home/tyler/dotfiles/scripts/cycle_audio.sh"))
hl.bind(mainMod .. " + apostrophe", hl.dsp.exec_cmd("/home/tyler/dotfiles/scripts/toggle-airpods-bt-con.sh"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("/home/tyler/.local/bin/uv run /home/tyler/dotfiles/scripts/voice_to_text.py"))

hl.bind("F9", hl.dsp.exec_cmd("pamixer --get-volume > /tmp/.handy-vol && pamixer --set-volume 15 && pkill -USR2 -n handy"))
hl.bind("F9", hl.dsp.exec_cmd("pamixer --set-volume $(cat /tmp/.handy-vol) && pkill -USR2 -n handy"), { release = true })
hl.bind("F10", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1"))
hl.bind("F10", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0"), { release = true })

hl.bind("F6", hl.dsp.exec_cmd("~/dotfiles/hypr/scripts/aside_continue.sh"))
hl.bind("F7", hl.dsp.exec_cmd("aside query --mic"))
