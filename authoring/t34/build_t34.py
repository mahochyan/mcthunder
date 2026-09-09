"""T-34-style medium tank: full-detail concept replication (Stage B, no tri budget).

Ground truth = concept sheet docs/reference/concept_medium_4663339.png (sha256
466333967f87737f485481cb6ab199b2181ec96174e4de002b1a1aedaac7703e); checklist =
docs/checklists/t34_concept_checklist.md. Practice asset: NO seed JSON exists for
this vehicle (logged deviation) - armor shells modeled from the concept's cast/
welded look. Fixed atlas PNG reused as-is; nothing the sheet lacks (stars, MG,
antenna, pencil, return rollers, muzzle brake) is added.
"""
import bpy
import sys
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector

RUN = Path('E:/AIprogram/mcthunder-development/deliverables/tank-model-workflow-v1-run/tank-model-workflow-v1')
sys.path.insert(0, str(RUN / 'authoring/poly_budget'))
from build_preview import coord
from texture_preview import tile_uv, project

ATLAS = RUN / 'assets/vehicles/textures/vehicle_concept_atlas_v1.png'
OUT = Path(__file__).resolve().parent / 'output'


class Builder:
    def __init__(self):
        self.groups = {}

    def add(self, part, verts, faces, colors):
        vv, ff, cc = self.groups.setdefault(part, ([], [], []))
        off = len(vv)
        vv.extend(tuple(v) for v in verts)
        ff.extend(tuple(off + i for i in f) for f in faces)
        cc.extend([colors] * len(faces) if isinstance(colors, str) else colors)

    def box(self, part, p, size, color='paint'):
        vv = [(p[0] + x * size[0] / 2, p[1] + y * size[1] / 2, p[2] + z * size[2] / 2)
              for x, y, z in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                              (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]]
        self.add(part, vv, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], color)

    def rod(self, part, a, b, radius, color='paint', n=8, end_radius=None, cap_a=True, cap_b=True):
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        u = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < .9 else Vector((1, 0, 0))).normalized()
        v = axis.cross(u)
        rr = radius if end_radius is None else end_radius
        vv = [p + r * (math.cos(i * math.tau / n) * u + math.sin(i * math.tau / n) * v)
              for p, r in [(a, radius), (b, rr)] for i in range(n)]
        ff = [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        cc = [color] * len(ff)
        if cap_a:
            ff.append(tuple(reversed(range(n))))
            cc.append(color)
        if cap_b:
            ff.append(tuple(range(n, n * 2)))
            cc.append(color)
        self.add(part, vv, ff, cc)

    def loft(self, part, loops, color='paint', caps=(True, True)):
        n = len(loops[0])
        vv = [p for loop in loops for p in loop]
        ff, cc = [], []
        for lvl in range(len(loops) - 1):
            for i in range(n):
                ff.append((lvl * n + i, lvl * n + (i + 1) % n, (lvl + 1) * n + (i + 1) % n, (lvl + 1) * n + i))
                cc.append(color)
        if caps[0]:
            ff.append(tuple(range(n)))
            cc.append(color)
        if caps[1]:
            ff.append(tuple(range((len(loops) - 1) * n, len(loops) * n)))
            cc.append(color)
        self.add(part, vv, ff, cc)

    def hull_ring(self, y, zf, zc, zr, hw, nose=0.45):
        """Half-plane plan (x>=0) rounded hull cross-section at height y, mirrored."""
        pts = [(0.0, zf + 0.45, nose), (hw * 0.55, zf, hw * 0.78), (hw * 0.92, zf + 0.28, hw),
               (hw, zc, hw), (hw, zc + (zr - zc) * 0.82, hw), (hw * 0.97, zr, hw * 0.9)]
        right = [(x, y, z) for x, z, _ in pts]
        left = [(x, y, -z) for x, y, z in [(px, py, -pz) for px, py, pz in [(-p[0], p[1], p[2]) for p in pts][::-1]]]
        # mirror: negate x, keep z order reversed
        left = [(-px, y, pz) for px, py, pz in pts[::-1]]
        return right + left

    # T-34 upper-hull loft: plan shrinks with height (inverted trapezoid) ------
    def hull_ring2(self, y, hw, zf_nose, z_front, z_rear, nose_push=0.0):
        pts = [(0.0, zf_nose - nose_push), (hw * 0.5, zf_nose - nose_push * 0.75), (hw * 0.88, zf_nose),
               (hw, z_front), (hw, z_rear - 0.15), (hw * 0.93, z_rear)]
        ring = [(x, y, z) for x, z in pts] + [(-x, y, z) for x, z in pts[::-1]]
        return ring

    def chaikin(self, pts, it=2):
        for _ in range(it):
            out = []
            for i in range(len(pts)):
                a, b = pts[i], pts[(i + 1) % len(pts)]
                out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
                out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            pts = out
        return pts

    def track_samples(self, pitch):
        corners = [(0.04, -2.05), (0.04, 2.00), (0.42, 2.50), (0.88, 2.38), (1.00, 2.05),
                   (1.06, -1.90), (1.06, -2.15), (0.82, -2.55), (0.30, -2.50), (0.06, -2.25)]
        sm = self.chaikin(corners, 3)
        m = len(sm)
        dd = [0.0]
        for i in range(m):
            a, b = sm[i], sm[(i + 1) % m]
            dd.append(dd[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        total = dd[-1]
        n = max(1, round(total / pitch))
        out = []
        j = 0
        for k in range(n):
            d = total * k / n
            while j < m - 1 and dd[j + 1] < d:
                j += 1
            span = dd[j + 1] - dd[j]
            t = (d - dd[j]) / span if span > 1e-6 else 0.0
            y0, z0 = sm[j]
            y1, z1 = sm[(j + 1) % m]
            y = y0 + (y1 - y0) * t
            z = z0 + (z1 - z0) * t
            ang = math.atan2(y1 - y0, z1 - z0)
            out.append((y, z, ang, total / n))
        return out

    def build(self):
        # ---- hull: tall body, ~vertical sloped sides (side-view truth) ----
        hull = self.hull_ring2(0.42, 0.72, -2.55, -2.25, 2.25, 0.05)
        fender = self.hull_ring2(0.96, 1.04, -2.75, -2.55, 2.62, 0.05)
        mid = self.hull_ring2(1.32, 1.00, -2.36, -2.28, 2.50, 0.0)
        deck = self.hull_ring2(1.68, 0.95, -2.00, -1.95, 2.35, 0.0)
        self.loft('hull', [hull, fender], 'dark_paint', caps=(True, False))
        self.loft('hull', [fender, mid], 'paint', caps=(False, False))
        self.loft('hull', [mid, deck], 'paint', caps=(False, True))
        # fenders attach as thin plates outboard of the hull side
        for s in (-1, 1):
            self.box('hull', (s * 1.18, 0.96, 0.10), (0.30, 0.035, 4.95), 'paint')
            self.box('hull', (s * 1.18, 0.93, -2.40), (0.30, 0.035, 0.66), 'paint')
        # driver vision plug on glacis: boss faces UP-FRONT along plate normal
        self.rod('hull', (-0.52, 1.26, -2.42), (-0.52, 1.47, -2.60), 0.20, 'paint', n=12)
        self.box('hull', (-0.52, 1.48, -2.62), (0.18, 0.10, 0.22), 'glass')
        # transmission hatch on glacis center-right + two levers
        self.box('hull', (0.40, 1.48, -2.22), (0.50, 0.10, 0.36), 'paint')
        for dz in (-0.10, 0.10):
            self.rod('hull', (0.40, 1.55, -2.22 + dz), (0.40, 1.66, -2.22 + dz), 0.015, 'steel', n=5, cap_a=False)
        # front D shackles (two rings low-center on glacis, per front view)
        self.rod('hull', (-0.38, 1.00, -2.70), (-0.38, 1.24, -2.46), 0.085, 'steel', n=8)
        self.rod('hull', (0.38, 1.00, -2.70), (0.38, 1.24, -2.46), 0.085, 'steel', n=8)
        # rear D shackles x2
        for s in (-1, 1):
            self.rod('hull', (s * 0.50, 0.72, 2.66), (s * 0.50, 0.94, 2.63), 0.085, 'steel', n=8)
        # headlights high on hull front corners (round disc + guard, per front view)
        for s in (-1, 1):
            self.box('hull', (s * 0.90, 1.18, -2.30), (0.07, 0.20, 0.14), 'steel')
            self.rod('hull', (s * 0.90, 1.28, -2.38), (s * 0.90, 1.28, -2.52), 0.095, 'glass_head', n=12)
            self.rod('hull', (s * 0.90, 1.15, -2.50), (s * 0.90, 1.41, -2.50), 0.013, 'steel', n=4, cap_a=False, cap_b=False)
            self.rod('hull', (s * 0.90 - 0.13, 1.28, -2.50), (s * 0.90 + 0.13, 1.28, -2.50), 0.013, 'steel', n=4, cap_a=False, cap_b=False)
        # engine deck: recessed grille panel with louver slats (right deck)
        self.box('hull', (0.55, 1.665, 0.85), (0.62, 0.025, 1.55), 'grille')
        for i in range(8):
            self.box('hull', (0.55, 1.70, 0.18 + i * 0.19), (0.56, 0.02, 0.06), 'steel')
        # rear plate big access panel
        self.box('hull', (0, 1.12, 2.58), (0.80, 0.55, 0.06), 'paint')
        # side exhausts (upturned at rear deck edges)
        for s in (-1, 1):
            self.rod('hull', (s * 0.92, 1.45, 2.28), (s * 1.00, 1.78, 2.66), 0.075, 'steel', n=10)
            self.rod('hull', (s * 1.00, 1.78, 2.66), (s * 1.02, 1.85, 2.74), 0.05, 'recess', n=10, cap_a=False)
        # fore-aft cylindrical external fuel tanks x2 on rear deck (ENGINE DECK panel: cap forward, 2 bands)
        for s in (-1, 1):
            self.rod('hull', (s * 0.62, 1.87, 1.15), (s * 0.62, 1.87, 2.30), 0.185, 'paint', n=14)
            for z in (1.38, 2.07):
                self.rod('hull', (s * 0.62, 1.87, z - 0.04), (s * 0.62, 1.87, z + 0.04), 0.20, 'steel', n=14, cap_a=False, cap_b=False)
                self.box('hull', (s * 0.62, 1.71, z), (0.16, 0.10, 0.09), 'steel')
        # deck filler cap center
        self.rod('hull', (0.02, 1.685, 0.62), (0.02, 1.72, 0.62), 0.13, 'paint', n=10)
        # spare track rack (3 links stood on upper glacis right)
        for i, x in enumerate((0.55, 0.70, 0.85)):
            self.box('hull', (x, 1.585 + i * 0.008, -2.05 - i * 0.055), (0.12, 0.06, 0.22), 'dark_paint')
        # deck stowage: wooden box (left deck) + shovel (lay flat)
        self.box('hull', (-0.45, 1.775, 0.15), (0.50, 0.17, 0.40), 'wood')
        self.rod('hull', (-0.85, 1.71, -0.55), (-0.85, 1.71, 0.55), 0.03, 'wood', n=6, cap_a=False)
        self.box('hull', (-0.85, 1.70, 0.68), (0.16, 0.05, 0.26), 'steel')
        # ---- turret: angular faceted cast (flat planes, big roof chamfer; sheet: NOT rounded) ----
        to = (0.0, 1.68, -0.55)
        def T(p):
            return (p[0] - to[0], p[1] - to[1], p[2] - to[2])
        def tring(y, xs, zf, zt, zr):
            pts = [(0.00, zf), (0.50 * xs, zf + 0.02), (xs, zf + 0.50),
                   (xs, zt), (xs, zr - 0.40), (0.52 * xs, zr)]
            ring = [(x, y, z) for x, z in pts] + [(-x, y, z) for x, z in pts[::-1]]
            return [T(p) for p in ring]
        # nearly vertical walls (x barely tapers) + sloped front/rear plates -> angular cast, not a dome
        self.loft('turret', [tring(1.68, 1.06, -1.86, -0.45, 0.98),
                             tring(2.28, 0.97, -1.58, -0.44, 0.70)], 'paint', caps=(True, True))
        # skirt ring at the very base (fills the deck joint)
        self.loft('turret', [tring(1.66, 1.10, -1.90, -0.45, 1.02),
                             tring(1.72, 1.06, -1.86, -0.45, 0.98)], 'paint', caps=(False, False))
        # mantlet: cast trapezoid bulge + trunnion collar + small left vision port
        self.box('turret', T((0, 1.86, -1.70)), (1.06, 0.60, 0.16), 'paint')
        self.rod('turret', T((0, 1.86, -1.62)), T((0, 1.86, -2.02)), 0.17, 'paint', n=14, cap_a=False)
        self.rod('turret', T((0, 1.86, -1.92)), T((0, 1.86, -2.00)), 0.195, 'paint', n=14, cap_a=False)
        self.box('turret', T((-0.66, 2.04, -1.42)), (0.10, 0.16, 0.08), 'paint')
        self.box('turret', T((-0.72, 2.04, -1.42)), (0.03, 0.09, 0.03), 'recess')
        # turret roof: two raised corner blocks + commander hatch drum w/ handle
        for s in (-1, 1):
            self.box('turret', T((s * 0.44, 2.31, -1.00)), (0.28, 0.08, 0.22), 'paint')
        self.rod('turret', T((0.14, 2.27, 0.22)), T((0.14, 2.40, 0.22)), 0.22, 'paint', n=12)
        self.rod('turret', T((0.14, 2.40, 0.22)), T((0.14, 2.43, 0.22)), 0.19, 'paint', n=12)
        self.rod('turret', T((0.00, 2.445, 0.22)), T((0.28, 2.445, 0.22)), 0.02, 'steel', n=6, cap_a=False)
        # ---- gun (barrel empty at gun origin, local) ----
        go = (0.0, 1.86, -2.02)
        G = lambda p: (p[0] - go[0], p[1] - go[1], p[2] - go[2])
        self.rod('gun_recoil', G((0, 1.86, -1.97)), G((0, 1.86, -4.42)), 0.095, 'paint', n=16, cap_a=False)
        self.rod('gun_recoil', G((0, 1.86, -4.05)), G((0, 1.86, -4.50)), 0.115, 'paint', n=16, cap_a=False)
        # ---- running gear: 5 Christie wheels + front sprocket + rear idler ----
        for s in (-1, 1):
            x_in, x_out = s * 1.02, s * 1.20
            for z in (-1.38, -0.69, 0.0, 0.69, 1.38):
                self.rod('wheels', (x_in, 0.46, z), (x_out, 0.46, z), 0.46, 'rubber', n=18, cap_a=False)
                self.groups['wheels'][2][-1] = 'paint'
                # raised outer rim ring (side-view detail: stepped face edge)
                seg = 20
                def wring(x, r):
                    return [(x, 0.46 + math.sin(k * math.tau / seg) * r, z + math.cos(k * math.tau / seg) * r)
                            for k in range(seg)]
                self.loft('wheels', [wring(x_out, 0.455), wring(x_out + 0.045, 0.455),
                                     wring(x_out + 0.045, 0.35), wring(x_out, 0.35)], 'paint', caps=(False, False))
                self.groups['wheels'][2][-3 * seg:] = ['dark_paint'] * seg + ['paint'] * seg + ['dark_paint'] * seg
                for k in range(6):
                    a = k * math.tau / 6
                    self.rod('wheels', (x_out, 0.46 + math.sin(a) * 0.25, z + math.cos(a) * 0.25),
                             (x_out + s * 0.04, 0.46 + math.sin(a) * 0.25, z + math.cos(a) * 0.25), 0.05, 'light_paint', n=6)
                self.rod('wheels', (x_out, 0.46, z), (x_out + s * 0.06, 0.46, z), 0.12, 'light_paint', n=10)
            # front drive sprocket (block teeth), rear idler
            self.rod('wheels', (x_in, 0.72, -2.02), (x_out, 0.72, -2.02), 0.26, 'dark_paint', n=12, cap_a=False)
            self.groups['wheels'][2][-1] = 'steel_face'
            for k in range(8):
                a = k * math.tau / 8 + 0.2
                cy, cz = 0.72 + math.sin(a) * 0.30, -2.02 + math.cos(a) * 0.30
                self.box('wheels', ((x_in + x_out) / 2, cy, cz), (abs(x_out - x_in) + .04, 0.13, 0.11), 'steel')
            self.rod('wheels', (x_in, 0.60, 2.28), (x_out, 0.60, 2.28), 0.30, 'dark_paint', n=14, cap_a=False)
            self.groups['wheels'][2][-1] = 'steel_face'
            self.rod('wheels', (x_out, 0.60, 2.28), (x_out + s * 0.05, 0.60, 2.28), 0.10, 'steel', n=8)
            # track: individual cleated links, full loop incl. straight top run
            part = 'track_left' if s < 0 else 'track_right'
            for y, z, ang, pitch in self.track_samples(0.40):
                nrm = Vector((0, -math.cos(ang), math.sin(ang)))
                tan = Vector((0, math.sin(ang), math.cos(ang)))
                c = Vector((s * 1.20, y, z))
                w = 0.26
                vv = [tuple(c + Vector((sx * w, 0, 0)) + tan * (sz * pitch * 0.48) + nrm * h)
                      for sx in (-1, 1) for sz in (-1, 1) for h in (-0.045, 0.065)]
                ff = [(1, 3, 7, 5), (0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3)]
                cc = ['tread', 'steel', 'steel', 'steel', 'steel']
                ff.append((0, 4, 6, 2))
                cc.append('steel')
                self.add(part, vv, ff, cc)
                hc = c + nrm * -0.09
                hv = [tuple(hc + Vector((sx * 0.05, 0, 0)) + tan * (sz * pitch * 0.22) + nrm * h2)
                      for sx in (-1, 1) for sz in (-1, 1) for h2 in (-0.02, 0.02)]
                self.add(part, hv, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], 'steel')

    # ---- UV per face (fixed atlas) ----
    def face_uv(self, part, points, color):
        normal = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
        center = sum(points, Vector()) / len(points)
        axis = max(range(3), key=lambda i: abs(normal[i]))
        ax, ay = [(2, 1), (0, 2), (0, 1)][axis]
        if color == 'tread':
            return [tile_uv(4, u, v) for u, v in [(0, 0), (0, 1), (1, 1), (1, 0)]]
        base = {'steel': 13, 'recess': 13, 'rubber': 12, 'wood': 14, 'glass': 13, 'glass_head': 13,
                'grille': 7, 'dark_paint': 1, 'steel_face': 13, 'light_paint': 0}.get(color)
        if part == 'wheels' and abs(normal.x) > .99 and color == 'paint':
            ends = [(-2.02, 0.72), (2.28, 0.68)]
            road = all(abs(center.z - e) > .85 for e, _ in [(a, b) for a, b in ends])
            zc, yc = min(ends, key=lambda e: abs(e[0] - center.z)) if not road else (round(center.z / .66) * .66, 0.42)
            rc = 0.40 if road else 0.28
            uv = [(.5 + (p.z - zc) / rc * .465, .5 + (p.y - yc) / rc * .465) for p in points]
            return [tile_uv(0, u, v) for u, v in uv]
        if base is not None:
            return [tile_uv(base, u, v) for u, v in project(points, ax, ay)]
        return [tile_uv(0, u, v) for u, v in project(points, ax, ay)]


def create(model):
    material = bpy.data.materials.new('T34 concept atlas')
    material.use_nodes = True
    shader = material.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .90
    image = bpy.data.images.load(str(ATLAS))
    image.pack()
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    material.node_tree.links.new(node.outputs['Color'], shader.inputs['Base Color'])
    parts = {}
    for part, parent, origin in [('hull', None, (0, 0, 0)), ('turret', 'hull', (0.0, 1.68, -0.55)),
                                 ('barrel', 'turret', (0.0, 0.18, -1.47)), ('gun_recoil', 'barrel', (0, 0, 0))]:
        obj = bpy.data.objects.new(part, None)
        bpy.context.collection.objects.link(obj)
        if parent:
            obj.parent = parts[parent]
        obj.location = coord(origin)
        parts[part] = obj

    def mesh_object(name, parent, verts, faces, uvs):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([coord(v) for v in verts], [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = parent
        mesh.materials.append(material)
        layer = mesh.uv_layers.new(name='ConceptAtlasUV')
        for f, values in zip(mesh.polygons, uvs):
            for loop, value in zip(f.loop_indices, values):
                layer.data[loop].uv = value
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        tri = obj.modifiers.new('Export triangles', 'TRIANGULATE')
        bpy.ops.object.modifier_apply(modifier=tri.name)
        obj.select_set(False)
        obj['damage_geometry'] = False
        return obj

    for group, (verts, faces, colors) in model.groups.items():
        parent_name = 'turret' if group == 'turret' else ('gun_recoil' if group == 'gun_recoil' else 'hull')
        uvs = [model.face_uv(group, [Vector(verts[i]) for i in f], c) for f, c in zip(faces, colors)]
        mesh_object('Cosmetic_' + group, parts[parent_name], verts, faces, uvs)


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        if obj.name.startswith(('LOW_', 'CAGE_', 'Cosmetic_')):
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.preferences.filepaths.save_version = 0
    model = Builder()
    model.build()
    create(model)
    count = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    scene['vehicle_id'] = 't34_style_concept_replica'
    scene['gameplay_replacement'] = False
    scene['practice_asset'] = True
    blend = OUT / 't34_replica.blend'
    glb = OUT / 't34_replica.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', export_extras=True,
                              export_yup=True, export_cameras=False, export_lights=False)
    manifest = {
        'vehicle_id': 't34_style_concept_replica',
        'stage': 'B full-detail concept replication (no tri budget, user order)',
        'actual_triangles': count,
        'concept_sheet': 'docs/reference/concept_medium_4663339.png',
        'concept_sha256': '466333967f87737f485481cb6ab199b2181ec96174e4de002b1a1aedaac7703e',
        'checklist': 'docs/checklists/t34_concept_checklist.md',
        'seed': 'NONE - practice asset, armor shells modeled from concept (logged deviation)',
        'texture_file': ATLAS.relative_to(RUN).as_posix(),
        'texture_sha256': hashlib.sha256(ATLAS.read_bytes()).hexdigest(),
        'texture_origin': 'fixed package atlas PNG (reused, not regenerated)',
        'not_added_by_design': ['stars/markings', 'AA MG', 'antenna', 'turret pencil tube',
                                'return rollers (Christie)', 'muzzle brake'],
        'practice_asset': True,
        'gameplay_replacement': False,
        'generator': 'authoring/t34/build_t34.py',
    }
    glb.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('T34_STAGE_B_PASS', count, flush=True)


if __name__ == '__main__':
    run()
