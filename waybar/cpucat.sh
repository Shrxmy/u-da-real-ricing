#!/usr/bin/env bash
# Animated cat for Waybar: runs faster as CPU usage rises, naps when the CPU is idle.
# Frames come from the Waycat font (A–E running, G–N sleeping): github.com/CarloCattano/waycat
set -u
run=(A B C D E)
nap=(G H I J K L M N)
idle=0

read -r _ u n s i _ </proc/stat
prev_busy=$((u + n + s)); prev_total=$((u + n + s + i))

on_battery() {
  local f v
  for f in /sys/class/power_supply/{ACAD,AC,ADP1,AC0}/online; do
    [ -r "$f" ] && { read -r v <"$f"; [ "$v" = 0 ]; return; }
  done
  return 1
}

while :; do
  # On battery: one still napping frame, checked every 10 s instead of ~8 wakeups a second
  if on_battery; then
    printf '{"text":"%s","tooltip":"on battery: cat is resting","class":"asleep"}\n' "${nap[0]}" || exit 0
    sleep 10
    read -r _ u n s i _ </proc/stat
    prev_busy=$((u + n + s)); prev_total=$((u + n + s + i))
    continue
  fi

  read -r _ u n s i _ </proc/stat
  busy=$((u + n + s)); total=$((u + n + s + i))
  pct=0
  (( total > prev_total )) && pct=$(( 100 * (busy - prev_busy) / (total - prev_total) ))
  prev_busy=$busy; prev_total=$total

  if (( pct < 2 )); then idle=$((idle + 1)); else idle=0; fi

  if (( idle >= 4 )); then
    frames=("${nap[@]}"); class=asleep; ms=250
  else
    frames=("${run[@]}"); class=awake
    ms=$(( 200 - pct * 3 / 2 )); (( ms < 50 )) && ms=50   # 200ms per frame idle-ish, 50ms flat out
  fi

  for f in "${frames[@]}"; do
    # Waybar ignores SIGPIPE for its children, so exit on a failed write or we'd outlive the bar
    printf '{"text":"%s","tooltip":"CPU %d%%","class":"%s"}\n' "$f" "$pct" "$class" || exit 0
    sleep "0.$(printf %03d "$ms")"
  done
done
