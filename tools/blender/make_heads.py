"""Generate the Looksmax tier head pack (Sub-3 .. True Adam) in Blender.

Run headless:
    blender --background --python tools/blender/make_heads.py

Output (assets/heads/):
    head_1_sub3.fbx .. head_8_trueadam.fbx   one mesh per tier, with its face texture
    face_N.png                               face texture (transparent skin -> part Color shows)
    preview.png                              all eight heads side by side

Shape: a dense sphere deformed by a silhouette profile (round & puffy -> diamond with
cheekbones, jaw angles and a square chin) plus facial relief (nose, brows, sockets,
cheekbones, buccal hollows, lips, chin). Texture: eyes, brows, mouth, shading, stubble
painted procedurally; skin pixels are left transparent so Roblox tints them with the
MeshPart Color (the player's skin tone).
"""

import math
import os

import bmesh
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "heads")
TEX = 512

TIERS = [
    # name, fat (puffiness), jaw (diamond / masculinity)
    ("sub3", 1.0, 0.0),
    ("sub5", 0.75, 0.12),
    ("ltn", 0.5, 0.26),
    ("mtn", 0.3, 0.4),
    ("htn", 0.15, 0.55),
    ("chadlite", 0.05, 0.7),
    ("chad", 0.0, 0.85),
    ("trueadam", 0.0, 1.0),
]


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def g(dx, dy):
    return math.exp(-(dx * dx + dy * dy))


def smooth(t):
    t = clamp(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- shape
# Head units: y from +1 (crown) to bottom(jaw) (chin); x = cos(angle) across; front = -z.
# Proportions of a human head: taller than wide, deeper than wide, flat-ish face plane.

WIDTH = 0.8  # half-width of the skull relative to half-height
DEPTH = 0.92  # half-depth (front-back)

DIAMOND = [  # (height, face half-width) for a sharp face: cheekbones, jaw angle, square chin
    (1.0, 0.0),
    (0.85, 0.55),
    (0.5, 0.86),
    (0.1, 0.98),  # cheekbones
    (-0.4, 0.86),  # jaw angle
    (-0.75, 0.52),
    (-0.95, 0.34),  # square chin
    (-1.0, 0.0),
]


def piecewise(keys, y):
    for (y0, w0), (y1, w1) in zip(keys, keys[1:]):
        if y1 <= y <= y0:
            t = (y0 - y) / (y0 - y1)
            return lerp(w0, w1, smooth(t) * 0.8 + t * 0.2)
    return 0.0


def round_width(y, fat):
    """Egg: round skull, face narrowing to the chin; fat adds jowls low on the face."""
    if y >= 0:
        base = math.sqrt(max(0.0, 1 - (y / 1.0) ** 2.2))
    else:
        base = math.sqrt(max(0.0, 1 - (-y) ** 2.6)) * (1 - 0.12 * (-y))
    jowls = fat * 0.2 * math.sin(clamp((0.15 - y) / 1.0, 0, 1) * math.pi) if y < 0.15 else 0.0
    return base + jowls


def face_width(y, fat, jaw):
    return lerp(round_width(y, fat), piecewise(DIAMOND, y), jaw)


def front_depth(y, fat, jaw):
    """How far the face sticks out at height y (forehead, brow, flat face, chin)."""
    if y > 0.3:
        return math.sqrt(max(0.0, 1 - ((y - 0.3) / 0.75) ** 2)) * 0.95
    d = 0.95 - 0.04 * smooth((0.3 - y) / 0.25)  # under the brow
    d += fat * 0.05 * smooth((0.1 - y) / 0.5)  # puffy lower face
    d -= (1 - jaw) * 0.12 * smooth((-0.55 - y) / 0.4)  # weak receding chin on low tiers
    d += jaw * 0.03 * smooth((-0.6 - y) / 0.3)  # strong forward chin
    edge = smooth((y - bottom(jaw)) / 0.18)  # round off under the chin
    return d * (0.35 + 0.65 * edge)


def back_depth(y):
    if y > -0.2:
        return math.sqrt(max(0.0, 1 - (y / 1.05) ** 2))
    return math.sqrt(max(0.0, 1 - (0.2 / 1.05) ** 2)) * (1 - 0.55 * smooth((-0.2 - y) / 0.8))


def bottom(jaw):
    return lerp(-1.0, -1.14, jaw)


def relief(x, y, front, fat, jaw):
    if front <= 0:
        return 0.0
    ax = abs(x)
    r = 0.0
    # nose: bridge from the brows, rounded tip, nostril wings
    r += g(x / 0.1, 0) * smooth((0.28 - y) / 0.12) * smooth((y + 0.26) / 0.1) * 0.09
    r += g(x / 0.13, (y + 0.2) / 0.08) * 0.09
    r += g((ax - 0.1) / 0.06, (y + 0.24) / 0.05) * 0.025
    # brow ridge
    r += g(0, (y - 0.32) / 0.07) * smooth((0.7 - ax) / 0.25) * (0.015 + 0.05 * jaw)
    # eye sockets
    r -= g((ax - 0.36) / 0.15, (y - 0.13) / 0.09) * (0.02 + 0.035 * jaw)
    # cheekbones
    r += g((ax - 0.62) / 0.2, (y - 0.02) / 0.12) * (0.015 + 0.04 * jaw)
    # under cheekbones: puffy (fat) or hollow (lean)
    r += g((ax - 0.5) / 0.24, (y + 0.32) / 0.18) * (0.1 * fat - 0.025 * jaw)
    # lips
    r += g(x / 0.22, (y + 0.44) / 0.05) * 0.03
    r += g(x / 0.18, (y + 0.53) / 0.045) * 0.025
    # chin pad and cleft
    r += g(x / 0.26, (y + 0.8) / 0.1) * 0.05 * jaw
    r -= g(x / 0.04, (y + 0.84) / 0.06) * 0.02 * jaw
    # double chin
    r += g(x / 0.5, (y + 0.95) / 0.12) * 0.12 * fat
    return r * clamp(front * 1.4, 0, 1)


def surface(a, y, fat, jaw):
    """Point (x right, y up, z back) in head units for angle a (sin a < 0 = face) and height y."""
    uy = clamp(y, -1, 1)
    cx, sz = math.cos(a), math.sin(a)
    front = max(0.0, -sz)
    # diamond reshapes the face and sides; the back of the skull stays round
    w_face = face_width(uy, fat, jaw)
    w_back = round_width(uy, fat * 0.5)
    w = lerp(w_back, w_face, clamp(0.35 + front, 0, 1)) * WIDTH * lerp(1.0, 0.9, jaw)  # top tiers: narrower, longer face
    # jaw corner below the ears on the sides
    w *= 1 + g(0, (uy + 0.42) / 0.18) * 0.03 * jaw * (1 - front)
    push = relief(cx, uy, front, fat, jaw)
    if sz < 0:
        # flatter face plane: superellipse front
        z = -front_depth(uy, fat, jaw) * DEPTH * (front ** 0.7) * (1 + push)
    else:
        z = back_depth(uy) * DEPTH * sz
    x = w * cx * (1 + push * 0.3)
    return x, y, z


# ---------------------------------------------------------------- texture

def mix(c, target, a):
    if a <= 0:
        return
    a = min(a, 1.0)
    for i in range(4):
        c[i] = lerp(c[i], target[i], a)


def inside(d, soft):
    return clamp((1 + soft - d) / soft, 0, 1)


def hash01(x, y):
    n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return n - math.floor(n)


SCLERA = (0.95, 0.94, 0.92, 1)
IRIS = (0.33, 0.22, 0.14, 1)
PUPIL = (0.05, 0.04, 0.04, 1)
LINE = (0.13, 0.09, 0.08, 1)
BROW = (0.17, 0.12, 0.09, 1)
LIP = (0.6, 0.3, 0.3, 0.55)
MOUTH = (0.35, 0.14, 0.14, 1)
SHADOW = (0.25, 0.14, 0.12, 1)


def eye(c, x, y, side, jaw, fat):
    cx, cy = 0.36 * side, 0.12
    rx = lerp(0.16, 0.155, jaw)
    ry = lerp(0.07, 0.04, jaw) * (1 - 0.15 * fat)
    tilt = lerp(-0.14, 0.2, jaw) * side
    dx, dy = x - cx, y - cy
    lx = dx * math.cos(tilt) + dy * math.sin(tilt)
    ly = -dx * math.sin(tilt) + dy * math.cos(tilt)
    d = math.sqrt((lx / rx) ** 2 + (ly / ry) ** 2)
    if 0.9 < d < 1.3 and ly > -ry * 0.3:
        mix(c, LINE, inside(abs(d - 1.08) / 0.2, 0.4) * 0.95)
    fill = inside(d, 0.15)
    if fill <= 0:
        return
    mix(c, SCLERA, fill)
    ir = ry * 0.95
    idist = math.sqrt(lx * lx + (ly + ry * 0.1) ** 2) / ir
    mix(c, IRIS, inside(idist, 0.2) * fill)
    mix(c, PUPIL, inside(idist / 0.45, 0.3) * fill)


def brow(c, x, y, jaw):
    ax = abs(x)
    if ax < 0.16 or ax > 0.58:
        return
    t = (ax - 0.16) / 0.42
    center = lerp(0.33, 0.255, jaw) + 0.035 * math.sin(math.pi * t) * (1 - jaw) + (t - 0.4) * 0.05 * jaw
    thick = lerp(0.02, 0.045, jaw) * (1 - 0.35 * t)
    mix(c, BROW, inside(abs(y - center) / thick, 0.5) * 0.95)


def mouth(c, x, y, jaw):
    ax = abs(x)
    half = lerp(0.21, 0.24, jaw)
    if ax > half + 0.02:
        return
    line_y = -0.5 - 0.025 * (ax / half) ** 2 * (1 - jaw)
    edge = inside(ax / half, 0.15)
    mix(c, LIP, inside(abs(y - (line_y - 0.03)) / 0.03, 0.6) * edge)
    mix(c, LIP, inside(abs(y - (line_y + 0.02)) / 0.017, 0.6) * 0.6 * edge)
    mix(c, MOUTH, inside(abs(y - line_y) / 0.011, 0.8) * edge)


def texel(u, v, px, py, fat, jaw, low):
    """RGBA for texture coordinate (u around the head, v top->bottom). Skin = transparent."""
    c = [SHADOW[0], SHADOW[1], SHADOW[2], 0.0]
    a = u * math.pi * 2
    front = -math.sin(a)
    if front <= 0.05:
        return c
    x = math.cos(a)
    y = 1 - v * (1 - low)
    ax = abs(x)
    # soft shading painted as translucent shadow over the skin
    shade = g((ax - 0.58) / 0.17, (y + 0.18) / 0.09) * 0.25 * jaw
    shade += g((ax - 0.12) / 0.04, (y + 0.04) / 0.15) * 0.12
    shade += g((ax - 0.36) / 0.15, (y - 0.03) / 0.04) * 0.3 * fat
    if jaw > 0.55:
        k = (jaw - 0.55) / 0.45 * smooth((-0.32 - y) / 0.15) * smooth((0.85 - ax) / 0.2)
        k *= smooth((y - low - 0.06) / 0.1)  # nothing under the chin
        k *= 1 - g(x / 0.2, (y + 0.48) / 0.06)  # keep the lips clean
        shade += 0.08 * k + (0.22 * k if hash01(px, py) > 0.6 else 0)
    c[3] = clamp(shade, 0, 0.6)
    mix(c, SHADOW, g((ax - 0.07) / 0.03, (y + 0.25) / 0.02) * 0.9)  # nostrils
    eye(c, x, y, 1, jaw, fat)
    eye(c, x, y, -1, jaw, fat)
    brow(c, x, y, jaw)
    mouth(c, x, y, jaw)
    return c


def paint_image(name, fat, jaw):
    img = bpy.data.images.new(name, TEX, TEX, alpha=True)
    low = bottom(jaw)
    pixels = [0.0] * (TEX * TEX * 4)
    for py in range(TEX):
        v = 1 - (py + 0.5) / TEX  # Blender images start at the bottom row
        for px in range(TEX):
            u = (px + 0.5) / TEX
            c = texel(u, v, px, py, fat, jaw, low)
            o = (py * TEX + px) * 4
            pixels[o:o + 4] = c
    img.pixels = pixels
    path = os.path.join(OUT, f"{name}.png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


# ---------------------------------------------------------------- mesh

LAT, LON = 64, 96


def build_head(name, fat, jaw):
    low = bottom(jaw)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    grid = []
    for i in range(LAT + 1):
        y = 1 - (i / LAT) * (1 - low)
        row = []
        for j in range(LON + 1):  # duplicated seam column for clean UVs
            a = (j % LON) / LON * math.pi * 2
            x, yy, z = surface(a, y, fat, jaw)
            # Blender: X right, Z up, -Y front  (head units -> half size 0.5)
            row.append(bm.verts.new((x * 0.5, z * 0.5, yy * 0.5)))
        grid.append(row)
    for i in range(LAT):
        for j in range(LON):
            quad = (grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
            try:
                f = bm.faces.new(quad)
            except ValueError:
                continue
            uvs = ((j / LON, 1 - i / LAT), ((j + 1) / LON, 1 - i / LAT),
                   ((j + 1) / LON, 1 - (i + 1) / LAT), (j / LON, 1 - (i + 1) / LAT))
            for loop, uv in zip(f.loops, uvs):
                loop[uv_layer].uv = uv
    bmesh.ops.remove_doubles(bm, verts=[v for row in (grid[0], grid[-1]) for v in row], dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    # face texture drawn by draw_faces.py (line art); fall back to the procedural paint
    drawn = os.path.join(OUT, f"face_{name}.png")
    if os.path.exists(drawn):
        img = bpy.data.images.load(drawn)
        img.alpha_mode = "STRAIGHT"
    else:
        img = paint_image(f"face_{name}", fat, jaw)
    add_ears(obj, fat, jaw)
    mat = bpy.data.materials.new(f"mat_{name}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    obj.data.materials.append(mat)
    return obj


def add_ears(obj, fat, jaw):
    """Two ears on the sides, joined into the head. Their UVs point at a transparent
    (back-of-head) texel, so they take the skin color."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv_layer = bm.loops.layers.uv.active
    stick_out = lerp(0.35, 0.15, jaw) + 0.1 * fat  # Sub-3 ears stick out more
    for side in (1, -1):
        res = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=1.0)
        verts = res["verts"]
        y_mid = 0.02  # between brow and nose tip (head units)
        # skull half width in Blender units (same narrowing as surface())
        x_side = round_width(y_mid, fat * 0.5) * WIDTH * lerp(1.0, 0.9, jaw) * 0.5 - 0.01
        for v in verts:
            x, y, z = v.co
            # flat ear: thin across, tall, slightly deep; tilt the back edge outward
            v.co.x = x * 0.035 + side * (x_side + 0.01 + 0.04 * stick_out * (y * 0.5 + 0.5))
            v.co.y = y * 0.075 + 0.04
            v.co.z = z * 0.13 + y_mid * 0.5
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            for loop in f.loops:
                loop[uv_layer].uv = (0.25, 0.5)
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = True


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_unit_scale=True,
        bake_space_transform=True,
        axis_forward="-Z",
        axis_up="Y",
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
    )


def preview_material(obj, skin=(0.78, 0.6, 0.48, 1)):
    """Skin color with the face texture laid over it by alpha (what Roblox shows)."""
    src = obj.data.materials[0]
    img = next(n.image for n in src.node_tree.nodes if n.type == "TEX_IMAGE")
    mat = bpy.data.materials.new(f"preview_{obj.name}")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = skin
    nt.links.new(tex.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(tex.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    obj.data.materials[0] = mat


def preview(objs):
    """EEVEE render of all heads in a row, front view."""
    scene = bpy.context.scene
    for k, obj in enumerate(objs):
        obj.location = ((k - (len(objs) - 1) / 2) * 1.25, 0, 0)
        preview_material(obj)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.25 * len(objs)
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, rot, energy in (("key", (math.radians(60), 0, math.radians(-30)), 3.0),
                              ("fill", (math.radians(70), 0, math.radians(40)), 1.2)):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        lo = bpy.data.objects.new(name, light)
        lo.rotation_euler = rot
        scene.collection.objects.link(lo)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.2, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.render.resolution_x = 200 * len(objs)
    scene.render.resolution_y = 280
    scene.render.filepath = os.path.join(OUT, "preview.png")
    bpy.ops.render.render(write_still=True)


def closeup(objs, picks=(0, 4, 7)):
    """Bigger front shot of a few tiers (Sub-3, HTN, True Adam)."""
    scene = bpy.context.scene
    for k, obj in enumerate(objs):
        obj.hide_render = k not in picks
        if k in picks:
            obj.location = ((picks.index(k) - 1) * 1.25, 0, 0)
    scene.camera.data.ortho_scale = 1.25 * 3
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 520
    scene.render.filepath = os.path.join(OUT, "preview_close.png")
    bpy.ops.render.render(write_still=True)
    for obj in objs:
        obj.hide_render = False


def side_preview(objs):
    """Same row seen from the side (profile), to judge jaw and chin."""
    scene = bpy.context.scene
    for k, obj in enumerate(objs):
        obj.rotation_euler = (0, 0, math.radians(90))
    scene.render.filepath = os.path.join(OUT, "preview_side.png")
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("World")
    objs = []
    for k, (name, fat, jaw) in enumerate(TIERS, start=1):
        obj = build_head(f"head_{k}_{name}", fat, jaw)
        export(obj, os.path.join(OUT, f"head_{k}_{name}.fbx"))
        objs.append(obj)
        bb = [obj.matrix_world @ __import__("mathutils").Vector(c) for c in obj.bound_box]
        print(f"[heads] {obj.name} done: {len(obj.data.vertices)} verts, {len(obj.data.polygons)} faces, "
              f"z {min(v.z for v in bb):.2f}..{max(v.z for v in bb):.2f}, y {min(v.y for v in bb):.2f}..{max(v.y for v in bb):.2f}")
    preview(objs)
    closeup(objs)
    for k, obj in enumerate(objs):
        obj.location = ((k - (len(objs) - 1) / 2) * 1.25, 0, 0)
    bpy.context.scene.camera.data.ortho_scale = 1.25 * len(objs)
    bpy.context.scene.render.resolution_x = 200 * len(objs)
    bpy.context.scene.render.resolution_y = 280
    side_preview(objs)
    print("[heads] all done ->", OUT)


main()
