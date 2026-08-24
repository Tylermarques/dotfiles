local primary = "rgb(ffb2bc)"
local colorFile = io.open(os.getenv("HOME") .. "/.cache/ignis/material/dark_colors-hyprland.conf", "r")

if colorFile then
    local contents = colorFile:read("*a")
    colorFile:close()
    primary = contents:match("%$primary%s*=%s*(rgb%([%x]+%))") or primary
end

hl.config({
    general = {
        col = {
            active_border = primary,
            inactive_border = "rgb(000000)",
        },
    },
})
