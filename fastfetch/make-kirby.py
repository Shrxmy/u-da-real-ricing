#!/usr/bin/env python3
"""Render a pixel-art Kirby as ANSI half-blocks for fastfetch (logo type "file-raw").
Usage: python3 make-kirby.py > kirby.txt"""

SPRITE = [
    "......OOOOOO......",
    "....OOPPPPPPOO....",
    "...OPPPPPPPPPPO...",
    "..OPPPPPPPPPPPPO..",
    ".OPPPPPWPPWPPPPPO.",
    ".OPPPPPEPPEPPPPPO.",
    "OPPPPPPBPPBPPPPPPO",
    "OPPCCPPPMMPPPCCPPO",
    "OPPPPPPPPPPPPPPPPO",
    "OPPPPPPPPPPPPPPPPO",
    ".OPPPPPPPPPPPPPPO.",
    ".OSPPPPPPPPPPPPSO.",
    "..OSSPPPPPPPPSSO..",
    ".ORRRRROOOORRRRRO.",
    ".OOOOOOO..OOOOOOO.",
    "..................",
]
COLORS = {  # muted to sit with the Retro Clean palette
    "O": (92, 64, 82),     # outline (lighter than the terminal bg)
    "P": (233, 163, 185),  # body pink
    "S": (201, 132, 156),  # body shade
    "W": (255, 255, 255),  # eye highlight
    "E": (29, 27, 46),     # eye
    "B": (74, 111, 165),   # eye blue
    "C": (224, 122, 154),  # cheeks
    "M": (140, 58, 74),    # mouth
    "R": (194, 84, 94),    # feet
}
SCALE = 2  # each sprite pixel becomes 2x2 terminal half-cells

assert all(len(r) == len(SPRITE[0]) for r in SPRITE) and len(SPRITE) % 2 == 0
assert set("".join(SPRITE)) <= set(COLORS) | {"."}

rows = [r for r in SPRITE for _ in range(SCALE)]
rows = ["".join(ch * SCALE for ch in r) for r in rows]

def fg(c): return "\x1b[38;2;%d;%d;%dm" % COLORS[c]
def bg(c): return "\x1b[48;2;%d;%d;%dm" % COLORS[c]

out = []
for top, bot in zip(rows[0::2], rows[1::2]):
    line = ""
    for t, b in zip(top, bot):
        if t == "." and b == ".":
            line += "\x1b[0m "
        elif t == ".":
            line += "\x1b[0m" + fg(b) + "▄"
        elif b == "." or t == b:
            line += "\x1b[0m" + fg(t) + ("█" if t == b else "▀")
        else:
            line += fg(t) + bg(b) + "▀"
    out.append(line.rstrip() + "\x1b[0m")
print("\n".join(out))
