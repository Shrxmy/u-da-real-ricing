#!/usr/bin/env bash
# Wallpaper picker for Hyprland, with accent colors taken from the wallpaper.
#   wallpaper.sh           carousel picker (Quickshell): arrows/wheel browse, Enter applies, Esc closes
#   wallpaper.sh set FILE  apply FILE and recolor the accents
#   wallpaper.sh restore   start the wallpaper process with the saved wallpaper and accents (run at login)
set -euo pipefail

dir="$HOME/Pictures/Wallpapers"
state="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
current="$state/current" # symlink; hyprlock reads it too
default="$dir/Space Wide.jpg"
here="$(dirname "$(readlink -f "$0")")"

# Resident Quickshell wallpaper (quickshell/wallpaper) draws and animates the change.
# Mesa EGL keeps the NVIDIA GPU asleep; jemalloc decay returns freed memory (measured ~100 -> ~69 MB).
lean_qs() { # qs ARGS... on the Intel GPU with lean memory settings
  local mesa=/usr/share/glvnd/egl_vendor.d/50_mesa.json
  [ -f "$mesa" ] || mesa=""
  env ${mesa:+__EGL_VENDOR_LIBRARY_FILENAMES=$mesa} \
    MALLOC_CONF=narenas:1,tcache:false,dirty_decay_ms:0,muzzy_decay_ms:0,background_thread:false \
    qs "$@"
}

start_wallpaper() {
  lean_qs -c wallpaper -n -d >/dev/null 2>&1 9>&- || true # -n: no-op if already running
}

apply() {
  # Not running yet: start it; it shows the saved symlink on its own.
  qs -c wallpaper ipc call wallpaper set "$1" >/dev/null 2>&1 || start_wallpaper
}

# One switch at a time: overlapping runs finished out of order (wallpaper and accent mismatched).
lock() {
  mkdir -p "$state"
  exec 9>"$state/lock"
  flock 9
}

save() {
  mkdir -p "$state"
  ln -sfn "$1" "$current"
}

# Generated files the apps read: Waybar CSS import, Fuzzel include, Hyprland border (hyprland.lua).
write_accent() { # ACCENT SAND (hex, no '#')
  mkdir -p "$state"
  echo "$1 $2" >"$state/accent"
  printf '@define-color amber #%s;\n@define-color sand #%s;\n' "$1" "$2" >"$state/accent.css"
  printf '[colors]\nprompt=%sff\ninput=%sff\nmatch=%sff\nselection-text=%sff\nselection-match=%sff\nborder=%sff\n' \
    "$1" "$2" "$1" "$2" "$1" "$1" >"$state/fuzzel.ini"
}

# Live recolor; each app may not be running, so none of this is fatal.
push_accent() { # ACCENT SAND
  hyprctl eval "hl.config({ general = { col = { active_border = \"rgb($1)\" } } })" >/dev/null 2>&1 || true
  # Waybar reloads its style itself (reload_style_on_change); SIGUSR2 rebuilt the bar and could kill it.
  local cava="$HOME/.config/cava/config"
  if [ -f "$cava" ]; then
    sed -i -e "s/^gradient_color_4 = .*/gradient_color_4 = '#$1'/" \
      -e "s/^gradient_color_5 = .*/gradient_color_5 = '#$2'/" "$cava"
    pkill -USR1 -x cava || true # reload config
  fi
}

case "${1:-}" in
  set)
    img=$(readlink -f "${2:?usage: wallpaper.sh set FILE}")
    [ -f "$img" ] || exit 1
    lock
    save "$img"
    apply "$img"
    # shellcheck disable=SC2046 # two hex words
    set -- $(python3 -I "$here/accent.py" "$img")
    write_accent "$1" "$2"
    push_accent "$1" "$2"
    ;;
  restore)
    lock
    img=$(readlink -f "$current" 2>/dev/null || true)
    [ -f "$img" ] || { img=$default; save "$img"; }
    apply "$img"
    read -r accent sand 2>/dev/null <"$state/accent" || { accent=cc9166; sand=d9ac8c; }
    # always: Fuzzel won't start if its include is missing. No push_accent: at login Waybar is
    # still starting and SIGUSR2 before its handler is installed kills it; apps read the files at start.
    write_accent "$accent" "$sand"
    ;;
  "")
    mapfile -t files < <(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
    [ "${#files[@]}" -gt 0 ] || exit 0
    # Small cached thumbnails so the picker never decodes full-size images; rebuilt only when stale.
    thumbs="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"
    mkdir -p "$thumbs"
    for f in "${files[@]}"; do
      t="$thumbs/$(basename "$f").jpg"
      [ "$t" -nt "$f" ] || magick -define jpeg:size=960x540 "$f[0]" -thumbnail 480x270^ \
        -gravity center -extent 480x270 -quality 85 "$t" || true
    done
    read -r accent _ 2>/dev/null <"$state/accent" || accent=cc9166
    WALLPICKER_FILES=$(printf '%s\n' "${files[@]}") \
      WALLPICKER_CURRENT=$(readlink -f "$current" 2>/dev/null || true) \
      WALLPICKER_THUMBS=$thumbs WALLPICKER_ACCENT=$accent WALLPICKER_SET="$here/wallpaper.sh" \
      lean_qs -c wallpicker -n # -n: Super+W while open doesn't stack a second picker
    ;;
  *)
    echo "usage: wallpaper.sh [set FILE | restore]" >&2
    exit 2
    ;;
esac
