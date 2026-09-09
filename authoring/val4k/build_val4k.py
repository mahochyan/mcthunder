"""VAL-4K: 4000-triangle M4A3(75)W 1944 VVSS concept-fidelity validation model.

Reusable-workflow implementation at 4x budget: armor vertices unchanged from the
validated seed; every silhouette feature visible on the user's M4-style concept
sheet is real geometry (single track links, VVSS bogies, return rollers, toothed
rear sprockets, cupola + AA MG, double-baffle muzzle brake [concept-fidelity
choice; the historical 75 mm had none - logged], shackles, guarded headlights,
deck grille, exhausts, stowage crates, tools, antenna). Textures reuse the fixed
concept atlas PNG (no image regeneration). Validation piece, not a gameplay
replacement.
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
sys.path.insert(0, str(RUN / 'authoring/vehicles'))
from build_preview import Model, coord
from texture_preview import tile_uv, project
import style_metadata as style

ATLAS = RUN / 'assets/vehicles/textures/vehicle_concept_atlas_v1.png'
SEED = RUN / 'authoring/vehicles/seeds/us_m4a3_75w_vvss_1944.json'
OUT = Path(__file__).resolve().parent / 'output'
BUDGET = 4000


class Val4k(Model):
    def __init__(self, seed):
        super().__init__(BUDGET)
        self.seed = seed
        self.p = seed['packet']
        self.g = self.p['geometry']
        g = self.g
        self.width = self.p['facts']['dimensions.width_m']['value']
        self.length = self.p['facts']['dimensions.reference_length_m']['value']
        self.tw = g['track_width']
        self.xtr = self.width / 2 - self.tw / 2
        self.half = self.length * .402
        self.rt = .52
        self.yc = .56
        self.roof = g['hull_rings'][2][0]
        self.top = g['turret_top']
        self.r = g['wheel_radius']
        self.perim = 4 * self.half + math.tau * self.rt

    # ---- helpers (game space: x right, y up, -z forward) ----
    def ring_point(self, d):
        half, r, y = self.half, self.rt, self.yc
        if d < half * 2:
            return (y - r, -half + d, 0.0)
        if d < half * 2 + math.pi * r:
            a = (d - half * 2) / r - math.pi / 2
            return (y + r * math.sin(a), half + r * math.cos(a), a + math.pi / 2)
        if d < half * 4 + math.pi * r:
            return (y + r, half - (d - half * 2 - math.pi * r), math.pi)
        a = (d - half * 4 - math.pi * r) / r + math.pi / 2
        return (y + r * math.sin(a), -half + r * math.cos(a), a + math.pi / 2)

    def link_box(self, part, side, center, angle, length, inner, outer, w):
        n = Vector((0, -math.cos(angle), math.sin(angle)))
        t = Vector((0, math.sin(angle), math.cos(angle)))
        c = Vector((side * self.xtr, center[0], center[1]))
        vv = [tuple(c + Vector((sx * w / 2, 0, 0)) + t * (sz * length / 2) + n * h)
              for sx in (-1, 1) for sz in (-1, 1) for h in (-inner, outer)]
        # vv order: (-1,-1,-i) (-1,-1,o) (-1,1,-i) (-1,1,o) (1,-1,-i) (1,-1,o) (1,1,-i) (1,1,o)
        ff = [(1, 3, 7, 5), (0, 4, 6, 2), (0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3)]
        cc = ['tread', 'steel', 'steel', 'steel', 'steel', 'steel']
        self.add(part, vv, ff, cc)

    def radial_face(self, part, a, b, r, n, face_color='paint', band='rubber', hub=None):
        self.rod(part, a, b, r, band, n=n, cap_a=False)
        self.groups[part][2][-1] = face_color
        if hub:
            ax, ay, az = b
            side = 1 if b[0] > a[0] else -1
            self.rod(part, b, (b[0] + side * hub[0], ay, az), r * .55, 'light_paint', n=n - 2, cap_a=False)
            self.rod(part, (b[0] + side * (hub[0] + .005), ay, az), (b[0] + side * (hub[0] + hub[1]), ay, az),
                     r * .18, 'steel', n=6, cap_a=False)

    def teeth(self, part, center, r, n, size):
        x, y, z = center
        for i in range(n):
            a = i * math.tau / n
            cy, cz = y + math.cos(a) * r, z + math.sin(a) * r
            dy, dz = math.cos(a), math.sin(a)
            hy, hz = -math.sin(a), math.cos(a)
            w, hl, ht = size
            vv = []
            for sx, sy, sz in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                               (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]:
                vv.append((x + sx * w / 2, cy + (dy * sz + hy * sy) * hl, cz + (dz * sz + hz * sy) * ht))
            self.add(part, vv, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], 'steel')

    def build(self):
        g, w, tw = self.g, self.width, self.tw
        roof, top, r = self.roof, self.top, self.r
        span = self.length * .60
        centers = [-span * .34, 0, span * .34]
        wheel_z = [c + d for c in centers for d in [-r * 1.02, r * 1.02]]
        for side in (-1, 1):
            x = side * self.xtr
            outer = x + side * tw * .39
            # road wheels (6): rubber rim band + painted face (tile 2) + hub
            for z in wheel_z:
                self.radial_face('wheels', (x - side * tw * .25, r + .10, z), (outer, r + .10, z), r, 10, hub=(tw * .14, .04))
            # rear drive sprocket with teeth, front idler
            self.radial_face('wheels', (x - side * tw * .2, self.yc, self.half), (outer, self.yc, self.half), .43, 12, face_color='sprocket')
            self.teeth('wheels', (outer + side * .02, self.yc, self.half), .44, 10, (tw * .3, .10, .075))
            self.radial_face('wheels', (x - side * tw * .2, self.yc, -self.half), (outer, self.yc, -self.half), .43, 12, hub=(tw * .14, .04))
            # single track links, chain closed (each outer quad = one atlas link tile)
            part = 'track_left' if side < 0 else 'track_right'
            N = 40
            pitch = self.perim / N
            for i in range(N):
                y, z, ang = self.ring_point(i * pitch + pitch * .5)
                self.link_box(part, side, (y, z), ang, pitch * .96, .045, .05, tw + .04)
            # VVSS bogie yoke + volute-spring housing + return roller
            for z in centers:
                outline = [(-.14, .97), (.14, .97), (.14, .75), (.42, .50), (.32, .40), (0, .66), (-.32, .40), (-.42, .50), (-.14, .75)]
                vv = [(side * xx, yy, z + zz) for xx in [tw * .38, tw * .46] for zz, yy in outline]
                n = len(outline)
                ff = [tuple(range(n, n * 2))] + [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
                self.add('suspension', vv, ff, 'spring')
                self.box('suspension', (side * (self.xtr + tw * .42), .82, z), (tw * .5, .30, .26), 'spring')
                self.rod('suspension', (side * (self.xtr + tw * .30), .99, z + .14), (side * (self.xtr + tw * .52), .99, z + .14), .10, 'steel', n=8)
            # fenders + front track-top nose guards (sit on the idler arc, flush)
            self.box('hull', (side * self.xtr, 1.18, .05), (tw + .08, .035, self.length * .89), 'paint')
            self.box('hull', (side * self.xtr, 1.12, -2.5), (tw + .1, .04, .62), 'paint')
            # headlights with guards
            self.rod('hull', (side * .82, 1.70, -2.02), (side * .82, 1.70, -2.13), .085, 'glass_head', n=8)
            for dx in (-.12, .12):
                self.rod('hull', (side * .82 + dx, 1.60, -2.09), (side * .82 + dx, 1.82, -2.09), .013, 'steel', n=4, cap_a=False, cap_b=False)
            # front tow shackles
            self.rod('hull', (side * .62, .85, -2.90), (side * .62, .68, -2.94), .07, 'steel', n=8)
            # stowage: crates right deck, rolled canvas left, tools
            if side > 0:
                self.box('hull', (.62, roof + .16, 2.3), (.52, .26, .66), 'canvas')
                self.box('hull', (.60, roof + .42, 2.35), (.42, .24, .50), 'canvas')
                self.rod('hull', (1.02, roof + .12, .80), (1.02, roof + .12, 1.85), .035, 'wood', n=6, cap_a=False)
                self.box('hull', (1.02, roof + .12, .72), (.10, .12, .22), 'steel')
            else:
                self.rod('hull', (-.45, roof + .08, 2.55), (.45, roof + .08, 2.55), .11, 'canvas', n=8)
                self.rod('hull', (-1.02, roof + .12, -.15), (-1.02, roof + .12, -1.05), .032, 'wood', n=6, cap_a=False)
                self.box('hull', (-1.02, roof + .12, -.10), (.14, .16, .16), 'steel')
        # hull furniture: transmission housing, vision block, driver hatches
        self.box('hull', (0, 1.08, -2.80), (1.05, .50, .22), 'paint')
        self.box('hull', (0, .66, -2.96), (.72, .38, .16), 'paint')
        self.box('hull', (-.30, 1.52, -2.18), (.30, .14, .42), 'hatch')
        for s in (-1, 1):
            self.box('hull', (s * .46, roof + .03, -1.15), (.40, .05, .42), 'hatch')
        # engine deck grille + exhausts + tail light + rear shackles
        self.box('hull', (0, roof + .035, 1.55), (1.30, .03, 1.60), 'grille')
        for s in (-1, 1):
            self.rod('hull', (s * .55, .62, 3.02), (s * .55, .62, 3.28), .085, 'steel', n=8)
            self.rod('hull', (s * .55, .62, 3.24), (s * .55, .62, 3.30), .11, 'steel', n=8, cap_a=False)
            self.rod('hull', (s * .92, .82, 3.02), (s * .92, .65, 3.02), .07, 'steel', n=8)
        self.box('hull', (-.18, 1.58, 3.00), (.12, .14, .05), 'steel')
        # ---- turret (local coords; empty at turret_origin) ----
        self.rod('turret', (.35, top + .01, .02), (.35, top + .14, .02), .28, 'cupola', n=12, cap_a=False)
        self.groups['turret'][2][-1] = 'cupola_top'
        self.box('turret', (.35, top + .16, .02), (.30, .04, .30), 'cupola_top')
        self.rod('turret', (.20, top + .16, .02), (.50, top + .16, .02), .02, 'steel', n=6, cap_a=False, cap_b=False)
        # AA machine gun with shield
        self.box('turret', (.35, top + .30, .06), (.11, .14, .42), 'dark_paint')
        self.box('turret', (.35, top + .30, -.19), (.26, .17, .04), 'dark_paint')
        self.rod('turret', (.35, top + .32, -.02), (.35, top + .32, -.66), .022, 'steel', n=6, cap_a=False, cap_b=False)
        self.rod('turret', (.35, top + .14, .15), (.35, top + .24, .15), .035, 'steel', n=6, cap_a=False, cap_b=False)
        # ventilators + loader hatch + antenna
        self.box('turret', (.30, top + .06, -.60), (.17, .11, .17), 'paint')
        self.box('turret', (-.25, top + .06, -.65), (.15, .10, .15), 'paint')
        self.rod('turret', (-.42, top + .01, .12), (-.42, top + .03, .12), .22, 'hatch', n=8)
        self.rod('turret', (-.62, top, .55), (-.62, top + .85, .55), .012, 'steel', n=4, end_radius=.004, cap_a=False)
        # ---- gun (local to barrel/gun_recoil) ----
        barrel = float(g['barrel_length'])
        bore = self.p['assembly']['caliber_mm'] / 2000
        n = 12
        self.rod('gun_recoil', (0, 0, -.10), (0, 0, -.36), .115, n=n, end_radius=.095)
        self.rod('gun_recoil', (0, 0, -.36), (0, 0, -barrel + .16), .095, n=n, cap_a=False, cap_b=False)
        vv = [(rr * math.cos(i * math.tau / n), rr * math.sin(i * math.tau / n), z)
              for rr, z in [(.095, -barrel + .16), (.075, -barrel + .16), (.075, -barrel + .02)]
              for i in range(n)]
        ff = [(l * n + i, l * n + (i + 1) % n, (l + 1) * n + (i + 1) % n, (l + 1) * n + i) for l in range(2) for i in range(n)]
        self.add('gun_recoil', vv, ff, ['steel'] * n + ['recess'] * n)
        # double-baffle muzzle brake (concept sheet 1; the historical 75 mm had none - logged choice)
        self.box('gun_recoil', (0, 0, -barrel + .10), (.18, .24, .045), 'steel')
        self.box('gun_recoil', (0, 0, -barrel + .02), (.18, .24, .045), 'steel')
        self.box('gun_recoil', (.075, 0, -barrel + .06), (.04, .24, .13), 'steel')
        self.box('gun_recoil', (-.075, 0, -barrel + .06), (.04, .24, .13), 'steel')
        self.box('gun_recoil', (.05, .095, -.55), (.07, .06, .14), 'steel')

    # ---- UV per face: color/geometry driven, fixed atlas tiles ----
    def face_uv_ext(self, part, points, color):
        normal = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
        center = sum(points, Vector()) / len(points)
        base = {'steel': 13, 'recess': 13, 'rubber': 12, 'canvas': 14, 'dark_paint': 1,
                'spring': 11, 'grille': 7, 'wood': 14, 'glass_head': 13}.get(color)
        axis = max(range(3), key=lambda i: abs(normal[i]))
        ax, ay = [(2, 1), (0, 2), (0, 1)][axis]
        if color == 'tread':
            return [tile_uv(4, u, v) for u, v in [(0, 0), (0, 1), (1, 1), (1, 0)]]
        if color in ('cupola', 'cupola_top'):
            return [tile_uv(15, u, v) for u, v in project(points, *(2, 1) if color == 'cupola' else (0, 2))]
        if color == 'hatch':
            if part == 'turret':
                return [tile_uv(9, u, v) for u, v in project(points, 0, 2)]
            return [tile_uv(15, u, v) for u, v in project(points, 0, 2)]
        if part == 'wheels' and abs(normal.x) > .99 and color in ('paint', 'sprocket', 'light_paint', 'steel'):
            if color in ('light_paint', 'steel'):
                tile, uv = 13, project(points, 2, 1)
            else:
                ends = [self.half, -self.half]
                zc = min(ends, key=lambda e: abs(e - center.z))
                road = all(abs(center.z - e) > .8 for e in ends)
                rc = self.r if road else .43
                yc = self.r + .10 if road else self.yc
                tile = 3 if (zc > 0 and not road) else 2
                uv = [(.5 + (p.z - zc) / rc * .465, .5 + (p.y - yc) / rc * .465) for p in points]
            return [tile_uv(tile, u, v) for u, v in uv]
        if part == 'wheels' and abs(normal.x) > .99:
            return [tile_uv(13, u, v) for u, v in project(points, 2, 1)]
        if color == 'paint':
            if part == 'hull' and abs(normal.y) > .98 and center.y > self.roof - .05 and center.z < -.7:
                return [tile_uv(15, u, v) for u, v in project(points, 0, 2)]
            return [tile_uv(0, u, v) for u, v in project(points, ax, ay)]
        if base is not None:
            return [tile_uv(base, u, v) for u, v in project(points, ax, ay)]
        return [tile_uv(1, u, v) for u, v in project(points, ax, ay)]

    def armor_uv(self, patch):
        points = [Vector(v) for v in patch['vertices']]
        g = self.g
        zone = patch['zone']
        part = patch['part']
        tile, ax, ay = 0, 0, 1
        bounds = (-g['hull_rings'][2][1], g['hull_rings'][2][1], g['hull_rings'][1][0], g['hull_rings'][2][0])
        if part == 'hull':
            if zone == 'hull_front_upper':
                # 星标比例：以首上板自身中心窗口投影，星占板面中部（旧全环 bounds 在近距离拉伸成白团）
                return [tile_uv(5, .5 + p[0] / 1.6, .5 + (p[1] - 1.42) / 1.1) for p in
                        [(v[0], v[1]) for v in patch['vertices']]]
            elif zone.startswith('hull_rear_'):
                tile = 10
                bounds = (*bounds[:2], g['hull_rings'][0][0], g['hull_rings'][2][0])
            elif zone == 'hull_roof_rear':
                tile, ax, ay = 7, 0, 2
                bounds = (*bounds[:2], g['turret_origin'][2] + g['ring_half'], g['hull_rings'][2][3])
            elif 'sides' in zone:
                tile, ax, ay = 8, 2, 1
                bounds = (g['hull_rings'][2][2], g['hull_rings'][2][3], g['hull_rings'][1][0], g['hull_rings'][2][0])
            elif 'floor' in zone:
                tile, ax, ay, bounds = 1, 0, 2, None
            elif 'roof' in zone:
                ax, ay, bounds = 0, 2, None
        elif part == 'turret':
            if zone == 'turret_sides':
                center = sum(points, Vector()) / len(points)
                tile = 6 if -.55 < center.z < 0 else 0
                ax, ay, bounds = 2, 1, None
            else:
                bounds = None
                ax, ay = (0, 2) if 'roof' in zone else (0, 1)
        else:
            bounds = None
        return [tile_uv(tile, u, v) for u, v in project(points, ax, ay, bounds)]


def create(model, seed):
    material = bpy.data.materials.new('Vehicle concept atlas')
    material.use_nodes = True
    shader = material.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .90
    image = bpy.data.images.load(str(ATLAS))
    image.pack()
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    material.node_tree.links.new(node.outputs['Color'], shader.inputs['Base Color'])

    parts = {}
    g = model.g
    for part, parent, origin in [('hull', None, (0, 0, 0)), ('turret', 'hull', g['turret_origin']),
                                 ('barrel', 'turret', g['gun_origin']), ('gun_recoil', 'barrel', (0, 0, 0))]:
        obj = bpy.data.objects.new(part, None)
        bpy.context.collection.objects.link(obj)
        if parent:
            obj.parent = parts[parent]
        obj.location = coord(origin)
        parts[part] = obj

    def mesh_object(name, parent, vertices, faces, uvs, armor=False):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([coord(v) for v in vertices], [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = parent
        mesh.materials.append(material)
        layer = mesh.uv_layers.new(name='ConceptAtlasUV')
        for face, values in zip(mesh.polygons, uvs):
            for loop, value in zip(face.loop_indices, values):
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
        obj['damage_geometry'] = armor
        return obj

    uvs = {}
    for patch in seed['armor']:
        idx = patch['triangles']
        faces = [idx[i:i + 3] for i in range(0, len(idx), 3)]
        uv = model.armor_uv(patch)
        uvs[patch['id']] = uv
        obj = mesh_object('Armor_' + patch['id'], parts[patch['part']], patch['vertices'], faces,
                          [[uv[i] for i in f] for f in faces], True)
        obj['armor_zone'] = patch['zone']
        obj['gameplay_patch_id'] = patch['id']

    for group, (vertices, faces, colors) in model.groups.items():
        parent_name = 'hull' if group in ('hull', 'wheels', 'suspension', 'track_left', 'track_right') else group
        uv_faces = [model.face_uv_ext(group, [Vector(vertices[i]) for i in f], c)
                    for f, c in zip(faces, colors)]
        mesh_object('Cosmetic_' + group, parts[parent_name], vertices, faces, uv_faces)
    return uvs


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    seed = json.loads(SEED.read_text(encoding='utf-8'))
    model = Val4k(seed)
    model.build()
    uvs = create(model, seed)
    count = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    if count > BUDGET:
        raise RuntimeError(f'val4k: {count} exceeds {BUDGET} triangles')
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    scene['vehicle_id'] = 'us_m4a3_75w_vvss_1944_val4k'
    scene['actual_vehicle_triangles'] = count
    scene['art_style'] = 'concept-fidelity validation: real-geometry silhouette features + fixed concept atlas'
    scene['seed_sha256'] = hashlib.sha256(SEED.read_bytes()).hexdigest()
    scene['validation_only'] = True
    scene['gameplay_replacement'] = False
    blend = OUT / 'us_m4a3_val4k.blend'
    glb = OUT / 'us_m4a3_val4k.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', export_extras=True,
                              export_yup=True, export_cameras=False, export_lights=False)
    manifest = {
        'vehicle_id': 'us_m4a3_75w_vvss_1944_val4k',
        'seed_sha256': scene['seed_sha256'],
        'armor_patches': len(seed['armor']),
        'actual_triangles': count,
        'triangle_budget': BUDGET,
        'validation_only': True,
        'gameplay_replacement': False,
        'source': 'VAL-4K concept-fidelity build; armor vertices unchanged from validated seed',
        'texture_file': ATLAS.relative_to(RUN).as_posix(),
        'texture_sha256': hashlib.sha256(ATLAS.read_bytes()).hexdigest(),
        'texture_origin': 'fixed package atlas PNG (reused, not regenerated)',
        'concept_reference': 'user concept sheet M4-STYLE (docs/reference/concept_m4_style_0193f12.png)',
        'concept_fidelity_notes': {
            'muzzle_brake': 'double baffle per concept sheet; historical M4A3(75)W had none - logged deliberate deviation',
            'road_wheels': '6 + VVSS 3 bogies + return rollers (historical and concept agree)',
            'drive_sprocket_rear_idler_front': 'historical and concept agree'},
        'armor_uv': uvs,
        'generator': 'authoring/val4k/build_val4k.py',
    }
    glb.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('VAL4K_MODEL_PASS', count, flush=True)


if __name__ == '__main__':
    run()
