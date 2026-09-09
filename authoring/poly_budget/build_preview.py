"""Original M4-style polygon-budget studies. Blender 5.2.1 LTS; no game changes.

The user's concept sheets guide material/shape language, not historical dimensions.
Outputs contain actual triangulated model geometry; studio props never count as tank faces.
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'output'
OUT.mkdir(parents=True, exist_ok=True)

PALETTE = {
    'paint': '62644d', 'light_paint': '7d8061', 'dark_paint': '494d3b',
    'rubber': '292c29', 'track': '494d48', 'steel': '66695f',
    'canvas': '88795d', 'glass': '273b40', 'recess': '292d25',
}


def srgb(hex_code):
    values = [int(hex_code[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in values)


def coord(p):
    return (p[0], -p[2], p[1])


class Model:
    def __init__(self, budget):
        self.budget = budget
        self.groups = {}
        self.features = []

    @property
    def triangles(self):
        return sum(sum(len(f)-2 for f in value[1]) for value in self.groups.values())

    def add(self, part, verts, faces, colors='paint'):
        vertices, polygons, materials = self.groups.setdefault(part, ([], [], []))
        offset = len(vertices)
        vertices.extend(tuple(v) for v in verts)
        polygons.extend(tuple(offset+i for i in face) for face in faces)
        materials.extend([colors]*len(faces) if isinstance(colors, str) else colors)

    def optional(self, label, build):
        before = {k: tuple(len(a) for a in value) for k, value in self.groups.items()}
        build()
        if self.triangles > self.budget:
            for key in list(self.groups):
                if key not in before:
                    del self.groups[key]
                else:
                    for array, length in zip(self.groups[key], before[key]):
                        del array[length:]
            return False
        self.features.append(label)
        return True

    def box(self, part, p, size, color='paint'):
        vv = [(p[0]+x*size[0]/2, p[1]+y*size[1]/2, p[2]+z*size[2]/2)
              for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                            (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.add(part, vv, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)], color)

    def rod(self, part, a, b, radius, color='paint', n=8, end_radius=None, cap_a=True, cap_b=True):
        a,b = Vector(a),Vector(b)
        axis = (b-a).normalized()
        u = axis.cross(Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))).normalized()
        v = axis.cross(u)
        rr = radius if end_radius is None else end_radius
        vv = [p+r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v)
              for p,r in [(a,radius),(b,rr)] for i in range(n)]
        ff = [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        cc = [color]*len(ff)
        if cap_a: ff.append(tuple(reversed(range(n)))); cc.append(color)
        if cap_b: ff.append(tuple(range(n,n*2))); cc.append(color)
        self.add(part,vv,ff,cc)

    def rings(self, part, loops, color='paint', top=True, bottom=True):
        n=len(loops[0]); vv=[p for loop in loops for p in loop]; ff=[]; cc=[]
        for level in range(len(loops)-1):
            for i in range(n):
                ff.append((level*n+i,level*n+(i+1)%n,(level+1)*n+(i+1)%n,(level+1)*n+i))
                cc.append(color if i%5 else 'light_paint')
        if bottom: ff.append(tuple(reversed(range(n)))); cc.append('dark_paint')
        if top: ff.append(tuple(range((len(loops)-1)*n,len(loops)*n))); cc.append('paint')
        self.add(part,vv,ff,cc)

    def wheel(self, side, z, radius, n, hub=False, y=None):
        y = radius+.12 if y is None else y
        x = side*1.29
        # Inside cap is hidden against hull; the outer circular face is retained.
        outer = x+side*.17
        a,b=(x-side*.12,y,z),(outer,y,z)
        self.rod('wheels',a,b,radius,'rubber',n=n,cap_a=False)
        # Replace just the outer-cap paint assignment; no decal plane or fake extra faces.
        self.groups['wheels'][2][-1]='paint'
        if hub:
            self.rod('wheels',(outer,y,z),(outer+side*.035,y,z),radius*.73,'light_paint',n=n,cap_a=False)
            self.rod('wheels',(outer+side*.036,y,z),(outer+side*.09,y,z),radius*.22,'steel',n=max(6,n//2),cap_a=False)

    def track(self, side, arc_steps):
        x=side*1.29; width=.44; r=.50; half=2.52; y=.54
        outline=[]; inward=[]
        for center, base in [(half,-math.pi/2),(-half,math.pi/2)]:
            for i in range(arc_steps):
                a=base+i*math.pi/(arc_steps-1)
                outline.append((y+r*math.sin(a),center+r*math.cos(a)))
                inward.append((y+(r-.085)*math.sin(a),center+(r-.085)*math.cos(a)))
        n=len(outline)
        vv=[(xx,yy,zz) for xx,points in [(x-width/2,outline),(x+width/2,outline),
                                        (x+width/2,inward),(x-width/2,inward)] for yy,zz in points]
        ff=[]; cc=[]
        for level in range(4):
            for i in range(n):
                ff.append((level*n+i,level*n+(i+1)%n,((level+1)%4)*n+(i+1)%n,((level+1)%4)*n+i))
                cc.append('track' if level!=0 or i%2==0 else 'steel')
        self.add('tracks',vv,ff,cc)

    def track_links(self, count):
        half,r,y=2.52,.50,.54
        perimeter=half*4+math.tau*r
        for side in [-1,1]:
            for i in range(count):
                d=i*perimeter/count
                if d<half*2: z=-half+d; yy=y-r; angle=0
                elif d<half*2+math.pi*r:
                    a=(d-half*2)/r-math.pi/2; z=half+r*math.cos(a); yy=y+r*math.sin(a); angle=a+math.pi/2
                elif d<half*4+math.pi*r: z=half-(d-half*2-math.pi*r); yy=y+r; angle=math.pi
                else:
                    a=(d-half*4-math.pi*r)/r+math.pi/2; z=-half+r*math.cos(a); yy=y+r*math.sin(a); angle=a+math.pi/2
                # Raised tread ribs: six vertices / eight triangles, underside omitted.
                x=side*1.29; span=.46; length=perimeter/count*.48; depth=.042
                normal=Vector((0,-math.cos(angle),math.sin(angle)))
                tangent=Vector((0,math.sin(angle),math.cos(angle)))
                center=Vector((x,yy,z))
                vv=[center+Vector((sx*span/2,0,0))+tangent*(sz*length/2)+normal*h
                    for sx,sz,h in [(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0),(-1,0,depth),(1,0,depth)]]
                self.add('tracks',vv,[(0,1,5,4),(4,5,2,3),(0,4,3),(1,2,5)],'steel')

    def build(self):
        level=0 if self.budget<=1100 else (1 if self.budget<=2700 else 2)
        n=[8,12,16][level]
        # Main hull follows the existing M4-sized envelope with clearer corner bevels.
        hull=[]
        for yy,w,front,rear,cut in [(.47,.93,-2.51,2.72,.18),(.95,1.00,-2.85,2.98,.22),(1.86,1.0,-1.78,2.78,.15)]:
            hull.append([(-w+cut,yy,front),(w-cut,yy,front),(w,yy,front+cut),(w,yy,rear-cut),
                         (w-cut,yy,rear),(-w+cut,yy,rear),(-w,yy,rear-cut),(-w,yy,front+cut)])
        self.rings('hull',hull)
        outline=[(-.61,-.90),(.61,-.90),(.87,-.55),(1.02,.05),(.94,.71),(.68,1.04),
                 (0,1.14),(-.68,1.04),(-.94,.71),(-1.02,.05),(-.87,-.55)]
        loops=[]
        for yy,scale in [(1.9,.89),(2.14,1.0),(2.63,.80)]:
            loops.append([(x*scale,yy,z*scale-.40) for x,z in outline])
        self.rings('turret',loops,bottom=False)
        # A faceted cast shield and the same short 75 mm silhouette in all three studies.
        self.rings('mantlet',[[(-.58,2.01,-1.25),(.58,2.01,-1.25),(.58,2.52,-1.25),(-.58,2.52,-1.25)],
                             [(-.48,2.07,-1.59),(.48,2.07,-1.59),(.48,2.46,-1.59),(-.48,2.46,-1.59)]])
        self.rod('barrel',(0,2.28,-1.56),(0,2.28,-1.91),.14,n=n,end_radius=.105)
        self.rod('barrel',(0,2.28,-1.9),(0,2.28,-3.10),.095,n=n,end_radius=.065,cap_a=False,cap_b=False)
        # Hollow bore: ring + inward wall, no black filled cap masquerading as a hole.
        vv=[(rr*math.cos(i*math.tau/n),2.28+rr*math.sin(i*math.tau/n),z)
            for rr,z in [(.065,-3.10),(.04,-3.10),(.04,-2.92)] for i in range(n)]
        ff=[(l*n+i,l*n+(i+1)%n,(l+1)*n+(i+1)%n,(l+1)*n+i) for l in range(2) for i in range(n)]
        self.add('barrel',vv,ff,['steel']*n+['recess']*n)
        for side in [-1,1]:
            self.track(side,[5,8,12][level])
            for c in [-1.40,0,1.40]:
                for dz in [-.35,.35]: self.wheel(side,c+dz,.33,n,hub=level>0)
                self.box('suspension',(side*1.32,.87,c),(.21,.27,.28),'dark_paint')
            for z in [-2.52,2.52]: self.wheel(side,z,.435,n,hub=level>0,y=.54)
            self.box('hull',(side*1.26,1.18,.04),(.54,.045,5.30),'paint')
        self.rod('turret',(.4,2.62,.03),(.4,2.79,.03),.28,n=n)
        # Priority-ordered details; low study spends faces on silhouette before accessories.
        for side in [-1,1]:
            self.optional('driver hatch '+str(side),lambda side=side:self.box('hull',(side*.49,1.89,-1.13),(.42,.055,.44),'light_paint'))
        self.optional('loader hatch',lambda:self.rod('turret',(-.42,2.63,-.12),(-.42,2.675,-.12),.23,n=8))
        for side in [-1,1]:
            self.optional('headlight '+str(side),lambda side=side:self.rod('hull',(side*.84,1.70,-1.92),(side*.84,1.70,-2.01),.085,'steel',n=6))
        if level==0:
            for side in [-1,1]:
                for c in [-1.4,0,1.4]:
                    for dz in [-.35,.35]:
                        self.optional('low-budget flat wheel hub',lambda side=side,c=c,dz=dz:self.add('wheels',
                            [(side*1.463,.45+.10*math.sin(i*math.tau/8),c+dz+.10*math.cos(i*math.tau/8)) for i in range(8)],
                            [tuple(range(8))],'dark_paint'))
        if level>0:
            for side in [-1,1]:
                for c in [-1.40,0,1.40]:
                    self.optional('VVSS return roller',lambda side=side,c=c:self.wheel(side,c+.16,.11,6,y=1.0))
                    self.optional('VVSS paired arms',lambda side=side,c=c:[self.rod('suspension',(side*1.48,.89,c),(side*1.48,.45,c+dz),.055,'dark_paint',n=6) for dz in [-.35,.35]])
            self.optional('deck grille base',lambda:self.box('hull',(0,1.879,1.84),(1.36,.025,1.45),'recess'))
            for i in range(7):
                self.optional('deck grille rib',lambda i=i:self.box('hull',(0,1.901,1.2+i*.2),(1.30,.026,.085),'paint'))
            self.optional('AA machine gun',lambda:[self.box('turret',(.39,2.96,.13),(.12,.15,.37),'dark_paint'),
                self.rod('turret',(.39,3.0,-.03),(.39,3.0,-.66),.024,'steel',n=6),
                self.rod('turret',(.39,2.79,.15),(.39,2.99,.15),.035,'steel',n=6)])
            self.optional('rear canvas roll',lambda:self.rod('hull',(-.70,2.04,2.35),(.70,2.04,2.35),.16,'canvas',n=8))
            self.optional('deck shovel',lambda:[self.rod('hull',(-.81,1.98,.99),(-.81,1.98,2.26),.026,'canvas',n=6),self.box('hull',(-.81,1.97,2.33),(.18,.035,.23),'steel')])
            self.optional('antenna',lambda:self.rod('turret',(-.65,2.54,.42),(-.65,3.43,.42),.012,'steel',n=4,end_radius=.004))
        if level==2:
            self.optional('raised track ribs',lambda:self.track_links(52))
            for side in [-1,1]:
                for z in [-2.57,2.66]:
                    self.optional('tow loop',lambda side=side,z=z:self.rod('hull',(side*.74,.80,z),(side*.74,.80,z+.12),.07,'steel',n=8))
                self.optional('side stowage',lambda side=side:self.box('hull',(side*1.08,1.47,1.77),(.13,.42,.62),'canvas'))
                self.optional('headlamp guard',lambda side=side:[self.rod('hull',(side*.84+dx,1.6,-1.97),(side*.84+dx,1.83,-1.97),.014,'steel',n=4) for dx in [-.12,.12]])
        self.features.insert(0,'M4 silhouette / hollow barrel / paired road wheels / cast turret / fenders')


def create_objects(model):
    mats={}
    for key,hex_code in PALETTE.items():
        m=bpy.data.materials.new(key); m.diffuse_color=(*srgb(hex_code),1); m.use_nodes=True
        bsdf=m.node_tree.nodes['Principled BSDF']; bsdf.inputs['Base Color'].default_value=m.diffuse_color
        bsdf.inputs['Roughness'].default_value=.82; bsdf.inputs['Metallic'].default_value=.25 if key in ('steel','track') else 0
        mats[key]=m
    keys=list(mats); objects=[]
    for part,(vertices,polygons,colors) in model.groups.items():
        mesh=bpy.data.meshes.new(part); mesh.from_pydata([coord(p) for p in vertices],[],polygons); mesh.update()
        obj=bpy.data.objects.new(part,mesh); bpy.context.collection.objects.link(obj)
        for m in mats.values(): mesh.materials.append(m)
        for face,color in zip(mesh.polygons,colors): face.material_index=keys.index(color)
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        # Recalculate actual outward normals and triangulate the exported mesh itself.
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        tri=obj.modifiers.new('Actual exported triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
        obj.select_set(False); objects.append(obj)
    return objects


def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def studio():
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=40
    scene.cycles.use_denoising=True
    if scene.world is None: scene.world=bpy.data.worlds.new('Studio World')
    scene.world.color=(.35,.35,.35)
    scene.world.use_nodes=True; scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.34,.35,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    scene.view_settings.view_transform='AgX'
    scene.render.resolution_x=1600; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012)); floor=bpy.context.object; floor.name='STUDIO_FLOOR_EXCLUDED'
    mat=bpy.data.materials.new('studio warm gray'); mat.diffuse_color=(.48,.48,.45,1); mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.48,.48,.45,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.92; floor.data.materials.append(mat)
    for name,power,size,location in [('key',1500,7,(-5,2,9)),('fill',1000,6,(6,1,5)),('rim',1500,5,(0,-7,7))]:
        light=bpy.data.lights.new(name,'AREA'); light.energy=power; light.shape='DISK'; light.size=size
        obj=bpy.data.objects.new(name,light); bpy.context.collection.objects.link(obj); obj.location=location; aim(obj,(0,0,1.2))
    camera=bpy.data.cameras.new('comparison_camera'); obj=bpy.data.objects.new('comparison_camera',camera); bpy.context.collection.objects.link(obj)
    obj.location=(8,10,6.0); aim(obj,(0,0,1.25)); camera.type='ORTHO'; camera.ortho_scale=9.5; scene.camera=obj
    return obj


def run():
    reports=[]
    budgets=[1000,2500,5000]
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if args: budgets=[int(x) for x in args]
    for budget in budgets:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        model=Model(budget); model.build()
        print('BUDGET_RAW',budget,model.triangles,flush=True)
        objects=create_objects(model)
        count=sum(len(o.data.polygons) for o in objects)
        if count>budget*1.10: raise RuntimeError(f'{budget}: model exceeds budget: {count}')
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT/f'm4_study_{budget}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
        camera=studio(); scene=bpy.context.scene
        scene['study_only']=True; scene['actual_tank_triangles']=count; scene['target_triangles']=budget
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'm4_study_{budget}.blend'))
        for view,location,target,scale in [('hero',(8,10,6.0),(0,0,1.25),9.5),('side',(11,0,3.0),(0,0,1.4),8.1)]:
            camera.location=location; aim(camera,target); camera.data.ortho_scale=scale
            scene.render.filepath=str(OUT/f'm4_{budget}_{view}.png'); bpy.ops.render.render(write_still=True)
        reports.append({'target_triangles':budget,'actual_triangles':count,'parts':{o.name:len(o.data.polygons) for o in objects},
                        'features':model.features,'materials':len(PALETTE),'gameplay_replacement':False,
                        'source':'Original procedural model; user-supplied concept sheets guide art style only'})
        print('MODEL_STUDY_PASS',budget,count,flush=True)
    (OUT/'BUDGET_REPORT.json').write_text(json.dumps(reports,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')


if __name__=='__main__': run()
