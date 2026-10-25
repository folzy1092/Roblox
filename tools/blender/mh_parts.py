"""Texture-free face for the MakeHuman tier heads: the head is split into separately colored
mesh parts (Roblox colors each MeshPart, so nothing is uploaded as an image and auto-moderation
has nothing to flag):
    Head       skin (tinted with the player's skin color in game)
    Lips       faces of the head where the MakeHuman skin texture shows lips
    Brows      head faces under the opaque part of the eyebrow card, lifted a hair
    EyeWhites  eyeball faces outside the iris
    Irises     eyeball faces inside the iris
Runs inside Blender (bpy + numpy + mathutils)."""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

COLORS = {  # preview colors (in game the parts get their own Roblox colors)
    "Head": (0.8, 0.6, 0.48, 1),
    "Lips": (0.62, 0.32, 0.3, 1),
    "Brows": (0.1, 0.07, 0.05, 1),
    "EyeWhites": (0.95, 0.94, 0.92, 1),
    "Irises": (0.22, 0.13, 0.07, 1),
}


def load_pixels(path):
    img = bpy.data.images.load(path, check_existing=True)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)


def sample(pixels, uv):
    h, w = pixels.shape[:2]
    x = min(w - 1, max(0, int(uv.x * w)))
    y = min(h - 1, max(0, int(uv.y * h)))
    return pixels[y, x]


def face_uv(face, uv_layer):
    u = Vector((0.0, 0.0))
    for loop in face.loops:
        u += loop[uv_layer].uv
    return u / len(face.loops)


def split_faces(obj, faces_to_move, name):
    """Move the given face indices of `obj` into a new object called `name`."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    keep = bmesh.new()
    keep.from_mesh(obj.data)
    keep.faces.ensure_lookup_table()
    move = set(faces_to_move)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in move], context="FACES")
    bmesh.ops.delete(keep, geom=[f for f in keep.faces if f.index in move], context="FACES")
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    keep.to_mesh(obj.data)
    keep.free()
    part = bpy.data.objects.new(name, mesh)
    part.matrix_world = obj.matrix_world.copy()
    bpy.context.collection.objects.link(part)
    return part


def blur(channel, r):
    """Box blur of a 2D array (summed-area table)."""
    pad = np.pad(channel, r, mode="edge")
    c = pad.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * r + 1
    h, w = channel.shape
    return (c[k:k + h, k:k + w] - c[:h, k:k + w] - c[k:k + h, :w] + c[:h, :w]) / (k * k)


def lips(head, skin_png):
    """Mouth faces are subdivided, then the ones over the lip color of the skin texture move out."""
    skin = load_pixels(skin_png)
    red = blur(skin[:, :, 0] - skin[:, :, 1], 6)
    redmap = np.dstack([red, red, red, red])
    bm = bmesh.new()
    bm.from_mesh(head.data)
    uv = bm.loops.layers.uv.active
    mw = head.matrix_world
    zs = [(mw @ v.co).z for v in bm.verts]
    lo, hi = min(zs), max(zs)

    world = bm.copy()
    world.transform(mw)
    tree = BVHTree.FromBMesh(world)
    world.free()
    xs = [(mw @ v.co).x for v in bm.verts]
    half = (max(xs) - min(xs)) / 2

    def in_mouth(f):
        c = mw @ f.calc_center_median()
        t = (c.z - lo) / (hi - lo)  # 0 = bottom of the cut, 1 = crown
        if not (0.12 < t < 0.48 and abs(c.x) < half * 0.4 and (mw.to_3x3() @ f.normal).y < -0.2):
            return False
        # only skin you can see from the front (not the inside of the mouth)
        hit = tree.ray_cast(c + Vector((0, -1, 0)) * 0.0005, Vector((0, -1, 0)))
        return hit[0] is None

    reds = [sample(redmap, face_uv(f, uv))[0] for f in bm.faces]
    base = float(np.median(reds))
    # skins differ in how red the lips are: the cut is halfway between skin and the reddest mouth spot
    peak = float(np.percentile([r for f, r in zip(bm.faces, reds) if in_mouth(f)], 99.5))
    cut = base + (peak - base) * 0.45
    # a ring of faces around anything lip-colored gets finer so the lip outline is smooth
    seed = {f for f, r in zip(bm.faces, reds) if r > base + (cut - base) * 0.5 and in_mouth(f)}
    ring = set(seed)
    for f in seed:
        for v in f.verts:
            ring.update(v.link_faces)
    edges = list({e for f in ring for e in f.edges})
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=2, use_grid_fill=True)
    bm.faces.ensure_lookup_table()
    picks = [f.index for f in bm.faces if in_mouth(f) and sample(redmap, face_uv(f, uv))[0] > cut]
    bm.to_mesh(head.data)
    bm.free()
    return split_faces(head, picks, "Lips")


def brows(head, brow_obj, brow_png):
    """The eyebrow card itself, made finer and cut to the opaque strokes of its texture."""
    tex = load_pixels(brow_png)
    alpha = blur(tex[:, :, 3], 4)
    amap = np.dstack([alpha, alpha, alpha, alpha])
    bm = bmesh.new()
    bm.from_mesh(brow_obj.data)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=6, use_grid_fill=True)
    uv = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if sample(amap, face_uv(f, uv))[0] < 0.25], context="FACES")
    # lay every brow vertex onto the skin, a hair above it, so brows follow the face exactly
    skin = bmesh.new()
    skin.from_mesh(head.data)
    skin.transform(head.matrix_world)
    tree = BVHTree.FromBMesh(skin)
    to_world, to_local = brow_obj.matrix_world, brow_obj.matrix_world.inverted()
    for v in bm.verts:
        loc, normal, _, _ = tree.find_nearest(to_world @ v.co)
        if loc is not None:
            v.co = to_local @ (loc + normal * 0.0012)
    skin.free()
    mesh = bpy.data.meshes.new("Brows")
    bm.to_mesh(mesh)
    bm.free()
    part = bpy.data.objects.new("Brows", mesh)
    part.matrix_world = brow_obj.matrix_world.copy()
    bpy.context.collection.objects.link(part)
    return part


def eyes(eye_obj, eye_png):
    """Split the eyeballs into whites and irises by the eye texture."""
    tex = load_pixels(eye_png)
    bm = bmesh.new()
    bm.from_mesh(eye_obj.data)
    uv = bm.loops.layers.uv.active
    picks = []
    for f in bm.faces:
        c = sample(tex, face_uv(f, uv))
        if (c[0] + c[1] + c[2]) / 3 < 0.45:
            picks.append(f.index)
    bm.free()
    iris = split_faces(eye_obj, picks, "Irises")
    eye_obj.name = "EyeWhites"
    eye_obj.data.name = "EyeWhites"
    return eye_obj, iris


def clean(obj):
    for mod in list(obj.modifiers):
        obj.modifiers.remove(mod)
    obj.vertex_groups.clear()
    obj.data.materials.clear()
    for layer in list(obj.data.uv_layers):
        obj.data.uv_layers.remove(layer)
    for poly in obj.data.polygons:
        poly.use_smooth = True


def normalize_group(objs):
    """Center the group at the origin and scale it so the whole head is 1 unit tall."""
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    size = hi.z - lo.z
    for o in objs:
        mw = o.matrix_world.copy()
        for v in o.data.vertices:
            v.co = (mw @ v.co - center) / size
        o.matrix_world = o.matrix_world.Identity(4)


def export_group(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", path_mode="AUTO", embed_textures=False,
                             mesh_smooth_type="FACE", add_leaf_bones=False)


def color(obj):
    key = obj.name.split(".")[0].split("_")[-1]
    mat = bpy.data.materials.get(f"prev_{key}") or bpy.data.materials.new(f"prev_{key}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = COLORS.get(key, COLORS["Head"])
    bsdf.inputs["Roughness"].default_value = 0.35 if key in ("EyeWhites", "Irises") else 0.6
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def render(groups, path, side=False, px=260):
    scene = bpy.context.scene
    for k, objs in enumerate(groups):
        for o in objs:
            o.location = ((k - (len(groups) - 1) / 2) * 1.1, 0, 0)
            o.rotation_euler = (0, 0, math.radians(90) if side else 0)
            color(o)
    cam = scene.camera
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        for name, rot, energy in (("key", (math.radians(55), 0, math.radians(-30)), 3.0),
                                  ("fill", (math.radians(70), 0, math.radians(40)), 1.0)):
            lo = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
            lo.data.energy = energy
            lo.rotation_euler = rot
            scene.collection.objects.link(lo)
        if scene.world is None:
            scene.world = bpy.data.worlds.new("World")
        scene.world.use_nodes = True
        scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.2, 1)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.1 * len(groups)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = px * len(groups)
    scene.render.resolution_y = int(px * 1.15)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
