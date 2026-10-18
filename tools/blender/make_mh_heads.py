"""Tier head pack from MakeHuman (MPFB extension for Blender), Sub-3 .. True Adam.

Run headless (MPFB extension + MakeHuman system assets installed):
    blender --background --python tools/blender/make_mh_heads.py

For each tier a male human is generated with macro sliders (age / weight / muscle) and face
targets (head shape, jaw, chin, cheekbones, eyes, brows, nose, lips), the head is cut off at
the neck, eyes and eyebrows are joined in, and everything is packed into ONE mesh with ONE
texture atlas (Roblox MeshPart limit):
    rows 0 .. 0.75   skin, cropped from the MakeHuman body texture around the head
    rows 0.75..0.875 eye texture
    rows 0.875..1    eyebrow texture
Skin texels are made transparent by color distance, so the MeshPart Color (the player's skin
tone) shows through while lips / shading / eyes / brows stay painted.

Output: assets/heads/head_N_<tier>.fbx, atlas_N_<tier>.png, preview_mh.png, preview_mh_side.png
"""

import math
import os
import sys

import bmesh
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "heads")
ATLAS = 1024

MPFB = "bl_ext.user_default.mpfb"

# --------------------------------------------------------------- tier recipes
# macro: MakeHuman macro sliders (0..1). targets: face targets (name -> weight 0..1).
# A "-incr"/"-decr" pair is chosen by the sign helper below: t("chin-prominent", -0.6) etc.

def t(name, value):
    """Signed slider -> concrete MakeHuman target (incr/decr, up/down, in/out ...)."""
    pairs = [("-incr", "-decr"), ("-up", "-down"), ("-out", "-in"), ("-forward", "-backward"),
             ("-convex", "-concave")]
    for pos, neg in pairs:
        if name.endswith("|" + pos[1:]) or name.endswith(pos):
            base = name[: -len(pos)]
            return (base + (pos if value >= 0 else neg), abs(value))
    return (name, value)


def both(name, value):
    """Left + right version of a target (l-*/r-*)."""
    return [t("l-" + name, value), t("r-" + name, value)]


TIERS = [
    ("sub3", {"age": 0.72, "weight": 1.0, "muscle": 0.2}, [
        ("head-round", 0.9), ("head-fat-incr", 1.0), t("chin-prominent-incr", -0.8), t("chin-height-incr", -0.4),
        *both("cheek-volume-incr", 1.0), *both("cheek-bones-incr", -0.6), ("neck-double-incr", 1.0),
        *both("eye-bag-incr", 1.0), *both("eye-corner2-up", -0.7), *both("eye-scale-incr", -0.3),
        ("eyebrows-angle-up", 0.6), t("eyebrows-trans-up", 0.4), t("nose-scale-horiz-incr", 0.6), t("nose-volume-incr", 0.6),
        t("nose-point-up", -0.4), t("mouth-angles-up", -0.8), t("mouth-laugh-lines-out", 1.0), t("forehead-trans-forward", -0.3),
    ]),
    ("sub5", {"age": 0.55, "weight": 0.85, "muscle": 0.3}, [
        ("head-round", 0.7), ("head-fat-incr", 0.6), t("chin-prominent-incr", -0.5),
        *both("cheek-volume-incr", 0.6), *both("cheek-bones-incr", -0.4), ("neck-double-incr", 0.6),
        *both("eye-bag-incr", 0.6), *both("eye-corner2-up", -0.4), t("nose-volume-incr", 0.4),
        t("mouth-angles-up", -0.5), t("mouth-laugh-lines-out", 0.5),
    ]),
    ("ltn", {"age": 0.5, "weight": 0.65, "muscle": 0.4}, [
        ("head-oval", 0.4), ("head-round", 0.3), t("chin-prominent-incr", -0.25), *both("cheek-volume-incr", 0.3),
        *both("eye-bag-incr", 0.3), t("mouth-angles-up", -0.2),
    ]),
    ("mtn", {"age": 0.5, "weight": 0.5, "muscle": 0.5}, [
        ("head-oval", 0.7), t("chin-prominent-incr", 0.0), *both("cheek-bones-incr", 0.2),
    ]),
    ("htn", {"age": 0.48, "weight": 0.42, "muscle": 0.6}, [
        ("head-oval", 0.5), ("head-diamond", 0.3), t("chin-prominent-incr", 0.3), t("chin-width-incr", 0.2),
        *both("cheek-bones-incr", 0.5), *both("cheek-volume-incr", -0.3), *both("eye-corner2-up", 0.3),
        t("eyebrows-trans-up", -0.2), t("mouth-angles-up", 0.1),
    ]),
    ("chadlite", {"age": 0.48, "weight": 0.38, "muscle": 0.7}, [
        ("head-diamond", 0.4), ("head-square", 0.3), t("chin-prominent-incr", 0.5), t("chin-width-incr", 0.4),
        t("chin-bones-incr", 0.5), *both("cheek-bones-incr", 0.75), *both("cheek-volume-incr", -0.5),
        *both("eye-corner2-up", 0.5), *both("eye-height2-incr", -0.3), t("eyebrows-trans-down", 0.4),
        t("eyebrows-angle-down", 0.3), t("forehead-trans-forward", 0.2),
    ]),
    ("chad", {"age": 0.48, "weight": 0.35, "muscle": 0.8}, [
        ("head-diamond", 0.45), ("head-square", 0.4), t("chin-prominent-incr", 0.75), t("chin-width-incr", 0.6),
        t("chin-bones-incr", 0.8), t("chin-cleft-incr", 0.5), *both("cheek-bones-incr", 1.0), *both("cheek-volume-incr", -0.7),
        *both("eye-corner2-up", 0.75), *both("eye-height2-incr", -0.5), t("eyebrows-trans-down", 0.6),
        t("eyebrows-angle-down", 0.5), t("forehead-trans-forward", 0.35), t("nose-greek-incr", 0.3),
    ]),
    ("trueadam", {"age": 0.5, "weight": 0.3, "muscle": 0.9}, [
        ("head-diamond", 0.45), ("head-square", 0.35), ("head-scale-vert-incr", 0.15), ("head-scale-horiz-decr", 0.15), t("chin-prominent-incr", 1.0),
        t("chin-width-incr", 0.7), t("chin-height-incr", 0.5), t("chin-bones-incr", 1.0), t("chin-cleft-incr", 0.8),
        *both("cheek-bones-incr", 1.0), *both("cheek-volume-incr", -1.0), *both("cheek-inner-incr", -0.6),
        *both("eye-corner2-up", 1.0), *both("eye-height2-incr", -0.7), *both("eye-scale-incr", -0.15),
        t("eyebrows-trans-down", 0.85), t("eyebrows-angle-down", 0.7), t("forehead-trans-forward", 0.5),
        t("nose-greek-incr", 0.5), t("nose-scale-horiz-incr", -0.2), t("mouth-lowerlip-volume-incr", 0.3),
    ]),
]


def mpfb():
    hs = __import__(MPFB + ".services.humanservice", fromlist=["HumanService"]).HumanService
    ts = __import__(MPFB + ".services.targetservice", fromlist=["TargetService"]).TargetService
    ls = __import__(MPFB + ".services.locationservice", fromlist=["LocationService"]).LocationService
    return hs, ts, ls


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)


def build_human(macro, targets):
    HumanService, TargetService, _ = mpfb()
    macro_dict = TargetService.get_default_macro_info_dict()
    macro_dict.update({"gender": 1.0, "proportions": 0.6, "height": 0.5})
    macro_dict.update(macro)
    macro_dict["race"] = {"asian": 0.1, "caucasian": 0.8, "african": 0.1}
    basemesh = HumanService.create_human(macro_detail_dict=macro_dict, feet_on_ground=True, scale=0.1)
    missing = []
    for name, weight in targets:
        if weight <= 0.001:
            continue
        path = TargetService.target_full_path(name)
        if not path:
            missing.append(name)
            continue
        TargetService.load_target(basemesh, path, weight=weight, name=name)
    if missing:
        print("[mh] missing targets:", missing)
    return basemesh


def joint_z(obj, group):
    idx = obj.vertex_groups[group].index
    zs = [(obj.matrix_world @ v.co).z for v in obj.data.vertices
          if any(g.group == idx and g.weight > 0.5 for g in v.groups)]
    return sum(zs) / len(zs)


def cut_head(basemesh):
    """Bake the sliders into the mesh, drop helper geometry, keep the head above the neck."""
    _, TargetService, _ = mpfb()
    TargetService.bake_targets(basemesh)
    neck, head = joint_z(basemesh, "joint-neck"), joint_z(basemesh, "joint-head")
    cut = neck + (head - neck) * 0.1  # keep the whole chin + a short neck stump
    for mod in list(basemesh.modifiers):
        basemesh.modifiers.remove(mod)
    body = basemesh.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(basemesh.data)
    deform = bm.verts.layers.deform.active
    junk = [v for v in bm.verts if not (deform and body in v[deform] and v[deform][body] > 0.5)]
    bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut),
                           plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(basemesh.data)
    bm.free()
    basemesh.vertex_groups.clear()
    return cut, head


def shape_preview(obj, k):
    """Quick grey render of one head, front + side, to judge the shape while iterating."""
    scene = bpy.context.scene
    for poly in obj.data.polygons:
        poly.use_smooth = True
    xs = [(obj.matrix_world @ v.co) for v in obj.data.vertices]
    cz = (min(p.z for p in xs) + max(p.z for p in xs)) / 2
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 0.32
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 400, 400
    for tag, loc, rot in (("front", (0, -3, cz), (math.radians(90), 0, 0)),
                          ("side", (3, 0, cz), (math.radians(90), 0, math.radians(90)))):
        cam.location, cam.rotation_euler = loc, rot
        scene.render.filepath = os.path.join(OUT, f"_shape_{k}_{tag}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)


# skin texture and eyebrow asset per tier
LOOKS = {
    "sub3": ("old_caucasian_male", "eyebrow006"),
    "sub5": ("middleage_caucasian_male", "eyebrow007"),
    "ltn": ("young_caucasian_male2", "eyebrow010"),
    "mtn": ("young_caucasian_male", "eyebrow012"),
    "htn": ("young_caucasian_male", "eyebrow001"),
    "chadlite": ("young_caucasian_male", "eyebrow004"),
    "chad": ("young_caucasian_male", "eyebrow008"),
    "trueadam": ("young_caucasian_male", "eyebrow009"),
}


def data_path(*parts):
    _, _, LocationService = mpfb()
    return os.path.join(LocationService.get_user_data(), *parts)


def add_proxy(basemesh, mhclo, asset_type):
    HumanService, _, _ = mpfb()
    return HumanService.add_mhclo_asset(mhclo, basemesh, asset_type=asset_type, subdiv_levels=0,
                                        set_up_rigging=False, interpolate_weights=False,
                                        import_subrig=False, import_weights=False)


def freeze(obj):
    """Apply modifiers/shape keys of a fitted proxy and unparent it (keep world position)."""
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # make sure faces point outward (MakeHuman eye proxies can come in inside-out)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if "eyebrow" in obj.name:
        # sink the brow card into the skin so its untextured edge doesn't show as a ribbon
        bm.normal_update()
        for v in bm.verts:
            v.co -= v.normal * 0.0015
    bm.to_mesh(obj.data)
    bm.free()
    print(f"[mh] {obj.name}: {len(obj.data.vertices)} verts, uv {[u.name for u in obj.data.uv_layers]}")


def main():
    sys.path.insert(0, os.path.dirname(__file__))
    import mh_pack

    os.makedirs(OUT, exist_ok=True)
    only = os.environ.get("MH_ONLY")  # e.g. MH_ONLY=1,8 builds just those tiers while iterating
    done = []
    for k, (name, macro, targets) in enumerate(TIERS, start=1):
        if only and str(k) not in only.split(","):
            continue
        for obj in list(bpy.data.objects):
            if obj not in done and obj.type not in ("CAMERA", "LIGHT"):
                bpy.data.objects.remove(obj, do_unlink=True)
        skin_name, brow_name = LOOKS[name]
        basemesh = build_human(macro, targets)
        if os.environ.get("MH_SHAPE_PREVIEW"):
            cut_head(basemesh)
            shape_preview(basemesh, k)
            continue
        eyes = add_proxy(basemesh, data_path("eyes", "low-poly", "low-poly.mhclo"), "Eyes")
        brows = add_proxy(basemesh, data_path("eyebrows", brow_name, brow_name + ".mhclo"), "Eyebrows")
        freeze(eyes)
        freeze(brows)
        cut_head(basemesh)
        skin_dir = data_path("skins", skin_name)
        skin_png = os.path.join(skin_dir, next(f for f in os.listdir(skin_dir) if f.endswith(".png") and "diffuse" in f))
        head = mh_pack.pack(basemesh, eyes, brows, skin_png, data_path("eyes", "materials", "brown_eye.png"),
                            data_path("eyebrows", brow_name, brow_name + ".png"), f"head_{k}_{name}", OUT)
        head.name = f"head_{k}_{name}"
        mh_pack.normalize(head)
        mh_pack.export(head, os.path.join(OUT, f"head_{k}_{name}.fbx"))
        print(f"[mh] {name}: {len(head.data.vertices)} verts, {len(head.data.polygons)} faces")
        done.append(head)
    if done:
        mh_pack.render_row(done, os.path.join(OUT, "preview_mh.png"))
        mh_pack.render_row(done, os.path.join(OUT, "preview_mh_side.png"), side=True)
    print("[mh] all done")


if __name__ == "__main__":
    main()
