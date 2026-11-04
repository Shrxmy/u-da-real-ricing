#!/usr/bin/env sh
# Called by dotfiles' powerwatch.sh on plug/unplug ($1 = ac | battery): keyboard off on battery, accent on AC.
exec python3 -I "$(dirname "$(readlink -f "$0")")/kbdlight.py" auto
