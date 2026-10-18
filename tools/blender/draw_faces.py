"""Draw the face textures of the tier head pack in a line-art style (eyelids, bags, wrinkles,
nasolabial folds, lips, chin, stubble), one per tier, Sub-3 .. True Adam.

Run with normal Python (Pillow + numpy):
    python tools/blender/draw_faces.py

Writes assets/heads/face_head_N_<tier>.png. Skin is transparent (Roblox shows the MeshPart
Color = player's skin through it); only lines and shading are painted.
The face is drawn in face space (x -1..1 across, y +1 crown .. chin) and then wrapped into
the head's cylindrical UV layout (u = angle around the head, v = height), the same layout
make_heads.py gives the mesh.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "heads")

TIERS = [  # must match make_heads.py
    ("sub3", 1.0, 0.0),
    ("sub5", 0.75, 0.12),
    ("ltn", 0.5, 0.26),
    ("mtn", 0.3, 0.4),
    ("htn", 0.15, 0.55),
    ("chadlite", 0.05, 0.7),
    ("chad", 0.0, 0.85),
    ("trueadam", 0.0, 1.0),
]

CANVAS = 2048  # face-space drawing (supersampled)
TEX = 1024  # final texture
Y_TOP, Y_BOTTOM = 1.0, -1.16

INK = (38, 26, 22, 255)
SOFT_INK = (60, 40, 34, 200)
SHADE = (70, 40, 35)
IRIS = (92, 62, 40, 255)
PUPIL = (18, 12, 10, 255)
WHITE = (246, 244, 240, 255)
LIP = (170, 85, 80)
ACNE = (190, 70, 70, 170)


def lerp(a, b, t):
    return a + (b - a) * t


def bottom(jaw):
    return lerp(-1.0, -1.14, jaw)


def P(x, y):
    """Face coords -> canvas pixel."""
    return ((x + 1) / 2 * CANVAS, (Y_TOP - y) / (Y_TOP - Y_BOTTOM) * CANVAS)


LINE_SCALE = 1.9  # bolder strokes so the art reads at game distance


def S(v):
    """Face-unit length -> pixels (horizontal scale)."""
    return v / 2 * CANVAS


def bezier(points, steps=40):
    """Cubic (4 pts) or quadratic (3 pts) bezier in face coords -> canvas polyline."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        if len(points) == 3:
            (x0, y0), (x1, y1), (x2, y2) = points
            x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
            y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
        else:
            (x0, y0), (x1, y1), (x2, y2), (x3, y3) = points
            x = (1 - t) ** 3 * x0 + 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3 * x3
            y = (1 - t) ** 3 * y0 + 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3 * y3
        out.append(P(x, y))
    return out


def stroke(d, points, width, color=INK, taper=True):
    """Polyline with tapered ends (pen-like)."""
    width *= LINE_SCALE
    n = len(points)
    for i in range(n - 1):
        t = i / max(1, n - 2)
        w = width * (math.sin(math.pi * t) * 0.7 + 0.3) if taper else width
        d.line([points[i], points[i + 1]], fill=color, width=max(1, int(w)))
        r = w / 2
        x, y = points[i + 1]
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def mirror(pts):
    return [(-x, y) for x, y in pts]


# ---------------------------------------------------------------- features

def draw_eye(d, mask_layer, side, p):
    """Almond eye with thick upper lid, iris, highlight; tilt/height from tier params."""
    s = side
    inner = (0.17 * s, 0.12)
    outer = (0.57 * s, 0.12 + p["tilt"])
    top = p["eye_open"]
    upper = [inner, (0.28 * s, 0.12 + top), (0.45 * s, 0.12 + top + p["tilt"] * 0.6), outer]
    lower = [inner, (0.3 * s, 0.12 - top * p["lower"]), (0.46 * s, 0.12 - top * p["lower"] + p["tilt"] * 0.5), outer]
    almond = bezier(upper) + list(reversed(bezier(lower)))

    # eye white + iris clipped to the almond
    layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.polygon(almond, fill=WHITE)
    ix, iy = 0.37 * s, 0.125 + p["tilt"] * 0.4 - top * 0.05
    r = S(p["iris"])
    cx, cy = P(ix, iy)
    ld.ellipse([cx - r, cy - r, cx + r, cy + r], fill=IRIS)
    ld.ellipse([cx - r * 0.45, cy - r * 0.45, cx + r * 0.45, cy + r * 0.45], fill=PUPIL)
    hr = r * 0.22
    ld.ellipse([cx - r * 0.35 - hr, cy - r * 0.4 - hr, cx - r * 0.35 + hr, cy - r * 0.4 + hr], fill=WHITE)
    m = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(m).polygon(almond, fill=255)
    mask_layer.paste(layer, (0, 0), m)

    # lids
    stroke(d, bezier(upper), S(p["lid"]), INK, taper=True)
    stroke(d, bezier(lower), S(p["lid"] * 0.35), SOFT_INK, taper=True)
    # lid crease / hooded fold
    crease_y = 0.12 + top + p["crease"]
    stroke(d, bezier([(0.24 * s, crease_y - 0.01), (0.36 * s, crease_y + 0.02), (0.5 * s, crease_y + p["tilt"] * 0.5)]),
           S(0.006), SOFT_INK)
    # under-eye bags (sub tiers)
    for k in range(p["bags"]):
        yy = 0.12 - top * p["lower"] - 0.035 - k * 0.03
        stroke(d, bezier([(0.24 * s, yy + 0.01), (0.37 * s, yy - 0.025), (0.5 * s, yy + 0.01)]), S(0.006), SOFT_INK)
    # crow's feet (sub-3)
    for k in range(p["crows"]):
        ox, oy = outer
        a = math.radians(-25 + k * 25)
        stroke(d, [P(ox + 0.03 * s, oy), P(ox + (0.03 + 0.07 * math.cos(a)) * s, oy + 0.07 * math.sin(a))],
               S(0.005), SOFT_INK)


def draw_brow(d, side, p):
    s = side
    pts = bezier([(0.17 * s, p["brow_y"] - p["brow_in"]), (0.3 * s, p["brow_y"] + p["brow_arch"]),
                  (0.45 * s, p["brow_y"] + p["brow_arch"] * 0.8), (0.58 * s, p["brow_y"] - 0.02)], steps=30)
    # several hair-like strokes give texture
    for k in range(p["brow_strokes"]):
        off = (k - p["brow_strokes"] / 2) * S(p["brow_thick"]) / p["brow_strokes"]
        shifted = [(x, y + off) for x, y in pts]
        stroke(d, shifted, S(p["brow_thick"]) / p["brow_strokes"] * 1.8, INK, taper=True)


def draw_nose(d, p):
    w = p["nose_w"]
    # tip
    stroke(d, bezier([(-w * 0.55, -0.2), (0, -0.27), (w * 0.55, -0.2)]), S(0.008), SOFT_INK)
    # nostril wings
    for s in (1, -1):
        stroke(d, bezier([(w * 0.6 * s, -0.12), (w * 1.05 * s, -0.17), (w * 0.85 * s, -0.24), (w * 0.4 * s, -0.24)]),
               S(0.009), INK)
    # bridge shadow line (sharper faces)
    if p["bridge"]:
        stroke(d, bezier([(0.07, 0.2), (0.08, 0.05), (w * 0.6, -0.1)]), S(0.005), SOFT_INK)


def draw_mouth(d, p):
    hw = p["mouth_w"]
    corner = p["mouth_corner"]
    y = -0.5
    upper = bezier([(-hw, y + corner), (-hw * 0.4, y + 0.012), (0, y - 0.004), (hw * 0.4, y + 0.012), (hw, y + corner)][:3] +
                   [(hw, y + corner)])
    stroke(d, bezier([(-hw, y + corner), (-hw * 0.3, y + 0.015), (hw * 0.3, y + 0.015), (hw, y + corner)]), S(0.011), INK)
    # cupid's bow / upper lip shape
    stroke(d, bezier([(-hw * 0.6, y + 0.03), (-hw * 0.15, y + p["lip_top"]), (0, y + p["lip_top"] - 0.01)]), S(0.005), SOFT_INK)
    stroke(d, bezier([(hw * 0.6, y + 0.03), (hw * 0.15, y + p["lip_top"]), (0, y + p["lip_top"] - 0.01)]), S(0.005), SOFT_INK)
    # lower lip
    stroke(d, bezier([(-hw * 0.5, y - p["lip_low"]), (0, y - p["lip_low"] - 0.02), (hw * 0.5, y - p["lip_low"])]), S(0.007), SOFT_INK)
    _ = upper


def draw_folds(d, p):
    """Nasolabial folds from the nose wing toward the mouth corner (age / fat); short
    marionette lines on Sub-3 only."""
    if p["folds"] <= 0:
        return
    for s in (1, -1):
        nx = p["nose_w"] * 1.15
        stroke(d, bezier([(nx * s, -0.16), ((nx + 0.12) * s, -0.27), ((p["mouth_w"] + 0.05) * s, -0.42)]),
               S(0.005 * p["folds"]), SOFT_INK)
        if p["folds"] > 1:
            stroke(d, bezier([((p["mouth_w"] + 0.02) * s, -0.56), ((p["mouth_w"] + 0.04) * s, -0.63),
                              ((p["mouth_w"] + 0.02) * s, -0.7)]), S(0.004), SOFT_INK)


def draw_chin(d, p):
    if p["double_chin"]:
        stroke(d, bezier([(-0.35, -0.92), (0, -1.0), (0.35, -0.92)]), S(0.007), SOFT_INK)
        stroke(d, bezier([(-0.28, -0.82), (0, -0.86), (0.28, -0.82)]), S(0.004), SOFT_INK)
    if p["cleft"]:
        stroke(d, bezier([(0.0, -0.78), (0.004, -0.83), (0, -0.88)]), S(0.006), SOFT_INK)
    if p["chin_line"]:
        stroke(d, bezier([(-0.16, -0.73), (0, -0.76), (0.16, -0.73)]), S(0.005), SOFT_INK)


def draw_wrinkles(d, p):
    for k in range(p["forehead_lines"]):
        y = 0.5 + k * 0.07
        stroke(d, bezier([(-0.4, y), (-0.15, y + 0.025), (0.15, y - 0.01), (0.4, y + 0.015)]), S(0.005), SOFT_INK)


def shade_layer(p, jaw):
    """Soft shading as an alpha layer (cheekbone hollows, jaw edge, eye shadow, dark circles)."""
    xs = np.linspace(-1, 1, CANVAS // 4)
    ys = np.linspace(Y_TOP, Y_BOTTOM, CANVAS // 4)
    X, Y = np.meshgrid(xs, ys)
    AX = np.abs(X)

    def g(dx, dy):
        return np.exp(-(dx * dx + dy * dy))

    a = np.zeros_like(X)
    a += g((AX - 0.58) / 0.15, (Y + 0.2) / 0.09) * 0.32 * jaw  # under cheekbones
    a += g((AX - 0.82) / 0.1, (Y + 0.45) / 0.25) * 0.3 * jaw  # jaw edge
    a += g((AX - 0.36) / 0.16, (Y - 0.24) / 0.05) * 0.18 * jaw  # deep-set eyes
    a += g((AX - 0.36) / 0.15, (Y - 0.0) / 0.05) * p["dark_circles"]  # dark circles
    a += g(AX / 0.06, (Y + 0.05) / 0.18) * 0.06  # nose bridge side
    a += g(AX / 0.25, (Y + 0.93) / 0.06) * 0.25 * jaw  # under the chin
    a = np.clip(a, 0, 0.55)
    img = np.zeros((a.shape[0], a.shape[1], 4), dtype=np.uint8)
    img[..., 0], img[..., 1], img[..., 2] = SHADE
    img[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA").resize((CANVAS, CANVAS), Image.BILINEAR)


def stubble(d, p, rng):
    for _ in range(p["stubble"]):
        x = rng.uniform(-0.75, 0.75)
        y = rng.uniform(-0.98, -0.3)
        if abs(x) < 0.25 and -0.58 < y < -0.42:  # leave the lips
            continue
        if (x / 0.78) ** 2 + ((y + 0.62) / 0.42) ** 2 > 1:
            continue
        cx, cy = P(x, y)
        r = rng.uniform(2, 4)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(45, 32, 28, 140))


def acne(d, p, rng):
    for _ in range(p["acne"]):
        x = rng.choice([-1, 1]) * rng.uniform(0.35, 0.7)
        y = rng.uniform(-0.35, 0.05) if rng.random() < 0.7 else rng.uniform(0.45, 0.65)
        cx, cy = P(x, y)
        r = rng.uniform(5, 9)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACNE)


def params(fat, jaw, k):
    """Per-tier look. k = tier index 0..7."""
    sub = max(0.0, 1 - k / 2.5)  # 1 at Sub-3, fades out by LTN
    return {
        "tilt": lerp(-0.035, 0.03, jaw),
        "eye_open": lerp(0.075, 0.045, jaw),
        "lower": lerp(0.75, 0.5, jaw),
        "iris": lerp(0.055, 0.045, jaw),
        "lid": lerp(0.012, 0.018, jaw),
        "crease": lerp(0.03, 0.014, jaw),
        "bags": 2 if k == 0 else (1 if k <= 2 else 0),
        "crows": 3 if k == 0 else 0,
        "brow_y": lerp(0.3, 0.235, jaw),
        "brow_arch": lerp(0.035, 0.0, jaw),
        "brow_in": lerp(-0.01, 0.03, jaw),
        "brow_thick": lerp(0.022, 0.05, jaw),
        "brow_strokes": 3 if jaw < 0.5 else 5,
        "nose_w": lerp(0.13, 0.09, jaw),
        "bridge": jaw > 0.45,
        "mouth_w": lerp(0.17, 0.21, jaw),
        "mouth_corner": lerp(-0.03, 0.004, jaw),
        "lip_top": lerp(0.03, 0.045, jaw),
        "lip_low": lerp(0.03, 0.05, jaw),
        "folds": 2 if k == 0 else (1 if k <= 2 else 0),
        "double_chin": fat > 0.6,
        "cleft": jaw > 0.8,
        "chin_line": 0.4 < jaw <= 0.8,
        "forehead_lines": 3 if k == 0 else 0,
        "dark_circles": 0.35 * sub,
        "stubble": int(260 * sub) + (int(180 * (jaw - 0.6) / 0.4) if jaw > 0.6 else 0),
        "acne": 9 if k == 0 else (4 if k == 1 else 0),
    }


def draw_face(k, fat, jaw):
    import random

    rng = random.Random(1000 + k)
    p = params(fat, jaw, k)
    face = shade_layer(p, jaw)
    eyes = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ink = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(ink)
    stubble(d, p, rng)
    acne(d, p, rng)
    draw_wrinkles(d, p)
    for side in (1, -1):
        draw_eye(d, eyes, side, p)
        draw_brow(d, side, p)
    draw_nose(d, p)
    draw_folds(d, p)
    draw_mouth(d, p)
    draw_chin(d, p)
    # lip tint
    tint = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    td = ImageDraw.Draw(tint)
    hw = p["mouth_w"] * 0.85
    td.polygon(bezier([(-hw, -0.5), (0, -0.5 + p["lip_top"]), (hw, -0.5)]) +
               bezier([(hw, -0.5), (0, -0.5 - p["lip_low"] - 0.02), (-hw, -0.5)]), fill=LIP + (90,))
    face = Image.alpha_composite(face, tint)
    face = Image.alpha_composite(face, eyes)
    face = Image.alpha_composite(face, ink)
    return face


def wrap(face, jaw):
    """Face-space canvas -> cylindrical head texture."""
    src = np.asarray(face.resize((CANVAS // 2, CANVAS // 2), Image.LANCZOS)).astype(np.float32)
    h, w = src.shape[:2]
    low = bottom(jaw)
    u = (np.arange(TEX) + 0.5) / TEX
    v = (np.arange(TEX) + 0.5) / TEX
    U, V = np.meshgrid(u, v)
    a = U * 2 * math.pi
    front = -np.sin(a)
    x = np.cos(a)
    y = 1 - V * (1 - low)
    px = np.clip(((x + 1) / 2 * w).astype(int), 0, w - 1)
    py = np.clip(((Y_TOP - y) / (Y_TOP - Y_BOTTOM) * h).astype(int), 0, h - 1)
    out = src[py, px]
    out[front <= 0.02] = 0
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (256 * len(TIERS), 300), (205, 160, 130, 255))
    for k, (name, fat, jaw) in enumerate(TIERS):
        face = draw_face(k, fat, jaw)
        tex = wrap(face, jaw)
        tex.save(os.path.join(OUT, f"face_head_{k + 1}_{name}.png"))
        flat = Image.new("RGBA", face.size, (205, 160, 130, 255))
        flat = Image.alpha_composite(flat, face).resize((256, 275))
        sheet.paste(flat, (256 * k, 0))
        print("drew", name)
    sheet.save(os.path.join(OUT, "faces_flat.png"))


if __name__ == "__main__":
    main()
