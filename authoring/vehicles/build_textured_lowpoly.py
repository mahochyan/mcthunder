"""Author the four production vehicles at roughly 1000 triangles each.

Armor vertices/topology and articulated pivots come unchanged from the existing
validated seeds. Mechanical surface detail uses the concept-derived atlas;
silhouette features remain real geometry. No modifier creates hidden extra faces.
"""
import bpy
import sys
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector

AUTHOR=Path(__file__).resolve().parent
ROOT=AUTHOR.parents[1]
sys.path.insert(0,str(AUTHOR.parent/'poly_budget'))
from build_preview import Model as Geometry, coord
from texture_preview import tile_uv, project
sys.path.insert(0,str(AUTHOR))
import style_metadata as style

ATLAS=ROOT/'assets/vehicles/textures/vehicle_concept_atlas_v1.png'


class LowModel(Geometry):
    def __init__(self, seed):
        super().__init__(1100)
        self.seed=seed; self.p=seed['packet']; self.g=self.p['geometry']
        self.parts={}; self.uvs={}; self.wheels=[]
        self.material=bpy.data.materials.new('Vehicle concept atlas'); self.material.use_nodes=True
        shader=self.material.node_tree.nodes['Principled BSDF']
        shader.inputs['Roughness'].default_value=.90
        image=bpy.data.images.load(str(ATLAS)); image.pack()
        node=self.material.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image
        self.material.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
        self.material.use_backface_culling=False
        for part,parent,origin in [('hull',None,(0,0,0)),('turret','hull',self.g['turret_origin']),
                                   ('barrel','turret',self.g['gun_origin']),('gun_recoil','barrel',(0,0,0))]:
            obj=bpy.data.objects.new(part,None); bpy.context.collection.objects.link(obj)
            if parent: obj.parent=self.parts[parent]
            obj.location=coord(origin); self.parts[part]=obj

    def armor_uv(self, patch):
        points=[Vector(v) for v in patch['vertices']]
        g=self.g; zone=patch['zone']; part=patch['part']
        tile=0; ax,ay=0,1
        bounds=(-g['hull_rings'][2][1],g['hull_rings'][2][1],g['hull_rings'][1][0],g['hull_rings'][2][0])
        if part=='hull':
            if zone=='hull_front_upper': tile=5
            elif zone.startswith('hull_rear_'): tile=10; bounds=(*bounds[:2],g['hull_rings'][0][0],g['hull_rings'][2][0])
            elif zone=='hull_roof_rear':
                tile=7; ax,ay=0,2
                bounds=(*bounds[:2],g['turret_origin'][2]+g['ring_half'],g['hull_rings'][2][3])
            elif 'sides' in zone:
                tile=8; ax,ay=2,1
                bounds=(g['hull_rings'][2][2],g['hull_rings'][2][3],g['hull_rings'][1][0],g['hull_rings'][2][0])
            elif 'floor' in zone: tile=1; ax,ay=0,2; bounds=None
            elif 'roof' in zone: ax,ay=0,2; bounds=None
        elif part=='turret':
            if zone=='turret_sides':
                center=sum(points,Vector())/len(points)
                tile=6 if -.55<center.z<0 else 0
                ax,ay=2,1; bounds=None
            else: bounds=None; ax,ay=(0,2) if 'roof' in zone else (0,1)
        else: bounds=None
        return [tile_uv(tile,u,v) for u,v in project(points,ax,ay,bounds)]

    def mesh_object(self,name,parent,vertices,faces,uvs,armor=False):
        mesh=bpy.data.meshes.new(name); mesh.from_pydata([coord(v) for v in vertices],[],faces); mesh.update()
        obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); obj.parent=self.parts[parent]
        mesh.materials.append(self.material)
        uv=mesh.uv_layers.new(name='ConceptAtlasUV')
        for face,values in zip(mesh.polygons,uvs):
            for loop,value in zip(face.loop_indices,values): uv.data[loop].uv=value
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
        tri=obj.modifiers.new('Export triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
        obj.select_set(False)
        obj['damage_geometry']=armor
        return obj

    def wheel(self,side,z,r,y):
        g=self.g; width=self.p['facts']['dimensions.width_m']['value']; tw=g['track_width']
        x=side*(width/2-tw/2); outer=x+side*tw*.39
        self.rod('wheels',(x-side*tw*.25,y,z),(outer,y,z),r,'rubber',n=8,cap_a=False)
        self.groups['wheels'][2][-1]='paint'
        self.wheels.append((outer,y,z,r))

    def track(self,side):
        g=self.g; width=self.p['facts']['dimensions.width_m']['value']; length=self.p['facts']['dimensions.reference_length_m']['value']
        x=side*(width/2-g['track_width']/2); tw=g['track_width']; half=length*.402
        radius=.52; y=.56; outline=[]; inner=[]
        for center,base in [(half,-math.pi/2),(-half,math.pi/2)]:
            for i in range(4):
                angle=base+i*math.pi/3
                outline.append((y+radius*math.sin(angle),center+radius*math.cos(angle)))
                inner.append((y+(radius-.07)*math.sin(angle),center+(radius-.07)*math.cos(angle)))
        n=len(outline); name='track_left' if side<0 else 'track_right'
        vv=[(xx,yy,zz) for xx,points in [(x-tw/2,outline),(x+tw/2,outline),(x+tw/2,inner),(x-tw/2,inner)] for yy,zz in points]
        ff=[]; cc=[]
        for level in range(4):
            for i in range(n):
                a,b,c,d=[Vector(vv[j]) for j in [level*n+i,level*n+(i+1)%n,((level+1)%4)*n+(i+1)%n,((level+1)%4)*n+i]]
                count=4 if level==0 and (b-a).length>3 else 1
                for j in range(count):
                    quad=[a.lerp(b,j/count),a.lerp(b,(j+1)/count),d.lerp(c,(j+1)/count),d.lerp(c,j/count)]
                    start=len(vv); vv.extend(tuple(p) for p in quad); ff.append(tuple(range(start,start+4)))
                    cc.append('tread' if level==0 else 'steel')
        self.add(name,vv,ff,cc)

    def build(self):
        g=self.g; p=self.p
        width=p['facts']['dimensions.width_m']['value']; length=p['facts']['dimensions.reference_length_m']['value']
        roof=g['hull_rings'][2][0]; top=g['turret_top']; tw=g['track_width']; r=g['wheel_radius']
        vvss=p['assembly']['suspension']=='VVSS'
        for patch in self.seed['armor']:
            indices=patch['triangles']; faces=[indices[i:i+3] for i in range(0,len(indices),3)]
            uv=self.armor_uv(patch); self.uvs[patch['id']]=uv
            obj=self.mesh_object('Armor_'+patch['id'],patch['part'],patch['vertices'],faces,[[uv[i] for i in f] for f in faces],True)
            obj['armor_zone']=patch['zone']; obj['gameplay_patch_id']=patch['id']
        span=length*.60
        centers=[-span*.34,0,span*.34]
        wheel_z=([c+d for c in centers for d in [-r*1.02,r*1.02]] if vvss else [-span/2+span*i/(int(g['wheel_count'])-1) for i in range(int(g['wheel_count']))])
        for side in [-1,1]:
            x=side*(width/2-tw/2)
            for z in wheel_z: self.wheel(side,z,r,r+.10)
            for z in [-length*.402,length*.402]: self.wheel(side,z,.43,.56)
            self.track(side)
            self.box('hull',(x,1.18,.05),(tw+.08,.035,length*.89),'paint')
            if vvss:
                for z in centers:
                    # A connected yoke silhouette, front face plus the three most exposed edges.
                    outline=[(-.12,.98),(.12,.98),(.12,.75),(r*1.16,r+.12),(r*.90,r-.02),(0,.66),(-r*.90,r-.02),(-r*1.16,r+.12),(-.12,.75)]
                    vv=[(x+side*xx,y,z+zz) for xx in [tw*.38,tw*.46] for zz,y in outline]
                    n=len(outline); ff=[tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in [2,3,6]]
                    self.add('suspension',vv,ff,'dark_paint')
            else:
                for z in wheel_z:
                    self.rod('suspension',(x+side*tw*.40,r+.10,z),(x+side*tw*.40,r+.33,z+.24),.055,'dark_paint',n=3,cap_a=False,cap_b=False)
        # Hollow main gun and muzzle ring; motion belongs to the existing recoil pivot.
        barrel=float(g['barrel_length']); n=8; bore=p['assembly']['caliber_mm']/2000
        self.rod('gun_recoil',(0,0,-.10),(0,0,-.36),bore*2.2,n=n,end_radius=bore*1.7)
        self.rod('gun_recoil',(0,0,-.36),(0,0,-barrel),bore*1.7,n=n,end_radius=bore*1.35,cap_a=False,cap_b=False)
        vv=[(rr*math.cos(i*math.tau/n),rr*math.sin(i*math.tau/n),z) for rr,z in [(bore*1.35,-barrel),(bore,-barrel),(bore,-barrel+.18)] for i in range(n)]
        ff=[(l*n+i,l*n+(i+1)%n,(l+1)*n+(i+1)%n,(l+1)*n+i) for l in range(2) for i in range(n)]
        self.add('gun_recoil',vv,ff,['steel']*n+['recess']*n)
        if g.get('muzzle_brake',False):
            for side in [-1,1]: self.box('gun_recoil',(side*.13,0,-barrel+.10),(.08,.20,.30),'steel')
        if not g['open_top']:
            self.rod('turret',(.35,top,-.02),(.35,top+.12,-.02),.25,n=6,cap_a=False)
        else:
            self.box('turret',(0,.05,.65),(1.05,.08,1.30),'dark_paint')
            self.box('gun_recoil',(0,0,.34),(.32,.30,.55),'dark_paint')
        self.box('turret',(.35,top+.28,.04),(.11,.13,.32),'dark_paint')
        self.rod('turret',(.35,top+.12,.12),(.35,top+.28,.12),.025,'steel',n=3,cap_a=False,cap_b=False)
        self.rod('turret',(.35,top+.30,-.12),(.35,top+.30,-.56),.02,'steel',n=3,cap_a=False,cap_b=False)
        self.rod('turret',(-.60,top-.06,.38),(-.60,top+.66,.38),.008,'steel',n=3,cap_a=False,cap_b=False)
        self.box('hull',(0,roof+.12,g['hull_rings'][2][3]-.40),(1.15,.23,.34),'canvas')
        for side in [-1,1]:
            self.box('hull',(side*.45,roof+.025,g['hull_rings'][2][2]+.55),(.38,.05,.40),'hatch')
            self.rod('hull',(side*(g['hull_rings'][2][1]-.08),roof-.12,g['hull_rings'][2][2]-.15),
                     (side*(g['hull_rings'][2][1]-.08),roof-.12,g['hull_rings'][2][2]-.25),.075,'steel',n=6,cap_a=False)
        for group,(vertices,faces,colors) in self.groups.items():
            parent='hull' if group in ('hull','wheels','suspension','track_left','track_right') else group
            name='Cosmetic_hull_Olive' if group=='hull' else 'Cosmetic_'+group
            uv_faces=[]
            for face,color in zip(faces,colors):
                points=[Vector(vertices[i]) for i in face]; center=sum(points,Vector())/len(points)
                normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
                axis=max(range(3),key=lambda i:abs(normal[i])); ax,ay=[(2,1),(0,2),(0,1)][axis]
                tile={'rubber':12,'steel':13,'recess':13,'dark_paint':1,'canvas':14}.get(color,0)
                uv=project(points,ax,ay)
                if group=='wheels' and abs(normal.x)>.99:
                    x,y,z,r=min(self.wheels,key=lambda v:(Vector(v[:3])-center).length)
                    tile=3 if z<-length*.38 else 2
                    uv=[(.5+(p.z-z)/r*.465,.5+(p.y-y)/r*.465) for p in points]
                elif group.startswith('track') and color=='tread': tile=4; uv=[(0,0),(0,1),(1,1),(1,0)]
                elif group=='suspension' and abs(normal.x)>.99: tile=11
                elif group=='turret' and abs(normal.y)>.99 and abs(center.y-top-.12)<.01: tile=9
                elif group=='hull' and color=='hatch' and abs(normal.y)>.99: tile=15
                uv_faces.append([tile_uv(tile,u,v) for u,v in uv])
            self.mesh_object(name,parent,vertices,faces,uv_faces)


def run():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for source in sorted((AUTHOR/'seeds').glob('*.json')):
        if args and source.stem not in args: continue
        bpy.ops.wm.read_factory_settings(use_empty=True); bpy.context.preferences.filepaths.save_version=0
        seed=json.loads(source.read_text(encoding='utf-8')); model=LowModel(seed); model.build()
        count=sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH')
        if count>1100: raise RuntimeError(f'{source.stem}: {count} exceeds 1100 triangles')
        scene=bpy.context.scene; scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
        scene['vehicle_id']=source.stem; scene['actual_vehicle_triangles']=count
        scene['art_style']='low-poly silhouette geometry with concept-derived texture detail'
        scene['seed_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
        blend=AUTHOR/(source.stem+'.blend'); glb=ROOT/'assets/vehicles'/(source.stem+'.glb')
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
        manifest={'vehicle_id':source.stem,'seed_sha256':scene['seed_sha256'],'armor_patches':len(seed['armor']),
                  'source':'Original Blender geometry with ImageGen concept-derived texture','cosmetic_geometry_affects_damage':False}
        style.metadata(manifest,blend,glb)
        manifest.update({'generator':'authoring/vehicles/build_textured_lowpoly.py','actual_triangles':count,
                         'triangle_budget_with_runtime_tracks':1100,'lod_policy':'One 1100-triangle maximum model; texture-scroll tracks; no duplicated track shoes',
                         'texture_file':ATLAS.relative_to(ROOT).as_posix(),'texture_sha256':hashlib.sha256(ATLAS.read_bytes()).hexdigest(),
                         'texture_origin':'Built-in ImageGen, user-supplied M4-style concept reference',
                         'texture_prompt':'authoring/poly_budget/ATLAS_PROMPT.txt','armor_uv':model.uvs})
        glb.with_suffix('.manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
        print('LOWPOLY_MODEL_PASS',source.stem,count,flush=True)


if __name__=='__main__': run()
