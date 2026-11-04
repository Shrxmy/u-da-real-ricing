#!/usr/bin/env python3
"""Lenovo LOQ/Legion 4-zone keyboard RGB (ITE 8295, report 0xCC). Sets the color and exits; the keyboard keeps it.

    kbdlight.py auto       on AC: the wallpaper accent; on battery: off
    kbdlight.py RRGGBB     all four zones one color
    kbdlight.py off
    kbdlight.py --selftest

Needs /dev/hidrawN access: hypr/70-lenovo-kbd-rgb.rules (installed once with sudo).
"""
import colorsys, fcntl, glob, os, sys

STATE = os.path.join(os.environ.get('XDG_STATE_HOME', os.path.expanduser('~/.local/state')), 'wallpaper', 'accent')
FALLBACK = 'cc9166'
REPORT_LEN = 33  # report ID 0xCC + 32 bytes (from the device's HID report descriptor)


def packet(rgb, brightness=2):
    """Static effect, same color on all 4 zones. brightness: 1 low, 2 high."""
    r, g, b = rgb
    buf = bytearray(REPORT_LEN)
    buf[0:5] = bytes([0xCC, 0x16, 0x01, 0x01, brightness])  # report id, set-effect cmd, static, speed, brightness
    buf[5:17] = bytes([r, g, b] * 4)
    return bytes(buf)


def led_color(hx):
    """Wallpaper accents are muted for a dark UI and read as white on LEDs: keep the hue, go full saturation-ish and full brightness."""
    r, g, b = (int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4))
    if max(r, g, b) == 0:
        return (0, 0, 0)  # off
    h, s, _ = colorsys.rgb_to_hsv(r, g, b)
    return tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, max(s, 0.85), 1.0))


def find_device():
    for d in sorted(glob.glob('/sys/class/hidraw/hidraw*')):
        try:
            with open(d + '/device/uevent') as f:
                if 'HID_ID=0003:0000048D:' not in f.read():
                    continue
            with open(d + '/device/report_descriptor', 'rb') as f:
                if b'\x85\xcc' in f.read():  # declares the RGB feature report
                    return '/dev/' + os.path.basename(d)
        except OSError:
            continue
    return None


def send(data):
    dev = find_device()
    if not dev:
        sys.exit('kbdlight: no Lenovo RGB keyboard found')
    hidiocsfeature = (3 << 30) | (len(data) << 16) | (ord('H') << 8) | 0x06  # _IOWR('H', 0x06, len)
    with open(dev, 'wb', buffering=0) as f:
        fcntl.ioctl(f, hidiocsfeature, data)


def on_ac():
    for name in ('ACAD', 'AC', 'ADP1', 'AC0'):
        try:
            with open(f'/sys/class/power_supply/{name}/online') as f:
                return f.read().strip() == '1'
        except OSError:
            continue
    return True


def accent():
    try:
        with open(STATE) as f:
            hx = f.read().split()[0]
        int(hx, 16)
        return hx if len(hx) == 6 else FALLBACK
    except (OSError, IndexError, ValueError):
        return FALLBACK


def _selftest():
    p = packet((1, 2, 3))
    assert len(p) == 33 and p[:5] == b'\xcc\x16\x01\x01\x02', p[:5]
    assert p[5:17] == bytes([1, 2, 3] * 4) and p[17:] == bytes(16)
    for hx in ('75a0bd', 'a275bd', 'cc9166', 'd65f5c'):  # dusty UI accents must read as real colors on LEDs
        r, g, b = led_color(hx)
        h0 = colorsys.rgb_to_hsv(*(int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)))[0]
        h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        assert v == 1.0 and sat >= 0.8, (hx, (r, g, b), sat)  # bright and saturated, not near-white
        assert min(abs(h - h0), 1 - abs(h - h0)) * 360 < 2, (hx, 'hue drifted')
    assert led_color('000000') == (0, 0, 0)
    assert packet(led_color('000000'))[5:17] == bytes(12)  # off = black on every zone
    print('selftest ok')


def main(arg):
    if arg == '--selftest':
        return _selftest()
    if arg == 'auto':
        arg = accent() if on_ac() else 'off'
    if arg == 'off':
        rgb = (0, 0, 0)
    else:
        int(arg, 16)  # validates hex; raises on junk
        if len(arg) != 6:
            sys.exit('kbdlight: color must be RRGGBB')
        rgb = led_color(arg)
    try:
        send(packet(rgb))
    except PermissionError:
        sys.exit('kbdlight: no permission for the keyboard; install hypr/70-lenovo-kbd-rgb.rules')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'auto')
