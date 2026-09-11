"""Generates a smooth animated green checkmark GIF for the login success popup.

Rendered on a WHITE background (to match the white popup card) so there is no
GIF alpha fringing/blur. Uses 4x supersampling for crisp anti-aliased edges.
"""
import math
from PIL import Image, ImageDraw

SS = 4                      # supersample factor
OUT = 240                   # final size (px)
SIZE = OUT * SS
BG = (255, 255, 255, 255)   # white, matches popup card
GREEN_TOP = (34, 197, 94)   # #22C55E
GREEN_BOT = (21, 128, 61)   # #15803D

cx = cy = SIZE / 2
R = SIZE * 0.36             # circle radius


def ease_out_back(t, s=1.70158):
    t -= 1
    return t * t * ((s + 1) * t + s) + 1


def lerp(a, b, t):
    return a + (b - a) * t


def green_at(y):
    """Vertical gradient color for the circle."""
    t = (y - (cy - R)) / (2 * R)
    t = max(0.0, min(1.0, t))
    return (
        int(lerp(GREEN_TOP[0], GREEN_BOT[0], t)),
        int(lerp(GREEN_TOP[1], GREEN_BOT[1], t)),
        int(lerp(GREEN_TOP[2], GREEN_BOT[2], t)),
    )


def draw_circle(draw, scale):
    r = R * scale
    # gradient via horizontal slices
    steps = 120
    for i in range(steps):
        y0 = cy - r + (2 * r) * (i / steps)
        y1 = cy - r + (2 * r) * ((i + 1) / steps)
        ymid = (y0 + y1) / 2
        dy = abs(ymid - cy)
        if dy > r:
            continue
        dx = math.sqrt(max(0.0, r * r - dy * dy))
        draw.rectangle([cx - dx, y0, cx + dx, y1 + 1], fill=green_at(ymid))


# checkmark control points relative to center
P0 = (cx - 0.34 * R, cy + 0.02 * R)
P1 = (cx - 0.08 * R, cy + 0.28 * R)
P2 = (cx + 0.38 * R, cy - 0.26 * R)
TICK_W = int(R * 0.20)


def seg_len(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


L1 = seg_len(P0, P1)
L2 = seg_len(P1, P2)
LT = L1 + L2


def point_along(p):
    """Point at progress p (0..1) along the two-segment tick path."""
    d = p * LT
    if d <= L1:
        t = d / L1
        return (lerp(P0[0], P1[0], t), lerp(P0[1], P1[1], t))
    t = (d - L1) / L2
    return (lerp(P1[0], P2[0], t), lerp(P1[1], P2[1], t))


def draw_tick(draw, progress):
    if progress <= 0:
        return
    n = 60
    pts = [P0]
    for i in range(1, n + 1):
        p = (i / n) * progress
        pts.append(point_along(p))
    # round caps + joints
    for x, y in pts:
        draw.ellipse([x - TICK_W / 2, y - TICK_W / 2, x + TICK_W / 2, y + TICK_W / 2],
                     fill=(255, 255, 255, 255))
    draw.line(pts, fill=(255, 255, 255, 255), width=TICK_W, joint="curve")


frames = []
TOTAL = 30
for f in range(TOTAL):
    img = Image.new("RGBA", (SIZE, SIZE), BG)
    d = ImageDraw.Draw(img)

    # phase 1 (0-11): circle pops in; phase 2 (10-22): tick draws; rest hold
    cp = min(1.0, f / 11.0)
    circle_scale = 0.2 + 0.8 * ease_out_back(cp)
    draw_circle(d, circle_scale)

    if f >= 10:
        tp = min(1.0, (f - 10) / 11.0)
        # ease out for nicer finish
        tp = 1 - (1 - tp) * (1 - tp)
        draw_tick(d, tp)

    img = img.convert("RGB").resize((OUT, OUT), Image.LANCZOS)
    frames.append(img)

# hold the final frame
for _ in range(10):
    frames.append(frames[-1])

durations = [40] * TOTAL + [60] * 10

frames[0].save(
    "assets/animations/check_success.gif",
    save_all=True,
    append_images=frames[1:],
    duration=durations,
    loop=0,
    optimize=True,
    disposal=2,
)
print("Saved assets/animations/check_success.gif", len(frames), "frames")
