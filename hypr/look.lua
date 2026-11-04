-- u-da-real-ricing: Hyprland looks. Loaded (optionally) by the functional hyprland.lua in dotfiles,
-- which runs whatever this file returns in `autostart` once at login.
-- Retro Clean, flat & sharp
-- amber #cc9166  sand #d9ac8c  text #c6c0b9  muted #8a8a8a  subtle #4d4d4d
-- mauve #b894af  sage #778c73  rose #a97070  slate #8a99a8  base #25222a

-- active border follows the wallpaper accent (written by wallpaper.sh); amber until one is picked
local accent = "cc9166"
local accent_file = io.open(os.getenv("HOME") .. "/.local/state/wallpaper/accent")
if accent_file then
    accent = (accent_file:read("l") or ""):match("^%x%x%x%x%x%x") or accent
    accent_file:close()
end

hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border   = "rgb(" .. accent .. ")",
            inactive_border = "rgb(3d3d40)",
        },
    },
    decoration = {
        rounding = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_inactive = true,   -- unfocused windows sit back a little
        dim_strength = 0.12,
        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 10,
            color        = 0xee141216,
        },
        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0.17,
        },
    },
    animations = { enabled = true },
    misc = { background_color = 0xff25222a },
})

hl.curve("smooth",    { type = "bezier", points = { {0.22, 1},   {0.1, 1.1} } })
hl.curve("quick",     { type = "bezier", points = { {0.15, 0.85}, {0.25, 1.0} } })
hl.curve("linearish", { type = "bezier", points = { {0.3, 0.0},  {0.7, 1.0} } })

hl.animation({ leaf = "windows",          enabled = true, speed = 4, bezier = "smooth",    style = "popin 95%" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4, bezier = "smooth",    style = "popin 85%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3, bezier = "quick",     style = "popin 90%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 3, bezier = "quick" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "smooth",    style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "smooth",    style = "slidefadevert 5%" })
hl.animation({ leaf = "layers",           enabled = true, speed = 3, bezier = "quick",     style = "fade" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3, bezier = "quick",     style = "popin 95%" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 3, bezier = "quick",     style = "popin 95%" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 3, bezier = "linearish" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 3, bezier = "linearish" })
hl.animation({ leaf = "fade",             enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "border",           enabled = true, speed = 5, bezier = "quick" })

-- wallpaper carousel (Quickshell)
hl.bind("SUPER + W", hl.dsp.exec_cmd("~/.config/hypr/wallpaper.sh"))

hl.window_rule({
    name  = "terminal-glass", -- let the blurred wallpaper show through terminals
    match = { class = "^(Alacritty|org.kde.konsole)$" },
    opacity = "0.88 0.80",
})
hl.window_rule({
    name  = "spotify-glass", -- same blurred-wallpaper look, a bit more solid so album art stays readable
    match = { class = "^(Spotify|spotify)$" },
    opacity = "0.92 0.85",
})

return {
    autostart = { "~/.config/hypr/wallpaper.sh restore" }, -- resident Quickshell wallpaper
}
