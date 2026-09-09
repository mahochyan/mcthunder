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
        corners = [(0.15, -2.35), (0.15, 2.30), (0.40, 2.62), (0.66, 2.45), (0.66, -2.30),
                   (0.66, -2.52), (0.44, -2.68), (0.24, -2.58), (0.15, -2.48)]
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
        # ---- hull: LOW-SLUNG side-panel-verified (87.4px/m: deck 1.35, fender 0.90, long 27deg hood) ----
        belly = self.hull_ring2(0.30, 0.68, -2.25, -2.10, 2.10, 0.04)
        fender = self.hull_ring2(0.90, 1.02, -2.70, -2.50, 2.62, 0.06)
        deck = self.hull_ring2(1.35, 0.95, -2.02, -1.98, 2.42, 0.0)
        self.loft('hull', [belly, fender], 'dark_paint', caps=(True, False))
        self.loft('hull', [fender, deck], 'paint', caps=(False, True))
        # fenders: thin plates outboard (panel: straight line, small front/rear flaps)
        for s in (-1, 1):
            self.box('hull', (s * 1.16, 0.90, 0.085), (0.34, 0.035, 5.02), 'paint')
            self.box('hull', (s * 1.16, 0.87, -2.55), (0.34, 0.035, 0.50), 'paint')
        # glacis plane: z(y) = -2.50 + 1.07*(y-0.90) (long ~45deg hood, panel-verified)
        # driver vision plug (left) with slit glass, boss along plate normal
        self.rod('hull', (-0.50, 1.20, -2.18), (-0.50, 1.36, -2.32), 0.19, 'paint', n=12)
        self.box('hull', (-0.50, 1.375, -2.34), (0.17, 0.09, 0.21), 'glass')
        # transmission hatch (center-right) + levers
        self.box('hull', (0.42, 1.22, -2.16), (0.52, 0.10, 0.36), 'paint')
        for dz in (-0.10, 0.10):
            self.rod('hull', (0.42, 1.29, -2.08 + dz), (0.42, 1.38, -2.14 + dz), 0.015, 'steel', n=5, cap_a=False)
        # two D shackles low-center
        self.rod('hull', (-0.38, 0.98, -2.45), (-0.38, 1.14, -2.22), 0.08, 'steel', n=8)
        self.rod('hull', (0.38, 0.98, -2.45), (0.38, 1.14, -2.22), 0.08, 'steel', n=8)
        # headlights on brackets at hull front corners (round lamp + grid guard)
        for s in (-1, 1):
            self.box('hull', (s * 0.88, 1.00, -2.62), (0.07, 0.16, 0.12), 'steel')
            self.rod('hull', (s * 0.88, 1.04, -2.70), (s * 0.88, 1.04, -2.86), 0.105, 'glass_head', n=12)
            self.rod('hull', (s * 0.88, 0.92, -2.84), (s * 0.88, 1.16, -2.84), 0.013, 'steel', n=4, cap_a=False, cap_b=False)
            self.rod('hull', (s * 0.88 - 0.11, 1.04, -2.84), (s * 0.88 + 0.11, 1.04, -2.84), 0.013, 'steel', n=4, cap_a=False, cap_b=False)
        # rear plate: access panel + tow shackles + upturned exhausts (rear circles in panel)
        self.box('hull', (0, 1.15, 2.51), (0.80, 0.50, 0.06), 'paint')
        for s in (-1, 1):
            self.rod('hull', (s * 0.48, 0.70, 2.66), (s * 0.48, 0.92, 2.62), 0.08, 'steel', n=8)
            self.rod('hull', (s * 0.85, 1.20, 2.45), (s * 0.92, 1.42, 2.62), 0.07, 'steel', n=10)
            self.rod('hull', (s * 0.92, 1.42, 2.62), (s * 0.94, 1.48, 2.70), 0.05, 'recess', n=10, cap_a=False)
        # engine deck (panel layout): centered louvred grille + single centered fore-aft tank + right stowage
        self.box('hull', (0, 1.345, 1.50), (0.62, 0.03, 0.70), 'grille')
        for i in range(3):
            self.box('hull', (0, 1.375, 1.28 + i * 0.22), (0.56, 0.02, 0.07), 'steel')
        # rear-hung cylindrical fuel drum (panel: deck-line height, just past rear plate)
        self.rod('hull', (0, 1.38, 2.40), (0, 1.38, 2.80), 0.19, 'paint', n=14)
        self.rod('hull', (0, 1.38, 2.35), (0, 1.38, 2.41), 0.12, 'steel_face', n=12)
        for z in (2.50, 2.72):
            self.rod('hull', (0, 1.38, z - 0.035), (0, 1.38, z + 0.035), 0.205, 'steel', n=14, cap_a=False, cap_b=False)
            self.box('hull', (0, 1.38, z), (0.42, 0.10, 0.09), 'steel')
        self.rod('hull', (-0.40, 1.365, 0.62), (-0.40, 1.40, 0.62), 0.11, 'paint', n=10)
        self.box('hull', (0.58, 1.435, 0.62), (0.40, 0.17, 0.34), 'wood')
        self.rod('hull', (0.88, 1.375, -0.30), (0.88, 1.375, 0.42), 0.028, 'wood', n=6, cap_a=False)
        self.box('hull', (0.88, 1.365, 0.55), (0.15, 0.045, 0.24), 'steel')
        # ---- turret: angular faceted cast on deck 1.35; roof 1.87; TALL cupola (panel ~0.4m drum) ----
        to = (0.0, 1.35, -0.55)
        def T(p):
            return (p[0] - to[0], p[1] - to[1], p[2] - to[2])
        def tring(y, xs, zf, zt, zr):
            pts = [(0.00, zf), (0.50 * xs, zf + 0.02), (xs, zf + 0.50),
                   (xs, zt), (xs, zr - 0.40), (0.52 * xs, zr)]
            ring = [(x, y, z) for x, z in pts] + [(-x, y, z) for x, z in pts[::-1]]
            return [T(p) for p in ring]
        self.loft('turret', [tring(1.33, 1.10, -1.70, -0.45, 0.62),
                             tring(1.39, 1.05, -1.64, -0.45, 0.58)], 'paint', caps=(False, False))
        self.loft('turret', [tring(1.40, 1.05, -1.64, -0.45, 0.58),
                             tring(1.64, 1.08, -1.52, -0.45, 0.50),
                             tring(1.92, 0.98, -1.32, -0.44, 0.35)], 'paint', caps=(True, True))
        # mantlet: LOW cast shield (panel: gun line ~1.25m, below turret mid) + short collar
        def mring(y, a, b, z):
            return [T((a * math.cos(k * math.tau / 16), y + b * math.sin(k * math.tau / 16), z)) for k in range(16)]
        self.loft('turret', [mring(1.70, 0.54, 0.34, -1.74), mring(1.70, 0.52, 0.32, -1.54)], 'paint')
        self.rod('turret', T((0, 1.74, -1.74)), T((0, 1.74, -1.92)), 0.15, 'paint', n=14, cap_a=False)
        self.rod('turret', T((0, 1.74, -1.84)), T((0, 1.74, -1.92)), 0.175, 'paint', n=14, cap_a=False)
        self.box('turret', T((-0.60, 1.70, -1.36)), (0.09, 0.15, 0.08), 'paint')
        self.box('turret', T((-0.655, 1.70, -1.36)), (0.03, 0.08, 0.03), 'recess')
        for s in (-1, 1):
            self.box('turret', T((s * 0.42, 1.945, -0.92)), (0.26, 0.07, 0.20), 'paint')
        self.rod('turret', T((0.14, 1.90, 0.13)), T((0.14, 2.25, 0.13)), 0.215, 'paint', n=12)
        self.rod('turret', T((0.14, 2.25, 0.13)), T((0.14, 2.29, 0.13)), 0.19, 'paint', n=12)
        self.rod('turret', T((0.00, 2.305, 0.13)), T((0.28, 2.305, 0.13)), 0.018, 'steel', n=6, cap_a=False)
        # ---- gun: trunnion (0,1.74,-1.90), FLAT long barrel to z-3.6 @y1.70 (panel rows 52-71) ----
        go = (0.0, 1.74, -1.90)
        G = lambda p: (p[0] - go[0], p[1] - go[1], p[2] - go[2])
        self.rod('gun_recoil', G((0, 1.74, -1.84)), G((0, 1.71, -3.30)), 0.085, 'paint', n=16, cap_a=False)
        self.rod('gun_recoil', G((0, 1.72, -2.90)), G((0, 1.70, -3.36)), 0.125, 'paint', n=16, cap_a=False)
        # ---- running gear: 5 road wheels r0.42 pitch 0.83 + LARGE rear idler + low small sprocket ----
        for s in (-1, 1):
            x_in, x_out = s * 1.04, s * 1.22
            for z in (-1.66, -0.83, 0.0, 0.83, 1.66):
                self.rod('wheels', (x_in, 0.40, z), (x_out, 0.40, z), 0.40, 'rubber', n=20, cap_a=False)
                self.groups['wheels'][2][-1] = 'paint'
                # raised outer rim ring (side-view detail: stepped face edge)
                seg = 22
                def wring(x, r):
                    return [(x, 0.40 + math.sin(k * math.tau / seg) * r, z + math.cos(k * math.tau / seg) * r)
                            for k in range(seg)]
                self.loft('wheels', [wring(x_out, 0.39), wring(x_out + 0.045, 0.39),
                                     wring(x_out + 0.045, 0.28), wring(x_out, 0.28)], 'paint', caps=(False, False))
                self.groups['wheels'][2][-3 * seg:] = ['dark_paint'] * seg + ['paint'] * seg + ['dark_paint'] * seg
                for k in range(6):
                    a = k * math.tau / 6
                    self.rod('wheels', (x_out, 0.40 + math.sin(a) * 0.21, z + math.cos(a) * 0.21),
                             (x_out + s * 0.04, 0.40 + math.sin(a) * 0.21, z + math.cos(a) * 0.21), 0.05, 'light_paint', n=6)
                self.rod('wheels', (x_out, 0.40, z), (x_out + s * 0.06, 0.40, z), 0.11, 'light_paint', n=10)
            # rear LARGE idler (same class as road wheels, panel-verified)
            self.rod('wheels', (x_in, 0.40, 2.30), (x_out, 0.40, 2.30), 0.38, 'rubber', n=20, cap_a=False)
            self.groups['wheels'][2][-1] = 'paint'
            seg = 22
            def wr2(x, r):
                return [(x, 0.40 + math.sin(k * math.tau / seg) * r, 2.30 + math.cos(k * math.tau / seg) * r)
                        for k in range(seg)]
            self.loft('wheels', [wr2(x_out, 0.37), wr2(x_out + 0.045, 0.37),
                                 wr2(x_out + 0.045, 0.27), wr2(x_out, 0.27)], 'paint', caps=(False, False))
            self.groups['wheels'][2][-3 * seg:] = ['dark_paint'] * seg + ['paint'] * seg + ['dark_paint'] * seg
            self.rod('wheels', (x_out, 0.40, 2.30), (x_out + s * 0.06, 0.40, 2.30), 0.11, 'light_paint', n=10)
            # front drive sprocket (block teeth), low & small per panel
            self.rod('wheels', (x_in, 0.40, -2.39), (x_out, 0.40, -2.39), 0.24, 'dark_paint', n=14, cap_a=False)
            self.groups['wheels'][2][-1] = 'steel_face'
            for k in range(8):
                a = k * math.tau / 8 + 0.2
                cy, cz = 0.40 + math.sin(a) * 0.28, -2.39 + math.cos(a) * 0.28
                self.box('wheels', ((x_in + x_out) / 2, cy, cz), (abs(x_out - x_in) + .04, 0.10, 0.09), 'steel')
            # track: individual cleated links, full loop incl. straight top run
            part = 'track_left' if s < 0 else 'track_right'
            for y, z, ang, pitch in self.track_samples(0.34):
                nrm = Vector((0, -math.cos(ang), math.sin(ang)))
                tan = Vector((0, math.sin(ang), math.cos(ang)))
                c = Vector((s * 1.22, y, z))
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
            ends = [(-2.39, 0.40), (2.30, 0.40)]
            road = all(abs(center.z - e) > .85 for e, _ in [(a, b) for a, b in ends])
            if road:
                zc = round(center.z / 0.83) * 0.83; yc = 0.40; rc = 0.36
            elif abs(center.z - 2.30) < 1.0:
                zc, yc, rc = 2.30, 0.40, 0.34
            else:
                zc, yc, rc = -2.39, 0.40, 0.24
            uv = [(.5 + (p.z - zc) / rc * .465, .5 + (p.y - yc) / rc * .465) for p in points]
            return [tile_uv(0, u, v) for u, v in uv]
        if base is not None:
            return [tile_uv(base, u, v) for u, v in project(points, ax, ay)]
        return [tile_uv(0, u, v) for u, v in project(points, ax, ay)]


def create(model):
    for m in [x for x in bpy.data.materials if x.name.startswith('T34 concept atlas')]:
        bpy.data.materials.remove(m)
    material = bpy.data.materials.new('T34 concept atlas')
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    if shader is None:
        shader = material.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    if shader.inputs.get('Roughness'):
        shader.inputs['Roughness'].default_value = .90
    image = bpy.data.images.load(str(ATLAS))
    image.pack()
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    material.node_tree.links.new(node.outputs['Color'], shader.inputs['Base Color'])
    parts = {}
    for part, parent, origin in [('hull', None, (0, 0, 0)), ('turret', 'hull', (0.0, 1.35, -0.55)),
                                 ('barrel', 'turret', (0.0, 0.39, -1.35)), ('gun_recoil', 'barrel', (0, 0, 0))]:
        obj = bpy.data.objects.new(part, None)
        bpy.context.collection.objects.link(obj)
        if parent:
            obj.parent = parts[parent]
        obj.location = coord(origin)
        parts[part] = obj

    # cast-look soft edges: per-group bevel (concept: rounded cast plates, not knife boxes)
    bevels = {'hull': 0.028, 'turret': 0.035, 'gun_recoil': 0.014, 'wheels': 0.014}

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
        width = bevels.get(name.removeprefix('Cosmetic_'), 0.0)
        if width > 0:
            bev = obj.modifiers.new('Cast bevel', 'BEVEL')
            bev.width = width
            bev.segments = 1
            bev.limit_method = 'ANGLE'
            bev.angle_limit = math.radians(42)
            bev.use_clamp_overlap = True
            bpy.ops.object.modifier_apply(modifier=bev.name)
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
