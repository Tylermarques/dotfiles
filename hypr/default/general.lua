hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
    input = {
        kb_layout = "",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:win_space_toggle",
        kb_rules = "",
        accel_profile = "flat",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
        sensitivity = 0,
    },
    general = {
        gaps_in = 5,
        gaps_out = 20,
        border_size = 2,
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 15,
        blur = {
            enabled = true,
            size = 12,
            passes = 4,
            new_optimizations = true,
        },
        shadow = {
            enabled = true,
            range = 30,
            render_power = 4,
            color = "rgb(000000)",
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        enable_anr_dialog = false,
    },
})

hl.curve("quart", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "quart", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "quart" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 6, bezier = "quart" })
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "quart" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "quart" })
