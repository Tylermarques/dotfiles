hl.window_rule({
    match = { class = "pavucontrol" },
    float = true,
    pin = true,
    size = { 900, 500 },
})

-- Float Thunar file operation progress windows.
hl.window_rule({ match = { class = "thunar", title = "^(File Operation Progress)$" }, float = true })
hl.window_rule({ match = { class = "^(Material Settings)$" }, float = true })

hl.layer_rule({ match = { namespace = "^(ignis_BAR.*)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(ignis_NOTIFICATION_POPUP.*)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(ignis_CONTROL_CENTER.*)$" }, no_anim = true })

hl.layer_rule({ match = { namespace = "vicinae" }, blur = true, ignore_alpha = 0, no_anim = true })
