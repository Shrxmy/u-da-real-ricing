#!/usr/bin/env python3
"""Pick an accent pair (accent, sand) from a wallpaper's most vivid color.

    accent.py IMAGE      print "ACCENT SAND" (hex, no '#'); fallback pair if image has no real color
    accent.py --selftest
"""
import colorsys, re, subprocess, sys

FALLBACK = ('cc9166', 'd9ac8c')  # hand-picked amber/sand


def _rgb(hx):
    return tuple(int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _hex(rgb):
    return ''.join(f'{round(c * 255):02x}' for c in rgb)


def pick(hist):
    """hist: [(count, 'rrggbb')] -> (accent, sand) or None when nothing vivid."""
    lit = [(n, hx) for n, hx in hist if max(_rgb(hx)) >= 0.15]  # night-sky black would drown every color
    if not lit:
        return None
    total = sum(n for n, _ in lit)
    best, best_score = None, 0
    for n, hx in lit:
        share = n / total
        rgb = _rgb(hx)
        chroma = max(rgb) - min(rgb)
        if share < 0.02 or chroma < 0.15:  # specks and near-grays don't define the image
            continue
        if chroma * share ** 0.5 > best_score:
            best, best_score = rgb, chroma * share ** 0.5
    if best is None:
        return None
    h, _, s = colorsys.rgb_to_hls(*best)
    s = min(max(s, 0.35), 0.60)  # keep it in the muted range of the base palette
    return _hex(colorsys.hls_to_rgb(h, 0.60, s)), _hex(colorsys.hls_to_rgb(h, 0.72, s))


def histogram(path):
    out = subprocess.run(['magick', path, '-resize', '64x64!', '-colors', '12', '-depth', '8',
                          '-format', '%c', 'histogram:info:-'],
                         capture_output=True, text=True, check=True).stdout
    return [(int(n), hx.lower()) for n, hx in re.findall(r'(\d+):.*?#([0-9A-Fa-f]{6})', out)]


def main(path):
    try:
        pair = pick(histogram(path))
    except (subprocess.CalledProcessError, OSError):
        pair = None  # unreadable image: keep the default look
    print(*(pair or FALLBACK))


def _selftest():
    assert pick([(900, '808080'), (100, '202020')]) is None, 'gray -> fallback'
    assert pick([(990, '303030'), (10, 'ff0080')]) is None, '1% speck ignored'
    assert pick([(985, '080808'), (15, '6f4b88')]) is not None, 'space shot: share counts lit pixels only'
    assert pick([(2867, '1b1828'), (741, '352647'), (305, '4c335b')]) is not None, 'dull majority must not block a vivid minority'
    a, s = pick([(600, 'ff70b0'), (400, '202020')])
    h0 = colorsys.rgb_to_hls(*_rgb('ff70b0'))[0]
    for hx, light in ((a, 0.60), (s, 0.72)):
        h, l, _ = colorsys.rgb_to_hls(*_rgb(hx))
        assert abs(h - h0) * 360 < 10, (hx, 'hue drifted')
        assert abs(l - light) <= 0.01, (hx, l)
    print('selftest ok')


if __name__ == '__main__':
    _selftest() if sys.argv[1:] == ['--selftest'] else main(sys.argv[1])
