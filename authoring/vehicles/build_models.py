"""Blender authoring pass. Run export_historical_model_seed.gd, then Blender -b -t 4 -P this file.

Coordinates exposed here are Godot meters (+Y up, -Z forward). Armor comes from
the gameplay layout and stays untouched. Detail sizes are artistic estimates.
Original meshes only; no downloaded models, textures, add-ons or dependencies.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
AUTHOR = ROOT / 'authoring/vehicles'
OUTPUT = ROOT / 'assets/vehicles'
OUTPUT.mkdir(parents=True, exist_ok=True)


def coord(p):
    return (p[0], -p[2], p[1])


def material(name, color, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.78
    shader.inputs['Metallic'].default_value = metal
    return m


class Model:
    def __init__(self, seed):
        self.seed, self.p = seed, seed['packet']
        self.g = self.p['geometry']
        self.groups = {}
        self.parts = {}
        self.mats = {
            'Olive': material('Olive drab', (0.20, 0.25, 0.13)),
            'Edge': material('Paint on fittings', (0.28, 0.32, 0.19)),
            'Dark': material('Recesses', (0.055, 0.065, 0.045)),
            'Rubber': material('Rubber', (0.035, 0.040, 0.033)),
            'Steel': material('Worn steel', (0.12, 0.14, 0.115), 0.45),
            'Canvas': material('Canvas', (0.30, 0.28, 0.18)),
            'Glass': material('Optics', (0.075, 0.13, 0.15), 0.15),
        }
        for part, parent, origin in [('hull', None, (0, 0, 0)),
                                     ('turret', 'hull', self.g['turret_origin']),
                                     ('barrel', 'turret', self.g['gun_origin']),
                                     ('gun_recoil', 'barrel', (0, 0, 0))]:
            obj = bpy.data.objects.new(part, None)
            bpy.context.collection.objects.link(obj)
            if parent:
                obj.parent = self.parts[parent]
            obj.location = coord(origin)
            self.parts[part] = obj

    def mesh(self, name, part, vertices, faces, mat, bevel=0):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([coord(p) for p in vertices], [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = self.parts[part]
        obj.data.materials.append(self.mats[mat])
        if bevel:
            modifier = obj.modifiers.new('Small manufactured edge', 'BEVEL')
            modifier.width, modifier.segments = bevel, 1
            modifier.limit_method = 'ANGLE'
        return obj

    def add(self, part, mat, vertices, faces):
        vv, ff = self.groups.setdefault((part, mat), ([], []))
        offset = len(vv)
        vv.extend(vertices)
        ff.extend(tuple(i + offset for i in face) for face in faces)

    def box(self, part, pos, size, mat='Olive'):
        verts = [(pos[0]+x*size[0]/2, pos[1]+y*size[1]/2, pos[2]+z*size[2]/2)
                 for x, y, z in [(-1,-1,-1), (1,-1,-1), (1,1,-1), (-1,1,-1),
                                 (-1,-1,1), (1,-1,1), (1,1,1), (-1,1,1)]]
        self.add(part, mat, verts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)])

    def rod(self, part, a, b, radius, mat='Olive', n=12, end_radius=None, caps=True):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        u = axis.cross(Vector((0,1,0)) if abs(axis.y) < 0.9 else Vector((1,0,0))).normalized()
        v = axis.cross(u)
        rr = radius if end_radius is None else end_radius
        verts = [p + r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v)
                 for p, r in [(a,radius),(b,rr)] for i in range(n)]
        faces = [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        if caps:
            faces += [tuple(reversed(range(n))), tuple(range(n,n*2))]
        self.add(part, mat, verts, faces)

    def disk(self, part, pos, radius, depth, mat='Olive', axis='x', n=16):
        a, b = list(pos), list(pos)
        index = {'x':0,'y':1,'z':2}[axis]
        a[index] -= depth/2
        b[index] += depth/2
        self.rod(part,a,b,radius,mat,n)

    def handle(self, part, pos, span=0.15):
        x,y,z = pos
        self.rod(part,(x-span/2,y,z),(x-span/2,y+0.045,z),0.012,'Steel',6)
        self.rod(part,(x+span/2,y,z),(x+span/2,y+0.045,z),0.012,'Steel',6)
        self.rod(part,(x-span/2,y+0.045,z),(x+span/2,y+0.045,z),0.012,'Steel',6)

    def hatch(self, part, x, y, z, radius):
        self.disk(part,(x,y,z),radius+0.022,0.03,'Dark','y')
        self.disk(part,(x,y+0.025,z),radius,0.035,'Edge','y')
        self.box(part,(x,y+0.055,z+radius*0.72),(radius*0.72,0.045,0.06))
        self.handle(part,(x,y+0.05,z-radius*0.45))

    def build(self):
        p,g = self.p,self.g
        width = p['facts']['dimensions.width_m']['value']
        length = p['facts']['dimensions.reference_length_m']['value']
        roof,radius,tw = g['hull_rings'][2][0],g['wheel_radius'],g['track_width']
        vvss = p['assembly']['suspension'] == 'VVSS'
        # Original gameplay faces preserved as individually named, editable objects.
        for patch in self.seed['armor']:
            tri = patch['triangles']
            obj = self.mesh('Armor_'+patch['id'],patch['part'],patch['vertices'],
                            [tri[i:i+3] for i in range(0,len(tri),3)],'Olive')
            obj['armor_zone'] = patch['zone']
            obj['gameplay_patch_id'] = patch['id']
            obj['geometry_status'] = 'estimated'
        # VVSS pairs are deliberately grouped around three bogies.
        span = length*0.65
        wheel_z = ([c+d for c in [-span*0.36,0,span*0.36] for d in [-radius*1.02,radius*1.02]]
                   if vvss else [-span/2+span*i/(g['wheel_count']-1) for i in range(int(g['wheel_count']))])
        for side in [-1,1]:
            x = side*(width/2-tw/2)
            for z in wheel_z:
                y = radius+0.10
                self.disk('hull',(x,y,z),radius,tw*0.74,'Rubber',n=20)
                face = x+side*tw*0.40
                self.disk('hull',(face,y,z),radius*0.81,0.045,'Olive',n=16)
                self.disk('hull',(face+side*0.025,y,z),radius*0.36,0.065,'Edge')
                self.disk('hull',(face+side*0.063,y,z),radius*0.14,0.055,'Steel')
                for i in range(6):
                    a = i*math.tau/6
                    self.disk('hull',(face+side*0.03,y+math.sin(a)*radius*0.53,z+math.cos(a)*radius*0.53),radius*0.12,0.012,'Dark',n=8)
                if not vvss:
                    self.rod('hull',(x-side*tw*0.3,y,z),(x-side*tw*0.3,y+0.22,z+0.25),0.07)
            if vvss:
                for z in [-span*0.36,0,span*0.36]:
                    self.box('hull',(x,0.78,z),(0.29,0.29,0.34))
                    for dz in [-0.105,0.105]:
                        self.rod('hull',(x+side*0.13,0.65,z+dz),(x+side*0.13,0.91,z+dz),0.065,'Steel')
                        self.rod('hull',(x,0.61,z),(x,radius+0.10,z+math.copysign(radius*1.02,dz)),0.09)
                    self.disk('hull',(x,1.0,z+0.22),0.115,tw*0.72,'Rubber')
                    self.disk('hull',(x+side*tw*0.38,1.0,z+0.22),0.075,0.03,'Edge')
            else:
                for z in [-span*0.36,0,span*0.36]:
                    self.disk('hull',(x,0.96,z),0.11,tw*0.66,'Rubber')
            for z in [-length*0.402,length*0.402]:
                self.disk('hull',(x,0.56,z),0.445,tw*0.72,'Steel',n=20)
                self.disk('hull',(x+side*tw*0.39,0.56,z),0.37,0.06,'Olive',n=20)
                for i in range(10):
                    a = i*math.tau/10
                    self.disk('hull',(x+side*tw*0.425,0.56+math.sin(a)*0.26,z+math.cos(a)*0.26),0.065,0.012,'Dark',n=8)
                self.disk('hull',(x+side*tw*0.44,0.56,z),0.14,0.10,'Edge')
            # Individual mudguard panels, ribs and lifting fittings.
            for i in range(5):
                zz = -length*0.37+i*length*0.185
                self.box('hull',(x,1.16,zz),(tw+0.10,0.045,length*0.18))
                self.box('hull',(x,1.19,zz-length*0.087),(tw+0.11,0.025,0.03),'Edge')
            front_z = g['hull_rings'][2][2]
            self.hatch('hull',side*0.51,roof+0.02,front_z+0.60,0.25 if 'm24' in p['id'] else 0.28)
            self.box('hull',(side*0.51,roof+0.105,front_z+0.41),(0.18,0.075,0.12),'Dark')
            self.box('hull',(side*0.51,roof+0.12,front_z+0.355),(0.12,0.035,0.025),'Glass')
            self.disk('hull',(side*0.87,roof-0.05,front_z-0.055),0.105,0.08,'Steel','z')
            self.disk('hull',(side*0.87,roof-0.05,front_z-0.10),0.079,0.012,'Glass','z')
            for dx in [-0.13,0.13]:
                self.rod('hull',(side*0.87+dx,roof-0.18,front_z-0.1),(side*0.87+dx,roof+0.08,front_z-0.1),0.012,'Steel',6)
            self.rod('hull',(side*0.87-0.13,roof+0.08,front_z-0.1),(side*0.87+0.13,roof+0.08,front_z-0.1),0.012,'Steel',6)
            rear = g['hull_rings'][2][3]
            self.handle('hull',(side*0.93,roof+0.01,rear-0.15))
            self.rod('hull',(side*0.80,0.70,rear),(side*0.80,0.70,rear+0.15),0.06,'Steel')
        # Engine deck changes size with each hull and leaves turret ring clear.
        deck_start = g['turret_origin'][2]+max(t[1] for t in g['turret_outline'])+0.15
        deck_end = g['hull_rings'][2][3]-0.12
        deck_len = max(0.3,deck_end-deck_start)
        for x in [-0.48,0.48]:
            self.box('hull',(x,roof+0.014,(deck_start+deck_end)/2),(0.82,0.025,deck_len),'Dark')
            for i in range(14):
                self.box('hull',(x,roof+0.032,deck_start+(i+0.5)*deck_len/14),(0.76,0.035,deck_len/23))
        # Low-profile tools and clamps on the rear deck.
        self.rod('hull',(-0.87,roof+0.10,deck_start),(-0.87,roof+0.10,deck_end),0.024,'Canvas',8)
        self.box('hull',(-0.87,roof+0.09,deck_end-0.03),(0.15,0.04,0.23),'Steel')
        ty = g['turret_top']
        commander_side = -1 if 'm24' in p['id'] else 1
        if not g['open_top']:
            cx = commander_side*0.46
            self.disk('turret',(cx,ty+0.10,0.43),0.30,0.18,'Olive','y')
            self.disk('turret',(cx,ty+0.18,0.43),0.32,0.03,'Edge','y')
            for i in range(6):
                a = i*math.tau/6
                self.box('turret',(cx+math.cos(a)*0.287,ty+0.11,0.43+math.sin(a)*0.287),(0.085,0.06,0.065),'Glass')
            self.hatch('turret',cx,ty+0.195,0.43,0.27)
            self.hatch('turret',-commander_side*0.43,ty+0.025,0.30,0.25)
            self.box('turret',(0.26,ty+0.04,-0.51),(0.22,0.09,0.16))
            self.box('turret',(0.26,ty+0.045,-0.596),(0.14,0.045,0.018),'Glass')
        else:
            # Visible open compartment, breech and seats; no invented roof plate.
            for row in p['crew']:
                if row['part'] != 'turret':
                    continue
                x,y,z = row['position']
                self.disk('turret',(x,y-0.22,z),0.17,0.07,'Canvas','y')
                self.rod('turret',(x,y-0.26,z),(x,-0.1,z),0.035,'Steel')
            self.box('barrel',(0,0,0.37),(0.34,0.31,0.64),'Steel')
            self.box('barrel',(0,0.02,0.71),(0.29,0.27,0.10),'Edge')
            self.disk('barrel',(-0.35,-0.14,0.25),0.14,0.03,'Steel')
            self.rod('barrel',(-0.22,0.14,0.12),(-0.22,0.14,0.62),0.052,'Steel')
        antenna_x = -commander_side*0.65
        self.disk('turret',(antenna_x,ty+0.07,0.86),0.08,0.14,'Steel','y')
        self.rod('turret',(antenna_x,ty+0.14,0.86),(antenna_x,ty+1.03,0.86),0.010,'Steel',6,end_radius=0.004)
        for x in [-0.70,0.70]:
            self.handle('turret',(x,ty*0.90,0.80))
        # Open bore with a real inner wall. Tube follows the existing recoil pivot.
        bl, bore = g['barrel_length'],p['assembly']['caliber_mm']/2000
        self.rod('gun_recoil',(0,0,-0.12),(0,0,-0.43),bore+0.11,'Olive',20,end_radius=bore+0.07,caps=False)
        self.rod('gun_recoil',(0,0,-0.40),(0,0,-bl),bore+0.055,'Steel',20,end_radius=bore+0.022,caps=False)
        self.rod('gun_recoil',(0,0,-bl),(0,0,-bl+0.25),bore,'Dark',20,caps=False)
        # Annular muzzle lip, never a filled cap.
        verts = [(r*math.cos(i*math.tau/20),r*math.sin(i*math.tau/20),-bl)
                 for r in [bore,bore+0.022] for i in range(20)]
        self.add('gun_recoil','Steel',verts,[(i,(i+1)%20,(i+1)%20+20,i+20) for i in range(20)])
        if g.get('muzzle_brake',False):
            # One open expansion chamber and large lateral ports, matching M26 reference silhouette.
            for zz in [-bl,-bl+0.32]:
                ring = [(r*math.cos(i*math.tau/20),r*math.sin(i*math.tau/20),z)
                        for z,r in [(zz,bore),(zz,0.155),(zz+0.035,0.155),(zz+0.035,bore)] for i in range(20)]
                faces=[]
                for level in range(4):
                    for i in range(20):
                        faces.append((level*20+i,level*20+(i+1)%20,((level+1)%4)*20+(i+1)%20,((level+1)%4)*20+i))
                self.add('gun_recoil','Steel',ring,faces)
            for yy in [-0.125,0.125]:
                self.box('gun_recoil',(0,yy,-bl+0.18),(0.15,0.055,0.32),'Steel')
        # Mantlet edge relief stays behind the shot-query front plane.
        hw,hh = g['mantlet_half_width'],g['mantlet_half_height']
        shield_part = 'turret' if g.get('separate_rotor_shield',False) else 'barrel'
        offset = g['gun_origin'] if shield_part == 'turret' else [0,0,0]
        for x in [-hw+0.025,hw-0.025]:
            self.box(shield_part,(offset[0]+x,offset[1],offset[2]-0.06),(0.045,hh*2,0.08),'Edge')
        for y in [-hh+0.022,hh-0.022]:
            self.box(shield_part,(offset[0],offset[1]+y,offset[2]-0.06),(hw*2,0.04,0.08),'Edge')
        for (part,mat),(verts,faces) in self.groups.items():
            obj = self.mesh('Cosmetic_'+part+'_'+mat,part,verts,faces,mat,0.004 if mat in ['Olive','Edge'] else 0)
            obj['damage_geometry'] = False
            obj['detail_dimensions'] = 'artistic estimates'


def run():
    for seed_path in sorted((AUTHOR/'seeds').glob('*.json')):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version = 0
        seed = json.loads(seed_path.read_text(encoding='utf-8'))
        model = Model(seed)
        model.build()
        scene = bpy.context.scene
        scene.unit_settings.system = 'METRIC'
        scene.unit_settings.scale_length = 1
        scene['vehicle_id'] = seed['packet']['id']
        scene['model_limitations'] = 'Original faceted reconstruction; armor and detail dimensions are estimates, not scan data.'
        scene['seed_sha256'] = hashlib.sha256(seed_path.read_bytes()).hexdigest()
        # Useful solid viewport defaults when an artist opens the source file.
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == 'VIEW_3D':
                    area.spaces.active.shading.color_type = 'MATERIAL'
                    area.spaces.active.region_3d.view_distance = 11
                    area.spaces.active.region_3d.view_location = (0,0,1.1)
        bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/(seed_path.stem+'.blend')))
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(seed_path.stem+'.glb')),export_format='GLB',
                                  export_apply=True,export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
        manifest = {'vehicle_id':seed_path.stem,'blender_version':bpy.app.version_string,
                    'seed_sha256':scene['seed_sha256'],
                    'blend_sha256':hashlib.sha256((AUTHOR/(seed_path.stem+'.blend')).read_bytes()).hexdigest(),
                    'glb_sha256':hashlib.sha256((OUTPUT/(seed_path.stem+'.glb')).read_bytes()).hexdigest(),
                    'armor_patches':len(seed['armor']),'source':'Original Blender geometry',
                    'cosmetic_geometry_affects_damage':False}
        (OUTPUT/(seed_path.stem+'.manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
        print('BLENDER_MODEL_PASS '+seed_path.stem)


if __name__ == '__main__':
    run()
