#!/usr/bin/env bash
set -euo pipefail

RICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.ricing-backups/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
FORCE=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run   Show planned actions without changing files
  --force     Overwrite existing files/symlinks without backup
  -h, --help  Show this help

Links the u-da-real-ricing looks into your home directory (Linux only).
Pair it with the functional dotfiles repo, which loads hypr/look.lua when present.
EOF
}

log() {
  printf '%s\n' "$*"
}

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Linux) log "Detected OS: Linux" ;;
    Darwin) log "Detected OS: macOS" ;;
    *)
      log "Unsupported OS: $(uname -s)"
      log "This script supports Linux and macOS only."
      exit 1
      ;;
  esac
}

ensure_backup_dir() {
  if [[ "$FORCE" == false && "$DRY_RUN" == false ]]; then
    mkdir -p "$BACKUP_DIR"
  fi
}

backup_path() {
  local target="$1"

  if [[ "$FORCE" == true ]]; then
    run_cmd rm -rf "$target"
    return
  fi

  # keep the path under $HOME so same-named files (waybar vs fastfetch config.jsonc) don't collide
  local dest="$BACKUP_DIR${target#"$HOME"}"
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] mv \"$target\" \"$dest\""
    return
  fi

  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
}

link_file() {
  local source="$1"
  local target="$2"
  local target_dir

  target_dir="$(dirname "$target")"

  if [[ ! -e "$source" ]]; then
    log "Skipping missing source: $source"
    return
  fi

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    log "Already linked: $target -> $source"
    return
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    log "Existing target found: $target"
    backup_path "$target"
  fi

  run_cmd mkdir -p "$target_dir"
  run_cmd ln -s "$source" "$target"
  if [[ "$DRY_RUN" == true ]]; then
    log "Planned link: $target -> $source"
  else
    log "Linked: $target -> $source"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      --force)
        FORCE=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  detect_os
  [[ "$(uname -s)" == "Linux" ]] || { log "Linux only."; exit 1; }

  log "Ricing directory: $RICE_DIR"
  ensure_backup_dir

  # Hyprland looks (loaded by dotfiles' hyprland.lua) + wallpaper system
  link_file "$RICE_DIR/hypr/look.lua" "$HOME/.config/hypr/look.lua"
  link_file "$RICE_DIR/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
  link_file "$RICE_DIR/hypr/wallpaper.sh" "$HOME/.config/hypr/wallpaper.sh"
  link_file "$RICE_DIR/hypr/accent.py" "$HOME/.config/hypr/accent.py"
  link_file "$RICE_DIR/hypr/kbdlight.py" "$HOME/.config/hypr/kbdlight.py"
  link_file "$RICE_DIR/hypr/power-hook.sh" "$HOME/.config/hypr/power-hook.sh"
  link_file "$RICE_DIR/quickshell/wallpaper" "$HOME/.config/quickshell/wallpaper"
  link_file "$RICE_DIR/quickshell/wallpicker" "$HOME/.config/quickshell/wallpicker"

  # Notifications (Quickshell, Hyprland only): service + D-Bus activation override (dunst/Plasma stay installed)
  link_file "$RICE_DIR/quickshell/notifications" "$HOME/.config/quickshell/notifications"
  link_file "$RICE_DIR/systemd/qs-notifications.service" "$HOME/.config/systemd/user/qs-notifications.service"
  link_file "$RICE_DIR/dbus/org.freedesktop.Notifications.service" "$HOME/.local/share/dbus-1/services/org.freedesktop.Notifications.service"
  run_cmd systemctl --user daemon-reload || true # no user session (e.g. a TTY): picked up at next login
  run_cmd busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null || true # see the activation override now

  # Bar, launcher, terminals
  link_file "$RICE_DIR/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
  link_file "$RICE_DIR/waybar/style.css" "$HOME/.config/waybar/style.css"
  link_file "$RICE_DIR/waybar/cpucat.sh" "$HOME/.config/waybar/cpucat.sh"
  link_file "$RICE_DIR/fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"
  link_file "$RICE_DIR/alacritty/colors.toml" "$HOME/.config/alacritty/colors.toml"
  link_file "$RICE_DIR/konsole/Solyvie-Alacritty.colorscheme" "$HOME/.local/share/konsole/Solyvie-Alacritty.colorscheme"

  # Shell flair
  link_file "$RICE_DIR/oh-my-posh/theme.omp.json" "$HOME/.config/oh-my-posh/theme.omp.json"
  link_file "$RICE_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  link_file "$RICE_DIR/fastfetch/kirby.txt" "$HOME/.config/fastfetch/kirby.txt"
  link_file "$RICE_DIR/eza/theme.yml" "$HOME/.config/eza/theme.yml"

  # Spotify theme (Spicetify)
  link_file "$RICE_DIR/spicetify/Themes/Retro" "$HOME/.config/spicetify/Themes/Retro"

  # cava: copied, not linked; wallpaper.sh rewrites its accent lines (sed -i would replace a symlink)
  if [[ ! -f "$HOME/.config/cava/config" ]]; then
    run_cmd mkdir -p "$HOME/.config/cava"
    run_cmd cp "$RICE_DIR/cava/config" "$HOME/.config/cava/config"
  fi

  # Waycat font for the animated bar cat: fetched from upstream (no license to redistribute it here)
  if [[ ! -f "$HOME/.local/share/fonts/Waycat.ttf" ]]; then
    run_cmd mkdir -p "$HOME/.local/share/fonts"
    run_cmd curl -fsSL -o "$HOME/.local/share/fonts/Waycat.ttf" \
      https://raw.githubusercontent.com/CarloCattano/waycat/main/fonts/Waycat.ttf
    run_cmd fc-cache -f "$HOME/.local/share/fonts"
  fi

  if [[ "$FORCE" == false ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log "[dry-run] Backup directory would be: $BACKUP_DIR"
    else
      log "Backups saved in: $BACKUP_DIR"
    fi
  fi

  log "Done. For Spotify: spicetify config current_theme Retro color_scheme base && spicetify backup apply"
  log "Keyboard RGB (Lenovo LOQ/Legion): sudo install -m 644 $RICE_DIR/hypr/70-lenovo-kbd-rgb.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger -s hidraw"
}

main "$@"
