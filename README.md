# u-da-real-ricing

the looks half of my setup: a warm, flat retro palette i call **retro clean**, on debian 13 + hyprland. the functional half (keybinds, shell, packages) is in [dotfiles](https://github.com/Shrxmy/dotfiles), and it works fine without this repo. this just makes it pretty.

## what's in here

- **hyprland looks** (`hypr/look.lua`): square corners, thin borders, blur, animations, and glass for terminals + spotify. dotfiles' `hyprland.lua` loads it if it's there
- **wallpapers**: `super + w` opens a little carousel, and switching does a circle reveal from the center. the border, bar, launcher and cava pick up an accent color from whatever wallpaper you choose (`accent.py`)
  - built on quickshell, kept lean: the wallpaper process sits at ~70 MB and 0% cpu when idle, and the picker only exists while it's open
- **bar**: waybar with a cat that runs faster when the cpu is busy and naps when it's idle
- **colors** for fuzzel, dunst, alacritty, konsole, eza, cava
- **spotify**: a spicetify theme to match
- **shell flair**: oh-my-posh prompt, fastfetch with a pixel kirby

## install

```bash
# packages first (see packages.txt)
sudo apt install -t trixie-backports quickshell
sudo apt install imagemagick python3 waybar fuzzel dunst hyprlock cava fastfetch

./install.sh --dry-run   # see what it'll do first
./install.sh
```

anything already there gets backed up to `~/.ricing-backups/` instead of overwritten (unless you pass `--force`). wallpapers go in `~/Pictures/Wallpapers`.

for spotify: `spicetify config current_theme Retro color_scheme base && spicetify backup apply`

## credits

the bar cat uses the font from [waycat](https://github.com/CarloCattano/waycat). it's downloaded on install, not included here.
