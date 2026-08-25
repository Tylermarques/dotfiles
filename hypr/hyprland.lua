require("default/colors")
require("default/monitors")
require("default/env")
require("default/exec")
require("default/general")
require("default/rules")
require("default/keybinds")

hl.config({
    debug = {
        -- Used to fix gamescope support.
        full_cm_proto = true,
    },
    general = {
        gaps_in = 2,
        gaps_out = 5,
        border_size = 1,
        col = {
            active_border = {
                colors = { "rgba(33ccffee)", "rgba(00ff99ee)" },
                angle = 45,
            },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = false,
    },
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = false })
hl.animation({ leaf = "workspacesOut", enabled = false })

hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE DISPLAY && systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")
    hl.exec_cmd("hyprlock --immediate")
    -- XWayland can place dialogs in invisible gaps in a non-rectangular monitor layout.
    hl.exec_cmd("~/.config/hypr/scripts/keep-windows-onscreen.py")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-cycle.sh")
    hl.exec_cmd("firefox", { workspace = "1" })
    hl.exec_cmd("spotify", { workspace = "2" })
    hl.exec_cmd("todoist", { workspace = "15" })
    hl.exec_cmd("alacritty", { workspace = "4" })
    hl.exec_cmd("slack", { workspace = "3" })
    hl.exec_cmd("vesktop", { workspace = "16" })
    hl.exec_cmd("hypridle")
    hl.exec_cmd("udiskie")
    hl.exec_cmd("obsidian", { workspace = "13" })
    hl.exec_cmd("librepods")
    hl.exec_cmd("~/.config/hypr/scripts/start-mail.sh")
    hl.exec_cmd("obs --startvirtualcam", { workspace = "6" })
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

local mainMod = "SUPER"

hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd("~/.config/hypr/scripts/open-meet.sh"))
hl.bind(mainMod .. " + G", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"))

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

for workspace, monitor in pairs({
    ["1"] = "DP-3",
    ["2"] = "DP-3",
    ["3"] = "DP-3",
    ["4"] = "DP-3",
    ["5"] = "DP-3",
    ["6"] = "HDMI-A-1",
    ["12"] = "HDMI-A-1",
    ["13"] = "DP-3",
    ["15"] = "DP-3",
    ["16"] = "DP-3",
}) do
    hl.workspace_rule({ workspace = workspace, monitor = monitor })
end

for class, workspace in pairs({
    Rhythmbox = "2",
    Spotify = "2",
    slack = "3",
    ["eu.betterbird.Betterbird"] = "12",
    ["com.obsproject.Studio"] = "6",
    chrome = "12",
    ["md.Obsidian"] = "13",
    todoist = "15",
    vesktop = "16",
}) do
    hl.window_rule({ match = { class = class }, workspace = workspace })
end
