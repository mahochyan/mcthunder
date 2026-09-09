"""ART-001 pilot builder (M4A3 75W VVSS 1944, <=1000 tri bake pilot).
Stages (headless):
  blender --background authoring/vehicles/us_m4a3_75w_vvss_1944.blend --python-exit-code 1 \
    --python authoring/art001/build_and_bake.py -- --stage low
  blender --background authoring/art001/pilot.blend --python-exit-code 1 \
    --python authoring/art001/build_and_bake.py -- --stage high|cage|uv|bake|export
Never calls build_models.py. Works only on the pilot copy.
"""
import bpy
import bmesh
import json
import math
import sys
import hashlib
import time
from mathutils import Vector, Matrix
from pathlib import Path

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
STAGE = argv[argv.index("--stage") + 1] if "--stage" in argv else "low"
SIZE = 1024
_self = Path(__file__).resolve()
ART = _self.parent                     # authoring/art001
PROJECT = ART.parents[1]               # repo root
OUT = PROJECT / "assets" / "art001" / "m4a3_pilot"
BLEND = ART / "pilot.blend"
GROUPS = ["hull", "turret", "gun", "wheels", "tracks"]

VEH = {"reference_length_m": 6.2738, "width_m": 2.667, "track_width": 0.42,
       "wheel_radius": 0.36, "barrel_length": 1.65}
TRACK_CX = VEH["width_m"] * 0.5 - VEH["track_width"] * 0.5
TRACK_STRAIGHT = VEH["reference_length_m"] * 0.804
TRACK_R = 0.52
TRACK_CY = 0.56
TOP_Y = 1.08
END_Z = TRACK_STRAIGHT * 0.5
ROAD_Y = 0.41
BOGIE_Z = [-1.6, 0.0, 1.6]
PAIR = 0.42

def coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c

def find_parent(name):
    o = bpy.data.objects.get(name)
    if o is None or o.type != 'EMPTY':
        raise RuntimeError("missing parent empty " + name)
    return o

def tri_count(ob):
    n = 0
    for p in ob.data.polygons:
        n += len(p.vertices) - 2
    return n

def mesh_obj(name, verts, faces, parent, collection, group, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    ob.parent = parent
    # 源 GLB 约定：空载偏移、子件局部恒等、顶点部件局部（勿用 parent_inverse 补偿）
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob["art_group"] = group
    me.materials.append(mat)
    print("ART001 mesh_obj %s verts=%d faces=%d tris=%d" % (name, len(me.vertices), len(me.polygons), sum(len(p.vertices)-2 for p in me.polygons)))
    return ob

def principled(nt):
    n = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if n is None:
        raise RuntimeError("Principled BSDF not found")
    return n

def low_materials():
    mats = {}
    spec = {"ART001_Olive": ((0.384, 0.427, 0.286), 0.78, 0.10),
            "ART001_Rubber": ((0.145, 0.165, 0.145), 0.95, 0.0),
            "ART001_Steel": ((0.333, 0.361, 0.314), 0.5, 0.75),
            "ART001_Dark": ((0.188, 0.216, 0.173), 0.85, 0.05)}
    for name, (col, rough, metal) in spec.items():
        m = bpy.data.materials.get(name)
        if m is None:
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            b = principled(m.node_tree)
            b.inputs["Base Color"].default_value = (*col, 1.0)
            b.inputs["Roughness"].default_value = rough
            b.inputs["Metallic"].default_value = metal
            m.use_backface_culling = False
        mats[name] = m
    return mats

def fix_normals_islands(ob):
    """Per connected island: keep normals outward (island signed-volume > 0)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    seen = set()
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        island = []
        stack = [f0]
        while stack:
            f = stack.pop()
            if f.index in seen:
                continue
            seen.add(f.index)
            island.append(f)
            for e in f.edges:
                for lf in e.link_faces:
                    if lf.index not in seen:
                        stack.append(lf)
        vol = sum(fc.calc_center_median().dot(fc.normal) for fc in island)
        if vol < 0:
            for fc in island:
                fc.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()

def radial_for(p):
    if abs(p.z) < END_Z - 0.2:
        return Vector((0, -1 if p.y < 0.6 else 1, 0))
    return Vector((0, p.y - TRACK_CY, p.z - math.copysign(END_Z, p.z))).normalized()

def loop_points(n_bottom=8, n_curve=6):
    pts = []
    for i in range(n_bottom):
        pts.append(Vector((0, 0.075, END_Z - i * TRACK_STRAIGHT / (n_bottom - 1))))
    for i in range(1, n_curve):
        a = -i * (math.pi / 2) / n_curve
        pts.append(Vector((0, TRACK_CY + math.sin(a) * TRACK_R, -END_Z + math.cos(a) * TRACK_R)))
    for i in range(n_bottom):
        pts.append(Vector((0, TOP_Y, -END_Z + i * TRACK_STRAIGHT / (n_bottom - 1))))
    for i in range(1, n_curve):
        a = i * (math.pi / 2) / n_curve
        pts.append(Vector((0, TRACK_CY + math.sin(a) * TRACK_R, END_Z - math.cos(a) * TRACK_R)))
    return pts

# ---------------- stage low ----------------
def rot_tube(verts):
    """炮管构建子约定轴向 -Z → 世界 +Y（前向）：旋转 (x,y,z)->(x,-z,y)，det=+1。"""
    return [Vector((v.x, -v.z, v.y)) for v in verts]

def swap_yz(verts):
    """构建器 y=高/z=长 子约定 → 世界 y=长/z=高：(x,y,z)->(x,z,y)。
    镜像（det=-1）会翻转绕序，由 fix_normals_islands 按岛修正朝向。"""
    return [Vector((v.x, v.z, v.y)) for v in verts]

def stage_low():
    low = coll("LOW")
    high = coll("HIGH")
    cage = coll("CAGE")
    # 幂等：清掉上次构建残留的 LOW/HIGH/CAGE 网格（父空节点保留）
    for c in (low, high, cage):
        for o in list(c.objects):
            data = o.data
            bpy.data.objects.remove(o)
            if data is not None:
                bpy.data.meshes.remove(data)
    coll("HIGH")
    coll("CAGE")
    hull = find_parent("hull")
    turret = find_parent("turret")
    barrel = find_parent("barrel")
    M = low_materials()

    # 1. armor shell quads (exact layout alignment; skip floor) — 按部件拆分（炮塔壳须随炮塔旋转）
    shells = {"hull": ([], []), "turret": ([], []), "barrel": ([], [])}
    plates = {"hull": 0, "turret": 0, "barrel": 0}
    for ob in list(bpy.data.objects):
        if ob.type != 'MESH' or not ob.name.startswith("Armor_"):
            continue
        zone = str(ob.get("armor_zone", ""))
        if "floor" in zone:
            continue
        part = ob.parent.name
        if part not in shells:
            continue
        offset = ob.parent.matrix_world.to_translation()
        mw = ob.matrix_world
        # Armor 网格 = 扇形三角化（中心点+边缘点，如炮塔顶=10 边形）。
        # 旧实现取前 4 顶点拼一个四边形：对围墙凑效，对多边形顶盖只保留一小块。
        # 正确做法：按共享中心点重组扇形（顶点共享 → 壳体保持连通岛，UV 利用率正常），
        # 逐扇形按 ref 向量定向。
        tris = [(list(p.vertices)) for p in ob.data.polygons if len(p.vertices) == 3]
        if not tris:
            continue
        # 找扇形中心：出现在该网格全部三角形中的顶点（每网格一个扇形）
        common = set(tris[0])
        for t in tris[1:]:
            common &= set(t)
        if len(common) != 1:
            raise RuntimeError("armor mesh is not a single fan: %s (common=%d)" % (ob.name, len(common)))
        c = common.pop()
        rim_pairs = []
        for t in tris:
            ab = [i for i in t if i != c]
            rim_pairs.append((ab[0], ab[1]))
        # 沿邻接走边缘环：a->b, 找下一对以 b 开头的边
        adj = {}
        for a, b in rim_pairs:
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        start = rim_pairs[0][0]
        rim = [start]
        prev = None
        while True:
            nxts = [x for x in adj[rim[-1]] if x != prev]
            if not nxts:
                break
            prev = rim[-1]
            rim.append(nxts[0])
            if rim[-1] == start:
                rim.pop()
                break
        base = len(shells[part][0])
        cw = ob.matrix_world
        fan_corners = [(cw @ ob.data.vertices[i].co) - offset for i in [c] + rim]
        fan_center = sum(fan_corners[1:], Vector()) / float(len(rim))
        n = (fan_corners[1] - fan_corners[0]).cross(fan_corners[2] - fan_corners[0])
        if n.length < 1e-9:
            continue
        n.normalize()
        ref = Vector((0.0, 0.9, 0.0)) if part in ("hull", "turret") else Vector((0.0, 0.5, -0.3))
        flip = n.dot(fan_center - ref) < 0
        shells[part][0].extend([v.copy() for v in fan_corners])
        m = len(rim)
        for i in range(m):
            a, b = (1 + i, 1 + (i + 1) % m)
            if flip:
                b, a = a, b
            shells[part][1].append([base, base + a, base + b])
        plates[part] += 1
    shell_mat = {"hull": "ART001_Olive", "turret": "ART001_Olive", "barrel": "ART001_Olive"}
    for part, (vs, fs) in shells.items():
        shell = mesh_obj("LOW_%s_Shell" % part, vs, fs, find_parent(part), low, part if part != "barrel" else "gun", M[shell_mat[part]])
    print("ART001 shell plates:", plates)

    # 2. gun tube (12-gon tapered open tube + muzzle ring + bore disc)
    verts, faces = [], []
    z0, z1, r0, r1, seg = -0.30, -1.66, 0.115, 0.075, 12
    for i in range(seg):
        a = 2 * math.pi * i / seg
        verts.append(Vector((math.cos(a) * r0, math.sin(a) * r0, z0)))
    for i in range(seg):
        a = 2 * math.pi * i / seg
        verts.append(Vector((math.cos(a) * r1, math.sin(a) * r1, z1)))
    for i in range(seg):
        j = (i + 1) % seg
        faces.append([i, j, seg + j, seg + i])
    ring = len(verts)
    for i in range(seg):
        a = 2 * math.pi * i / seg
        verts.append(Vector((math.cos(a) * (r1 + 0.02), math.sin(a) * (r1 + 0.02), z1)))
    for i in range(seg):
        j = (i + 1) % seg
        faces.append([seg + i, seg + j, ring + j, ring + i])
    bore = len(verts)
    verts.append(Vector((0, 0, z1 + 0.03)))
    for i in range(1, seg - 1):
        faces.append([ring + i, ring + i + 1, bore])
    tube = mesh_obj("LOW_gun_Tube", rot_tube(verts), faces, barrel, low, "gun", M["ART001_Steel"])

    # 3. wheels (single-sided discs; material double-sided)
    verts, faces = [], []
    def disc(cy, cz, cx, r, nseg):
        base = len(verts)
        for i in range(nseg):
            a = 2 * math.pi * i / nseg
            verts.append(Vector((cx, cy + math.sin(a) * r, cz + math.cos(a) * r)))
        center = len(verts)
        verts.append(Vector((cx, cy, cz)))
        for i in range(1, nseg - 1):
            faces.append([base, base + i + 1, base + i])
    for side in (-1, 1):
        cx = side * TRACK_CX
        for bz in BOGIE_Z:
            for off in (-PAIR / 2, PAIR / 2):
                disc(ROAD_Y, bz + off, cx, VEH["wheel_radius"], 10)
        for z in (-END_Z, END_Z):
            disc(0.56, z, cx, 0.45, 10)
        for bz in BOGIE_Z:
            disc(0.98, bz + 0.4, cx, 0.11, 6)
    wheels = mesh_obj("LOW_wheels", swap_yz(verts), faces, hull, low, "wheels", M["ART001_Rubber"])

    # 4. track bands: closed rectangular tube (4 rings x loop)
    verts, faces = [], []
    path = loop_points()
    n = len(path)
    w_half = VEH["track_width"] * 0.5
    thick = 0.0375
    for side in (-1, 1):
        x_out = side * (TRACK_CX + w_half)
        x_in = side * (TRACK_CX - w_half)
        corners = {}
        for tag, (xr, rr) in {"A": (x_out, thick), "B": (x_out, -thick),
                              "C": (x_in, -thick), "D": (x_in, thick)}.items():
            base = len(verts)
            for p in path:
                r = radial_for(p)
                verts.append(Vector((xr, p.y + r.y * rr, p.z + r.z * rr)))
            corners[tag] = base
        for i in range(n):
            j = (i + 1) % n
            faces.append([corners["A"] + i, corners["A"] + j, corners["B"] + j, corners["B"] + i])
            faces.append([corners["B"] + i, corners["B"] + j, corners["C"] + j, corners["C"] + i])
            faces.append([corners["C"] + i, corners["C"] + j, corners["D"] + j, corners["D"] + i])
            faces.append([corners["D"] + i, corners["D"] + j, corners["A"] + j, corners["A"] + i])
    tracks = mesh_obj("LOW_tracks", swap_yz(verts), faces, hull, low, "tracks", M["ART001_Steel"])

    # 5. hatches + cupola
    verts, faces = [], []
    def fdisc(cx, cy, cz, r, nseg):
        base = len(verts)
        for i in range(nseg):
            a = 2 * math.pi * i / nseg
            verts.append(Vector((cx + math.cos(a) * r, cy, cz + math.sin(a) * r)))
        center = len(verts)
        verts.append(Vector((cx, cy, cz)))
        for i in range(1, nseg - 1):
            faces.append([base, base + i, base + i + 1])
    for side in (-0.62, 0.62):
        fdisc(side, 1.885, -1.16, 0.36, 10)
    fdisc(0.0, 1.885, 2.35, 0.3, 10)
    hatches = mesh_obj("LOW_hull_Hatches", swap_yz(verts), faces, hull, low, "hull", M["ART001_Olive"])

    verts, faces = [], []
    cy0, cy1, cr, cxx, czz = 0.72, 0.97, 0.36, -0.43, 0.45
    for i in range(8):
        a = 2 * math.pi * i / 8
        verts.append(Vector((cxx + math.cos(a) * cr, cy0, czz + math.sin(a) * cr)))
    for i in range(8):
        a = 2 * math.pi * i / 8
        verts.append(Vector((cxx + math.cos(a) * cr, cy1, czz + math.sin(a) * cr)))
    for i in range(8):
        j = (i + 1) % 8
        faces.append([i, j, 8 + j, 8 + i])
    center = len(verts)
    verts.append(Vector((cxx, cy1, czz)))
    for i in range(1, 7):
        faces.append([8, 8 + i, 8 + i + 1])
    for i in range(10):
        a = 2 * math.pi * i / 10
        verts.append(Vector((0.42 + math.cos(a) * 0.29, 0.725, 0.21 + math.sin(a) * 0.29)))
    hc = len(verts)
    verts.append(Vector((0.42, 0.725, 0.21)))
    for i in range(1, 9):
        faces.append([16 + 8, 16 + 8 + i, 16 + 8 + i + 1])
    cupola = mesh_obj("LOW_turret_Cupola", swap_yz(verts), faces, turret, low, "turret", M["ART001_Olive"])

    for o in low.objects:
        fix_normals_islands(o)
    total = sum(tri_count(o) for o in low.objects)
    print("ART001_LOW_TOTAL_TRIS=%d" % total)
    for o in low.objects:
        print("  %s tris=%d group=%s" % (o.name, tri_count(o), o.get("art_group")))
    if total > 1000:
        raise RuntimeError("LOW budget exceeded: %d" % total)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print("ART001_LOW_STAGE_PASS")


# ---------------- stage high ----------------
def group_low_objects():
    by_group = {}
    for o in coll("LOW").objects:
        by_group.setdefault(o.get("art_group", "hull"), []).append(o)
    return by_group

def stage_high():
    low = coll("LOW")
    high = coll("HIGH")
    # idempotent: clear previous HIGH objects
    for o in list(high.objects):
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if me is not None:
            bpy.data.meshes.remove(me)
    hull = find_parent("hull")
    turret = find_parent("turret")
    M = low_materials()

    def join_into(target, extra):
        bpy.ops.object.select_all(action='DESELECT')
        target.select_set(True)
        extra.select_set(True)
        bpy.context.view_layer.objects.active = target
        print("ART001 join %s += %s (extra_tris=%d)" % (target.name, extra.name, sum(len(p.vertices)-2 for p in extra.data.polygons)))
        res = bpy.ops.object.join()
        print("ART001 join result:", res, "target_tris=%d" % sum(len(p.vertices)-2 for p in target.data.polygons))
        if 'FINISHED' not in res:
            raise RuntimeError("join failed for " + target.name)
        return target

    def copy_low(ob, name):
        h = ob.copy()
        h.data = ob.data.copy()
        h.name = name
        h["art_group"] = ob["art_group"]
        high.objects.link(h)
        h.parent = ob.parent
        h.matrix_parent_inverse = ob.matrix_parent_inverse.copy()
        return h

    def frustum(verts, faces, center, r0, r1, h, seg, axis='x'):
        """Truncated cone along axis; sloped wall bakes tangent detail under axial rays."""
        base = len(verts)
        for rr, half in ((r0, -h * 0.5), (r1, h * 0.5)):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                if axis == 'x':
                    verts.append(Vector((center.x + half, center.y + math.cos(a) * rr, center.z + math.sin(a) * rr)))
                else:
                    verts.append(Vector((center.x + math.cos(a) * rr, center.y + half, center.z + math.sin(a) * rr)))
        for i in range(seg):
            j = (i + 1) % seg
            faces.append([base + i, base + j, base + seg + j, base + seg + i])
        cap = len(verts)
        if axis == 'x':
            verts.append(Vector((center.x + h * 0.5, center.y, center.z)))
        else:
            verts.append(Vector((center.x, center.y + h * 0.5, center.z)))
        for i in range(1, seg - 1):
            faces.append([base + seg, base + seg + i, base + seg + i + 1])

    def box(verts, faces, center, size, rot_z=0.0):
        base = len(verts)
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    v = Vector((center.x + sx * size.x * 0.5, center.y + sy * size.y * 0.5, center.z + sz * size.z * 0.5))
                    if rot_z:
                        d = v - center
                        v = center + Vector((d.x * math.cos(rot_z) - d.y * math.sin(rot_z), d.x * math.sin(rot_z) + d.y * math.cos(rot_z), d.z))
                    verts.append(v)
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4), (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6)]
        for q in quads:
            faces.append([base + q[0], base + q[1], base + q[2], base + q[3]])

    def tube_ring(verts, faces, center, r, seg, axis_len, axis='x'):
        base = len(verts)
        for half in (-axis_len * 0.5, axis_len * 0.5):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                if axis == 'x':
                    verts.append(Vector((center.x + half, center.y + math.cos(a) * r, center.z + math.sin(a) * r)))
                else:
                    verts.append(Vector((center.x + math.cos(a) * r, center.y + half, center.z + math.sin(a) * r)))
        for i in range(seg):
            j = (i + 1) % seg
            faces.append([base + i, base + j, base + seg + j, base + seg + i])
        return base

    # hull details: bolts (chamfered, bake-visible), grille slats, lamps, MG, hooks, deflectors
    verts, faces = [], []
    for side in (-1, 1):
        x = side * (VEH["width_m"] * 0.5 - 0.02)
        for i in range(14):
            z = -2.6 + i * 0.4
            frustum(verts, faces, Vector((x, 0.95, z)), 0.03, 0.016, 0.03, 6, axis='x')
        for i in range(8):
            z = -2.3 + i * 0.62
            frustum(verts, faces, Vector((side * 0.9, 1.9, z)), 0.026, 0.014, 0.025, 6, axis='y')
    for sx in (-0.56, 0.56):
        for i in range(15):
            box(verts, faces, Vector((sx, 1.888, 0.95 + i * 0.072)), Vector((0.9, 0.006, 0.032)))
    box(verts, faces, Vector((0, 1.9, 2.2)), Vector((1.75, 0.03, 0.05)))
    for side in (-1, 1):
        frustum(verts, faces, Vector((side * 0.85, 1.78, -2.5)), 0.15, 0.09, 0.1, 12)
        box(verts, faces, Vector((side * 0.85, 1.72, -2.6)), Vector((0.1, 0.12, 0.08)))
    box(verts, faces, Vector((0.66, 1.5, -2.1)), Vector((0.12, 0.12, 0.3)))
    tube_ring(verts, faces, Vector((0.66, 1.48, -2.42)), 0.028, 8, 0.5, axis='z')
    for side in (-1, 1):
        box(verts, faces, Vector((side * 0.55, 1.05, 2.95)), Vector((0.12, 0.2, 0.3)))
        box(verts, faces, Vector((side * 0.72, 0.82, 2.72)), Vector((0.16, 0.18, 0.12)))
    for side in (-1, 1):
        box(verts, faces, Vector((side * 0.62, 1.98, -1.05)), Vector((0.2, 0.06, 0.14)))
    high_hull = copy_low(bpy.data.objects["LOW_hull_Shell"], "HIGH_hull_Shell")
    hh = mesh_obj("HIGH_hull_Detail", verts, faces, hull, high, "hull", M["ART001_Steel"])
    # merge detail into the high hull mesh for one-object bakes
    join_into(high_hull, hh)
    copy_low(bpy.data.objects["LOW_turret_Shell"], "HIGH_turret_Shell")
    copy_low(bpy.data.objects["LOW_barrel_Shell"], "HIGH_gun_Shell")

    # turret details: cupola vision slots, pistol port, lifting eyes, antenna mount
    verts, faces = [], []
    for i in range(6):
        a = i * math.pi / 3
        box(verts, faces, Vector((-0.43 + math.cos(a) * 0.34, 0.9, 0.45 + math.sin(a) * 0.34)), Vector((0.1, 0.07, 0.08)), rot_z=-a)
    box(verts, faces, Vector((0.62, 0.6, -0.75)), Vector((0.16, 0.1, 0.22)))
    for pos in ((0.2, 0.75, -0.7), (-0.3, 0.75, 0.9)):
        tube_ring(verts, faces, Vector((pos[0], pos[1], pos[2])), 0.03, 8, 0.02)
    high_turret = copy_low(bpy.data.objects["LOW_turret_Cupola"], "HIGH_turret_Cupola")
    ht = mesh_obj("HIGH_turret_Detail", verts, faces, turret, high, "turret", M["ART001_Dark"])
    join_into(high_turret, ht)

    # gun details: mantlet steps + muzzle lip
    verts, faces = [], []
    for i in range(7):
        y = (i - 3) * 0.08
        box(verts, faces, Vector((0, y, -0.10 - 0.09 * (1 - abs(i - 3) / 3))), Vector((1.05 - abs(i - 3) * 0.055, 0.08, 0.25)))
    tube_ring(verts, faces, Vector((0, 0, -1.66)), 0.09, 16, 0.04)
    high_gun = copy_low(bpy.data.objects["LOW_gun_Tube"], "HIGH_gun_Tube")
    hg = mesh_obj("HIGH_gun_Detail", verts, faces, find_parent("barrel"), high, "gun", M["ART001_Olive"])
    join_into(high_gun, hg)

    # wheels: hub + bolts per disc (explicit specs, same params as LOW)
    verts, faces = [], []
    disc_specs = []
    for side in (-1, 1):
        cx = side * TRACK_CX
        for bz in BOGIE_Z:
            for off in (-PAIR / 2, PAIR / 2):
                disc_specs.append((cx, ROAD_Y, bz + off, VEH["wheel_radius"]))
        for z in (-END_Z, END_Z):
            disc_specs.append((cx, 0.56, z, 0.45))
        for bz in BOGIE_Z:
            disc_specs.append((cx, 0.98, bz + 0.4, 0.11))
    for cx, cy, cz, r in disc_specs:
        frustum(verts, faces, Vector((cx, cy, cz)), r * 0.55, r * 0.32, 0.05, 10, axis='x')
        for i in range(8):
            a = 2 * math.pi * i / 8
            frustum(verts, faces, Vector((cx, cy + math.sin(a) * r * 0.75, cz + math.cos(a) * r * 0.75)), 0.024, 0.013, 0.022, 6, axis='x')
    print("ART001 wheel detail verts=%d faces=%d" % (len(verts), len(faces)))
    hw = copy_low(bpy.data.objects["LOW_wheels"], "HIGH_wheels")
    hwd = mesh_obj("HIGH_wheels_Detail", verts, faces, hull, high, "wheels", M["ART001_Steel"])
    join_into(hw, hwd)
    # tracks: pads + guide teeth per loop segment
    verts, faces = [], []
    path = loop_points()
    n = len(path)
    for side in (-1, 1):
        x = side * (TRACK_CX + VEH["track_width"] * 0.5)
        for i in range(n):
            p = path[i]
            r = radial_for(p)
            nrm = Vector((0, r.y, r.z))
            tang = Vector((0, -r.z, r.y))
            c0 = Vector((x, p.y, p.z)) + nrm * 0.0385
            b0 = len(verts)
            for sgn1 in (-1, 1):
                for sgn2 in (-1, 1):
                    verts.append(c0 + Vector((sgn1 * 0.15, 0, 0)) + tang * (sgn2 * 0.045))
            for sgn1 in (-1, 1):
                for sgn2 in (-1, 1):
                    verts.append(c0 + nrm * 0.02 + Vector((sgn1 * 0.1, 0, 0)) + tang * (sgn2 * 0.025))
            quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4), (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6)]
            for q in quads:
                faces.append([b0 + q[0], b0 + q[1], b0 + q[2], b0 + q[3]])
            if i % 2 == 0:
                box(verts, faces, Vector((side * (TRACK_CX - VEH["track_width"] * 0.5 - 0.03), p.y, p.z)), Vector((0.06, 0.05, 0.09)))
    htr = copy_low(bpy.data.objects["LOW_tracks"], "HIGH_tracks")
    htd = mesh_obj("HIGH_tracks_Detail", verts, faces, hull, high, "tracks", M["ART001_Dark"])
    join_into(htr, htd)

    for o in high.objects:
        fix_normals_islands(o)
    # 源/目标材质隔离：高模统一改用私有材质副本（ART001_SRC_*），
    # 烘焙目标图像节点（挂在低模材质上）不会进入源着色读取路径
    for o in high.objects:
        for i, m in enumerate(o.data.materials):
            if m is None:
                continue
            base = m.name.replace("ART001_SRC_", "")
            hm = bpy.data.materials.get("ART001_SRC_" + base)
            if hm is None:
                hm = m.copy()
                hm.name = "ART001_SRC_" + base
            o.data.materials[i] = hm
    total = sum(tri_count(o) for o in high.objects)
    print("ART001_HIGH_TOTAL_TRIS=%d" % total)
    for o in high.objects:
        print("  %s tris=%d group=%s" % (o.name, tri_count(o), o.get("art_group")))
    if total > 220000:
        raise RuntimeError("HIGH over pilot cost cap: %d" % total)
    bpy.ops.wm.save_mainfile()
    print("ART001_HIGH_STAGE_PASS")


# ---------------- stage cage ----------------
def stage_cage():
    cage = coll("CAGE")
    for o in list(cage.objects):
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if me is not None:
            bpy.data.meshes.remove(me)
    offsets = {"hull": 0.03, "turret": 0.03, "gun": 0.03, "wheels": 0.02, "tracks": 0.02}
    for low_ob in list(coll("LOW").objects):
        c = low_ob.copy()
        c.data = low_ob.data.copy()
        c.name = "CAGE_" + low_ob.name
        cage.objects.link(c)
        c.parent = low_ob.parent
        c.matrix_parent_inverse = low_ob.matrix_parent_inverse.copy()
        c["art_group"] = low_ob["art_group"]
        off = offsets[low_ob.get("art_group", "hull")]
        bm = bmesh.new()
        bm.from_mesh(c.data)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * off
        bm.to_mesh(c.data)
        bm.free()
    total = sum(tri_count(o) for o in cage.objects)
    print("ART001_CAGE objects=%d tris=%d" % (len(cage.objects), total))
    bpy.ops.wm.save_mainfile()
    print("ART001_CAGE_STAGE_PASS")


# ---------------- stage uv ----------------
def stage_uv():
    low = coll("LOW").objects
    bpy.ops.object.select_all(action='DESELECT')
    for o in low:
        o.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["LOW_hull_Shell"]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.03, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    # uv layout png: rasterize island edges into an image
    size = 512
    img = bpy.data.images.new("uv_layout", size, size, alpha=True)
    px = [0.08, 0.08, 0.08, 1.0] * (size * size)
    for ob in low:
        me = ob.data
        uvlay = me.uv_layers.active
        if uvlay is None:
            continue
        for poly in me.polygons:
            for li in poly.loop_indices:
                pass
        for li_a in range(len(me.loops)):
            pass
        idx = uvlay.data
        for poly in me.polygons:
            loops = [poly.loop_start + k for k in range(poly.loop_total)]
            pts = [idx[l].uv for l in loops]
            for k in range(len(pts)):
                a, b = pts[k], pts[(k + 1) % len(pts)]
                steps = 8
                for s in range(steps):
                    t = s / steps
                    u, v = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                    xi, yi = int(u * size) % size, int(v * size) % size
                    o4 = (yi * size + xi) * 4
                    px[o4] = 0.9; px[o4 + 1] = 0.85; px[o4 + 2] = 0.2; px[o4 + 3] = 1.0
    img.pixels = px
    img.filepath_raw = str(ART / "uv_layout.png")
    img.file_format = 'PNG'
    img.save()
    bpy.ops.wm.save_mainfile()
    print("ART001_UV_STAGE_PASS")


# ---------------- stage bake ----------------
def ensure_image(name, path, fill, colorspace):
    old = bpy.data.images.get(name)
    if old is not None:
        bpy.data.images.remove(old)  # 悬空文件引用的旧 datablock 会让像素写入失败，一律重建
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    # 顺序关键：先设色彩空间再填像素——生成图像在填色后改色彩空间会清空缓冲
    img.colorspace_settings.name = colorspace
    img.scale(SIZE, SIZE)
    px = (list(fill[:3]) + [1.0]) * (SIZE * SIZE)
    img.pixels = px
    # 注意：烘焙期间不得设置 filepath_raw——文件尚不存在时烘焙会尝试从磁盘重载导致黑缓冲
    return img

def save_img(img, path):
    img.filepath_raw = str(path)
    img.file_format = 'PNG'
    img.save()

def low_target_node(low_ob, img):
    m = low_ob.data.materials[0]
    nt = m.node_tree
    node = None
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE':
            node = n
            break
    if node is None:
        node = nt.nodes.new("ShaderNodeTexImage")
        nt.links.new(node.outputs["Color"], principled(nt).inputs["Base Color"])
    node.image = img
    node.select = True
    nt.nodes.active = node
    return m

def select_group(group, active_ob):
    bpy.ops.object.select_all(action='DESELECT')
    for o in coll("HIGH").objects:
        if o.get("art_group", "") == group:
            o.select_set(True)
    active_ob.select_set(True)
    bpy.context.view_layer.objects.active = active_ob

def setup_cycles(samples):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = False

def install_emis(materials):
    """在给定材质上安装临时 Emission 输出（R=roughness G=metallic），返回恢复清单。
    必须与 restore_emis 成对使用（调用侧 try/finally）。"""
    state = []
    for m in materials:
        nt = m.node_tree
        out_node = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output), None)
        bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if out_node is None or bsdf is None:
            continue
        rough = bsdf.inputs["Roughness"].default_value
        metal = bsdf.inputs["Metallic"].default_value
        emis = nt.nodes.new('ShaderNodeEmission')
        emis.inputs["Color"].default_value = (rough, metal, 0.0, 1.0)
        new_out = nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(emis.outputs["Emission"], new_out.inputs["Surface"])
        new_out.is_active_output = True
        out_node.is_active_output = False
        state.append((nt, out_node, new_out, emis))
    return state

def restore_emis(state):
    for nt, out_node, new_out, emis in state:
        new_out.is_active_output = False
        out_node.is_active_output = True
        nt.nodes.remove(new_out)
        nt.nodes.remove(emis)

def set_group_visible(group):
    """AO 隔离：全场景只保留目标组的源（HIGH）与目标（LOW）可见。
    隐藏其它组（零姿态炮塔/火炮等运动件）、源 .blend 遗留几何（Armor_*/Cosmetic_*）
    与其它 CAGE；被 cage_object 引用的笼由烘焙自动排除，可见性无影响。"""
    keep = set()
    for o in coll("HIGH").objects:
        if o.get("art_group", "") == group:
            keep.add(o.name)
    for o in coll("LOW").objects:
        if o.get("art_group", "") == group:
            keep.add(o.name)
    for o in bpy.data.objects:
        vis = o.name in keep
        o.hide_render = not vis
        o.hide_set(not vis)

def set_all_visible():
    for o in bpy.data.objects:
        o.hide_render = False
        o.hide_set(False)

def stage_bake():
    OUT.mkdir(parents=True, exist_ok=True)
    setup_cycles(1)
    # 清除跨 run 残留的图像节点与悬空图像 datablock，保证每材质单图像节点
    for m in bpy.data.materials:
        if m.name.startswith("ART001_"):
            for n in list(m.node_tree.nodes):
                if n.type == 'TEX_IMAGE':
                    m.node_tree.nodes.remove(n)
    for im in list(bpy.data.images):
        if im.name.startswith("ART001_"):
            bpy.data.images.remove(im)
    paths = {k: OUT / f for k, f in {
        "normal": "normal_gl.png", "ao": "ao_tmp.png", "albedo": "basecolor.png",
        "orm_mask": "orm_mask_tmp.png"}.items()}
    imgs = {
        "normal": ensure_image("ART001_n", paths["normal"], (0.5, 0.5, 1.0), 'Non-Color'),
        "ao": ensure_image("ART001_ao", paths["ao"], (1.0, 1.0, 1.0), 'Non-Color'),
        "albedo": ensure_image("ART001_alb", paths["albedo"], (1.0, 1.0, 1.0), 'sRGB'),
        "orm_mask": ensure_image("ART001_orm", paths["orm_mask"], (0.0, 0.0, 0.0), 'Non-Color'),
    }
    import numpy as _np0
    _chk = _np0.array(imgs["ao"].pixels[:], dtype=_np0.float32).reshape(-1, 4)
    print("ART001 AOINIT ao_mean=%.4f size=%d" % (_chk[:, 0].mean(), imgs["ao"].size[0]))
    # AO distance probe (set if the engine exposes it)
    cyc = bpy.context.scene.cycles
    for name in dir(cyc):
        if 'ao' in name.lower():
            print("ART001 cycles.%s = %s" % (name, getattr(cyc, name)))

    timings = {}
    for group in GROUPS:
        lows = [o for o in coll("LOW").objects if o.get("art_group", "") == group]
        highs = [o for o in coll("HIGH").objects if o.get("art_group", "") == group]
        if not lows or not highs:
            raise RuntimeError("missing source group: %s (lows=%d highs=%d)" % (group, len(lows), len(highs)))
        cages = {o.name: "CAGE_" + o.name for o in lows}
        src_mats = []
        for o in highs:
            for m in o.data.materials:
                if m is not None and m not in src_mats:
                    src_mats.append(m)
        for low_ob in lows:
            if not low_ob.data.uv_layers:
                raise RuntimeError("missing UV: " + low_ob.name)
            passes = [("normal", 'NORMAL', 1, False), ("ao", 'AO', 16, True), ("albedo", 'DIFFUSE', 1, False), ("orm_mask", 'EMIT', 1, False)]
            for key, btype, samples, isolated in passes:
                img = imgs[key]
                low_target_node(low_ob, img)
                select_group(group, low_ob)
                sc = bpy.context.scene
                sc.cycles.samples = samples
                # AO 遍做运动部件隔离：其它组（零姿态炮塔/火炮）不参与遮挡
                if isolated:
                    set_group_visible(group)
                filter_kw = {}
                emis_state = []
                try:
                    if btype == 'DIFFUSE':
                        filter_kw = {"pass_filter": {'COLOR'}}  # 只烘颜色，不含直接/间接光
                    if btype == 'EMIT':
                        emis_state = install_emis(src_mats)  # 仅此遍临时 Emission（R=rough G=metal）
                    t0 = time.time()
                    res = bpy.ops.object.bake(
                        type=btype, use_selected_to_active=True,
                        normal_space='TANGENT', normal_r='POS_X', normal_g='POS_Y', normal_b='POS_Z',
                        use_cage=True, cage_object=cages[low_ob.name],
                        use_clear=False, margin=8, target='IMAGE_TEXTURES',
                        max_ray_distance=0.25 if isolated else 0.0,  # 高低模经笼投射线距离（远大于笼偏移 0.02-0.03），非 AO 遮挡半径
                        **filter_kw)
                    dt = time.time() - t0
                finally:
                    if emis_state:
                        restore_emis(emis_state)
                    if isolated:
                        set_all_visible()
                if 'FINISHED' not in res:
                    raise RuntimeError("bake failed: %s %s %s" % (group, btype, res))
                timings["%s/%s/%s" % (group, low_ob.name, key)] = round(dt, 2)
        import numpy as np
        # 口径：整张图集逐步填充后的均值（含其它组与未填区），非该组 UV 局部均值
        print("ART001 atlas_mean_after_group %s ao_atlas_mean=%.3f" % (group, np.array(imgs["ao"].pixels[:], dtype=np.float32).reshape(-1,4)[:,0].mean()))
        for key, p in paths.items():
            try:
                save_img(imgs[key], p)
            except Exception as e:
                raise RuntimeError("save failed: %s -> %s (%s)" % (key, p, e))

    # 已知颜色验证：sRGB 图像缓冲存的是 sRGB 编码值，基色需先线性→sRGB 再比较
    alb = np.array(imgs["albedo"].pixels[:], dtype=np.float32).reshape(-1, 4)
    white = (alb[:, 0] > 0.97) & (alb[:, 1] > 0.97) & (alb[:, 2] > 0.97)
    filled = alb[~white]
    if filled.shape[0] < 1000:
        raise RuntimeError("albedo validation FAILED: almost no baked pixels (%d)" % filled.shape[0])
    def to_srgb(x):
        x = np.clip(x, 0.0, 1.0)
        return np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(x, 1 / 2.4) - 0.055)
    for mname in ("ART001_Olive", "ART001_Steel", "ART001_Dark", "ART001_Rubber"):
        m = bpy.data.materials.get(mname)
        if m is None:
            continue
        c_lin = np.array(principled(m.node_tree).inputs["Base Color"].default_value[:3], dtype=np.float32)
        c = to_srgb(c_lin)
        near = int((np.abs(filled[:, :3] - c).max(axis=1) <= 0.045).sum())
        if near < 500:
            raise RuntimeError("albedo validation FAILED: %s base color %s (sRGB %s) covers only %d px" % (mname, c_lin, c, near))
        print("ART001 albedo color validation: %s linear%s sRGB%s -> %d px OK" % (mname, c_lin, c, near))

    # compose ORM: R=AO G=rough B=metal
    import numpy as np
    ao = np.array(imgs["ao"].pixels[:], dtype=np.float32).reshape(-1, 4)
    mask = np.array(imgs["orm_mask"].pixels[:], dtype=np.float32).reshape(-1, 4)
    orm = np.zeros((ao.shape[0], 4), dtype=np.float32)
    orm[:, 0] = ao[:, 0]
    orm[:, 1] = mask[:, 0]
    orm[:, 2] = mask[:, 1]
    orm[:, 3] = 1.0
    orm_img = ensure_image("ART001_orm_out", OUT / "orm.png", (0, 0, 0), 'Non-Color')
    orm_img.pixels = orm.reshape(-1).tolist()
    save_img(orm_img, OUT / "orm.png")

    # ao_tmp.png / orm_mask_tmp.png 保留作证据文件（此前删除会留下悬空引用）
    (ART / "bake_timings.json").write_text(json.dumps(timings, indent=1), encoding='utf-8')
    bpy.ops.wm.save_mainfile()
    print("ART001_BAKE_STAGE_PASS total_passes=%d" % len(timings))


# ---------------- stage export ----------------
def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def stage_export():
    OUT.mkdir(parents=True, exist_ok=True)
    # detach any bake image nodes so the GLB carries UVs but no baked texture wiring
    for m in bpy.data.materials:
        if m.name.startswith("ART001_"):
            for l in list(m.node_tree.links):
                if l.from_node.type == 'TEX_IMAGE' and l.to_node.type == 'BSDF_PRINCIPLED':
                    m.node_tree.links.remove(l)
    bpy.ops.object.select_all(action='DESELECT')
    for o in coll("LOW").objects:
        o.select_set(True)
    # 父空必须一并导出，否则部件丢失世界偏移（炮塔/火炮会塌回原点）
    for pname in ("hull", "turret", "barrel"):
        p = bpy.data.objects.get(pname)
        if p is not None:
            p.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["LOW_hull_Shell"]
    glb = OUT / "m4a3_1k.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_cameras=False, export_lights=False)
    low_tri = sum(tri_count(o) for o in coll("LOW").objects)
    manifest = {
        "order": "ART-001", "vehicle": "M4A3(75)W VVSS 1944",
        "source_blend_sha256": "FC6DAE2F4E6E6744504071E887DAF10464C6FF470720C849295D281756A7E197",
        "pilot_blend_sha256": sha256(BLEND),
        "glb_sha256": sha256(glb),
        "basecolor_sha256": sha256(OUT / "basecolor.png"),
        "normal_sha256": sha256(OUT / "normal_gl.png"),
        "orm_sha256": sha256(OUT / "orm.png"),
        "blender_version": bpy.app.version_string,
        "budget": {"limit": 1000, "blender_low_tris": low_tri,
                   "per_object": {o.name: tri_count(o) for o in coll("LOW").objects}},
        "maps": {"size": SIZE, "basecolor": "sRGB", "normal": "Non-Color tangent OpenGL +X+Y+Z",
                 "orm": {"R": "AO", "G": "Roughness", "B": "Metallic"}},
        "bake_timings": json.loads((ART / "bake_timings.json").read_text(encoding='utf-8')),
        "uv": "single 0-1 atlas, smart_project angle66 margin0.03",
        "cage": {"hull/turret/gun": 0.03, "wheels/tracks": 0.02},
        "axis": "same authoring convention as authoring/vehicles (blend z-up -> glTF Y-up)",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding='utf-8')
    print("ART001_EXPORT_PASS glb_tris=%d" % low_tri)


def stage_sample():
    """WO order: 256px bake sample on ONE part-group BEFORE whole-vehicle bake."""
    global SIZE
    SIZE = 256
    out = ART / "sample_256"
    out.mkdir(parents=True, exist_ok=True)
    setup_cycles(1)
    imgs = {
        "normal": ensure_image("ART001_sample_n", out / "normal_gl.png", (0.5, 0.5, 1.0), 'Non-Color'),
        "ao": ensure_image("ART001_sample_ao", out / "ao.png", (1.0, 1.0, 1.0), 'Non-Color'),
    }
    group = "wheels"
    lows = [o for o in coll("LOW").objects if o.get("art_group", "") == group]
    for low_ob in lows:
        for key, btype, samples in [("normal", 'NORMAL', 1), ("ao", 'AO', 16)]:
            low_target_node(low_ob, imgs[key])
            select_group(group, low_ob)
            bpy.context.scene.cycles.samples = samples
            res = bpy.ops.object.bake(
                type=btype, use_selected_to_active=True,
                normal_space='TANGENT', normal_r='POS_X', normal_g='POS_Y', normal_b='POS_Z',
                use_cage=True, cage_object="CAGE_" + low_ob.name,
                use_clear=False, margin=8, target='IMAGE_TEXTURES')
            if 'FINISHED' not in res:
                raise RuntimeError("sample bake failed: %s" % btype)
            print("ART001 sample bake %s done" % btype)
    save_img(imgs["normal"], out / "normal_gl.png")
    save_img(imgs["ao"], out / "ao.png")
    # 256 小样数值验证：已知颜色 + 凸起 + 凹陷（工单要求先采样验证再整车）。
    # 切线系方向随 UV 排岛旋转 → 双向性按 R/G 两通道联合判定（旋转不变）。
    import numpy as np
    n = np.array(imgs["normal"].pixels[:], dtype=np.float32).reshape(-1, 4)
    a = np.array(imgs["ao"].pixels[:], dtype=np.float32).reshape(-1, 4)
    detail = ((n[:, 0] > 0.55) | (n[:, 1] > 0.55) | (n[:, 0] < 0.45) | (n[:, 1] < 0.45)) & (n[:, 2] < 0.98)
    pos = int((((n[:, 0] > 0.55) | (n[:, 1] > 0.55)) & (n[:, 2] < 0.98)).sum())
    neg = int((((n[:, 0] < 0.45) | (n[:, 1] < 0.45)) & (n[:, 2] < 0.98)).sum())
    if pos == 0 or neg == 0 or int(detail.sum()) < 20:
        raise RuntimeError("sample normal validation FAILED: no bidirectional tangent detail (+%d/-%d, detail=%d)" % (pos, neg, int(detail.sum())))
    if a[:, 0].min() > 0.5 or a[:, 0].max() < 0.7:
        raise RuntimeError("sample AO validation FAILED: no contact occlusion (min=%.3f max=%.3f)" % (a[:, 0].min(), a[:, 0].max()))
    print("ART001 sample validation: normal +%d/-%d tangent px, AO min=%.3f max=%.3f -> OK" % (pos, neg, a[:, 0].min(), a[:, 0].max()))
    # restore the atlas materials (sample images must not leak into the 1024 bake)
    for m in bpy.data.materials:
        if m.name.startswith("ART001_"):
            for n in list(m.node_tree.nodes):
                if n.type == 'TEX_IMAGE':
                    m.node_tree.nodes.remove(n)
    # mini GLB: low wheels only
    bpy.ops.object.select_all(action='DESELECT')
    for o in coll("LOW").objects:
        if o.get("art_group", "") == group:
            o.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["LOW_wheels"]
    bpy.ops.export_scene.gltf(filepath=str(out / "sample_wheels.glb"), export_format='GLB',
                              use_selection=True, export_apply=True, export_yup=True)
    bpy.ops.wm.save_mainfile()
    print("ART001_SAMPLE_256_PASS")


if STAGE == "low":
    stage_low()
elif STAGE == "high":
    stage_high()
elif STAGE == "cage":
    stage_cage()
elif STAGE == "uv":
    stage_uv()
elif STAGE == "sample":
    stage_sample()
elif STAGE == "bake":
    stage_bake()
elif STAGE == "export":
    stage_export()
else:
    raise RuntimeError("unknown stage " + STAGE)