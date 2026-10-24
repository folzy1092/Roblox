"""Packing helpers for make_mh_heads.py: one mesh + one texture atlas per head, FBX export,
preview renders. Runs inside Blender (bpy + numpy)."""

import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

ATLAS = 1024
HEAD_RECT = (0.0, 0.25, 1.0, 1.0)  # (u0, v0, u1, v1) in the atlas
EYES_RECT = (0.0, 0.125, 1.0, 0.25)
BROW_RECT = (0.0, 0.0, 1.0, 0.125)


def load_pixels(path):
    img = bpy.data.images.load(path, check_existing=True)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)  # rows bottom-up


def resample(src, u0, v0, u1, v1, out_w, out_h):
    """Crop UV rect [u0,u1]x[v0,v1] of src (bottom-up rows) and resize (nearest)."""
    h, w = src.shape[:2]
    us = u0 + (np.arange(out_w) + 0.5) / out_w * (u1 - u0)
    vs = v0 + (np.arange(out_h) + 0.5) / out_h * (v1 - v0)
    px = np.clip((us * w).astype(int), 0, w - 1)
    py = np.clip((vs * h).astype(int), 0, h - 1)
    return src[py][:, px].copy()


def uv_bounds(obj, pad=0.01):
    uv = obj.data.uv_layers.active.data
    us = [d.uv.x for d in uv]
    vs = [d.uv.y for d in uv]
    return (max(0.0, min(us) - pad), max(0.0, min(vs) - pad), min(1.0, max(us) + pad), min(1.0, max(vs) + pad))


def remap_uvs(obj, src_rect, dst_rect):
    u0, v0, u1, v1 = src_rect
    a0, b0, a1, b1 = dst_rect
    for d in obj.data.uv_layers.active.data:
        d.uv.x = a0 + (d.uv.x - u0) / max(1e-6, u1 - u0) * (a1 - a0)
        d.uv.y = b0 + (d.uv.y - v0) / max(1e-6, v1 - v0) * (b1 - b0)


def rows(rect):
    return int(rect[1] * ATLAS), int(rect[3] * ATLAS)


def pack(head, eyes, brows, skin_png, eye_png, brow_png, name, out_dir):
    """Join head + eyes + brows into one object with one atlas texture.
    Skin texels become transparent (Roblox shows the MeshPart Color = player skin through them);
    lips, shading, eyes and brows stay painted."""
    atlas = np.zeros((ATLAS, ATLAS, 4), dtype=np.float32)

    rect = uv_bounds(head)
    r0, r1 = rows(HEAD_RECT)
    skin = resample(load_pixels(skin_png), *rect, ATLAS, r1 - r0)
    # skin becomes transparent (player's skin color shows); keep only what is darker than the
    # base skin (creases, shadows, wrinkles) and redder (lips), as a tinted overlay
    base = np.median(skin[..., :3].reshape(-1, 3), axis=0)
    lum = skin[..., :3].mean(axis=2)
    dark = np.clip((base.mean() - lum - 0.03) * 4.0, 0, 0.75)
    red = np.clip(((skin[..., 0] - skin[..., 1]) - (base[0] - base[1]) - 0.04) * 5.0, 0, 0.8)
    skin[..., 3] = np.maximum(dark, red)
    atlas[r0:r1] = skin
    remap_uvs(head, rect, HEAD_RECT)

    e0, e1 = rows(EYES_RECT)
    erect = uv_bounds(eyes, pad=0)
    eye_img = resample(load_pixels(eye_png), *erect, ATLAS, e1 - e0)
    eye_img[..., 3] = 1.0
    atlas[e0:e1] = eye_img
    remap_uvs(eyes, erect, EYES_RECT)

    b0, b1 = rows(BROW_RECT)
    brect = uv_bounds(brows, pad=0)
    brow = resample(load_pixels(brow_png), *brect, ATLAS, b1 - b0)
    brow[..., 0], brow[..., 1], brow[..., 2] = 0.07, 0.05, 0.04  # dark hair, alpha keeps the strokes
    atlas[b0:b1] = brow
    remap_uvs(brows, brect, BROW_RECT)

    img = bpy.data.images.new(f"atlas_{name}", ATLAS, ATLAS, alpha=True)
    img.pixels = atlas.ravel().tolist()
    img.filepath_raw = os.path.join(out_dir, f"atlas_{name}.png")
    img.file_format = "PNG"
    img.save()

    bpy.ops.object.select_all(action="DESELECT")
    for o in (head, eyes, brows):
        for mod in list(o.modifiers):
            o.modifiers.remove(mod)
        o.data.materials.clear()
        o.data.uv_layers.active.name = "UVMap"
        o.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()

    mat = bpy.data.materials.new(f"mat_{name}")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = nt.nodes.get("Principled BSDF")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    head.data.materials.append(mat)
    for poly in head.data.polygons:
        poly.use_smooth = True
    return head


def normalize(obj):
    """Center the head at the origin and scale it to 1 unit tall."""
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    size = hi.z - lo.z
    mw = obj.matrix_world.copy()
    for v in obj.data.vertices:
        v.co = (mw @ v.co - center) / size
    obj.matrix_world = Matrix.Identity(4)


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # mesh only: no textures are exported (uploaded atlases got flagged by Roblox auto-moderation)
    for slot in obj.material_slots:
        slot.material = None
    obj.data.materials.clear()
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", path_mode="AUTO", embed_textures=False,
                             mesh_smooth_type="FACE", add_leaf_bones=False)


def render_row(objs, path, side=False):
    """Skin-colored heads with the atlas over it, in a row (front or side)."""
    scene = bpy.context.scene
    for k, obj in enumerate(objs):
        obj.location = ((k - (len(objs) - 1) / 2) * 1.1, 0, 0)
        obj.rotation_euler = (0, 0, math.radians(90) if side else 0)
        # heads are exported without textures; preview them as plain skin like in the game
        mat = bpy.data.materials.get("prev_skin") or bpy.data.materials.new("prev_skin")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (0.8, 0.6, 0.48, 1)
        bsdf.inputs["Roughness"].default_value = 0.6
        obj.data.materials.clear()
        obj.data.materials.append(mat)
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
    cam.data.ortho_scale = 1.1 * len(objs)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    px = int(os.environ.get("MH_PREVIEW_PX", "260"))
    scene.render.resolution_x = px * len(objs)
    scene.render.resolution_y = int(px * 1.15)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
