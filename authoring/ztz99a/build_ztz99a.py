"""Reference-led ZTZ-99A authoring and genuine Cycles high-to-low baking.
Run with Blender --background --python-exit-code 1 --python this_file -- [high|lod N|all].
Coordinates: meters, Blender +Y forward / +Z up, glTF -Z forward / +Y up.
"""
import bpy, bmesh, math, json, sys, hashlib, time
from pathlib import Path
from mathutils import Vector, Euler
from collections import defaultdict

ROOT = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
ASSET = ROOT.parent.parent / 'assets' / 'vehicles' / 'ztz99a'
for p in (ASSET / 'textures', ROOT / 'renders'):
    p.mkdir(parents=True, exist_ok=True)
MATS = {}
GROUPS = defaultdict(list)
HIGH = True
LEVEL = 4000
PI = math.pi

def log(s): print('ZTZ99A | ' + s, flush=True)

def select(obs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs: o.hide_set(False); o.select_set(True)
    if obs: bpy.context.view_layer.objects.active = obs[0]

def material(name, color, rough=.7, metal=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    b=m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value=(*color,1)
    b.inputs['Roughness'].default_value=rough
    b.inputs['Metallic'].default_value=metal
    m.diffuse_color=(*color,1)
    m['roughness_value']=rough; m['metallic_value']=metal
    MATS[name]=m
    return m

def materials():
    MATS.clear()
    paint=material('paint',(.24,.26,.13),.76,.08)
    n=paint.node_tree.nodes; l=paint.node_tree.links; bs=n.get('Principled BSDF')
    pos=n.new('ShaderNodeNewGeometry')
    mul=n.new('ShaderNodeVectorMath'); mul.operation='SCALE'; mul.inputs[3].default_value=9
    floor=n.new('ShaderNodeVectorMath'); floor.operation='FLOOR'
    div=n.new('ShaderNodeVectorMath'); div.operation='SCALE'; div.inputs[3].default_value=1/9
    noise=n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=2.2; noise.inputs['Detail'].default_value=1.3
    ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation='CONSTANT'
    colors=[(.29,(.028,.040,.021,1)),(.43,(.075,.105,.040,1)),(.54,(.185,.172,.074,1)),(.65,(.27,.238,.115,1))]
    for e in list(ramp.color_ramp.elements)[1:]: ramp.color_ramp.elements.remove(e)
    ramp.color_ramp.elements[0].position=colors[0][0]; ramp.color_ramp.elements[0].color=colors[0][1]
    for p,c in colors[1:]: ramp.color_ramp.elements.new(p).color=c
    l.new(pos.outputs['Position'],mul.inputs[0]);l.new(mul.outputs[0],floor.inputs[0]);l.new(floor.outputs[0],div.inputs[0]);l.new(div.outputs[0],noise.inputs['Vector']);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],bs.inputs['Base Color'])
    # Fixed wear microdetail extracted from the user's atlas (not an invented normal bake).
    wear=n.new('ShaderNodeTexImage');wear.image=bpy.data.images.load(str(ROOT/'reference/paint_wear.png'));wear.image.colorspace_settings.name='Non-Color';wear.image.pack();wear.projection='BOX';wear.projection_blend=.18
    l.new(pos.outputs['Position'],wear.inputs['Vector'])
    factor=n.new('ShaderNodeMath');factor.operation='MULTIPLY_ADD';factor.inputs[1].default_value=.85;factor.inputs[2].default_value=.47;l.new(wear.outputs['Color'],factor.inputs[0])
    weather=n.new('ShaderNodeMixRGB');weather.blend_type='MULTIPLY';weather.inputs[0].default_value=1;l.new(ramp.outputs[0],weather.inputs[1]);l.new(factor.outputs[0],weather.inputs[2])
    edge=n.new('ShaderNodeMapRange');edge.inputs['From Min'].default_value=.515;edge.inputs['From Max'].default_value=.56;edge.inputs['To Min'].default_value=0;edge.inputs['To Max'].default_value=.30;l.new(pos.outputs['Pointiness'],edge.inputs[0])
    chipped=n.new('ShaderNodeMixRGB');chipped.inputs[2].default_value=(.24,.225,.16,1);l.new(edge.outputs[0],chipped.inputs[0]);l.new(weather.outputs[0],chipped.inputs[1]);l.new(chipped.outputs[0],bs.inputs['Base Color'])
    rough=n.new('ShaderNodeMapRange');rough.inputs['From Min'].default_value=0;rough.inputs['From Max'].default_value=1;rough.inputs['To Min'].default_value=.57;rough.inputs['To Max'].default_value=.87;l.new(wear.outputs['Color'],rough.inputs[0]);l.new(rough.outputs[0],bs.inputs['Roughness'])
    texnoise=n.new('ShaderNodeTexNoise');texnoise.inputs['Scale'].default_value=105;texnoise.inputs['Detail'].default_value=2
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.002
    l.new(pos.outputs['Position'],texnoise.inputs['Vector']);l.new(texnoise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],bs.inputs['Normal'])
    for name,col,r,met in [('rubber',(.028,.034,.025),.91,0),('steel',(.12,.125,.10),.52,.7),('dark',(.018,.025,.021),.8,.05),('rim',(.23,.25,.13),.63,.25),('glass',(.018,.045,.052),.18,.25),('red',(.45,.025,.012),.4,.05),('yellow',(.85,.48,.025),.65,0),('white',(.8,.81,.71),.8,0),('canvas',(.115,.125,.078),.9,0)]: material(name,col,r,met)
    atlas=material('reference_atlas',(.3,.3,.2),.8,.06)
    img=bpy.data.images.load(str(ROOT/'reference/source_atlas.png'));img.pack()
    t=atlas.node_tree.nodes.new('ShaderNodeTexImage');t.image=img
    atlas.node_tree.links.new(t.outputs['Color'],atlas.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def uv_auto(o, tile=None, axes=None, bounds=None):
    mesh=o.data
    uv=mesh.uv_layers.new(name='SourceUV')
    coords=[o.matrix_world @ v.co for v in mesh.vertices]
    for face in mesh.polygons:
        a=axes
        if a is None:
            dominant=max(range(3),key=lambda i:abs(face.normal[i]))
            a=((1,2),(0,2),(0,1))[dominant]
        aa,bb=a
        vals=bounds or (min(v[aa] for v in coords),max(v[aa] for v in coords),min(v[bb] for v in coords),max(v[bb] for v in coords))
        for li in face.loop_indices:
            co=coords[mesh.loops[li].vertex_index]
            u=(co[aa]-vals[0])/max(.00001,vals[1]-vals[0]);v=(co[bb]-vals[2])/max(.00001,vals[3]-vals[2])
            if tile:
                x0,y0,x1,y1=tile;u=(x0+u*(x1-x0))/1254;v=1-(y1-v*(y1-y0))/1254
            uv.data[li].uv=(u,v)

def finish(o,name,group,mat='paint',bevel=0,tile=None,axes=None,bounds=None):
    o.name=name;o.data.materials.append(MATS['reference_atlas' if tile else mat])
    uv_auto(o,tile,axes,bounds)
    o['bake_group']=group;o['motion']='turret' if group=='turret' else 'gun_recoil' if group=='gun' else 'barrel' if group=='mantlet' else 'hull'
    GROUPS[group].append(o)
    if HIGH and bevel:
        mod=o.modifiers.new('Manufactured edge radii','BEVEL');mod.width=bevel;mod.segments=3
    return o

def box(name,loc,size,group,mat='paint',bevel=.012,tile=None,axes=None,bounds=None,rot=None):
    rotation=Euler(rot or (0,0,0)).to_matrix()
    v=[tuple(Vector(loc)+rotation@Vector((x*size[0]/2,y*size[1]/2,z*size[2]/2))) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh_obj(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],group,mat,bevel,tile,axes,bounds)

def mesh_obj(name,verts,faces,group,mat='paint',bevel=0,tile=None,axes=None,bounds=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    return finish(o,name,group,mat,bevel,tile,axes,bounds)

def rings(name,levels,group,mat='paint',bevel=0):
    # equal-length XY outline rings at each level
    vs=[(x,y,z) for z,pts in levels for x,y in pts];k=len(levels[0][1]);fs=[]
    fs.append(tuple(reversed(range(k))))
    for r in range(len(levels)-1):
        for j in range(k):fs.append((r*k+j,r*k+(j+1)%k,(r+1)*k+(j+1)%k,(r+1)*k+j))
    fs.append(tuple(range((len(levels)-1)*k,len(vs))))
    return mesh_obj(name,vs,fs,group,mat,bevel)

def cyl(name,a,b,r,group,mat='paint',n=None,r2=None,bevel=.004):
    if n is None:n=48 if HIGH else 8 if LEVEL>=2000 else 6
    a,b=Vector(a),Vector(b);d=(b-a).normalized();basis=d.to_track_quat('Z','Y').to_matrix()
    vs=[tuple(c+basis@Vector((rr*math.cos(i*2*PI/n),rr*math.sin(i*2*PI/n),0))) for c,rr in [(a,r),(b,r if r2 is None else r2)] for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    o=mesh_obj(name,vs,faces,group,mat,bevel)
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o

def tube(name,profile,group,mat='paint',n=None):
    # closed revolved profile of (Y,radius), centered at X=0 Z=2.06; includes real bore
    n=n or (64 if HIGH else 12 if LEVEL==4000 else 8 if LEVEL==2000 else 6)
    vs=[(r*math.cos(2*PI*i/n),y,2.06+r*math.sin(2*PI*i/n)) for y,r in profile for i in range(n)]
    fs=[]
    for j in range(len(profile)-1):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    o=mesh_obj(name,vs,fs,group,mat,.002 if HIGH else 0)
    for p in o.data.polygons:p.use_smooth=True
    return o

def plate(name,corners,thickness,group,mat='paint',tile=None,axes=None,bounds=None):
    cs=[Vector(v) for v in corners];normal=(cs[1]-cs[0]).cross(cs[2]-cs[0]).normalized()
    center=sum(cs,Vector())/len(cs)
    if abs(normal.x)>.65 and normal.x*center.x<0:normal=-normal
    elif abs(normal.z)>.65 and center.z>1.2 and normal.z<0:normal=-normal
    elif abs(normal.y)>.65 and normal.y*center.y<0:normal=-normal
    vs=[tuple(c) for c in cs]+[tuple(c-normal*thickness) for c in cs];n=len(cs)
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh_obj(name,vs,fs,group,mat,.006 if HIGH else 0,tile,axes,bounds)

def bolt(name,at,axis,group,r=.015):
    if HIGH:cyl(name,at,Vector(at)+Vector(axis)*.012,r,group,'steel',6,bevel=.0015)

def track_path():
    # clockwise in YZ, chamfered nose/tail. Six road wheels fit between the elevated ends.
    return [(-2.80,.105),(2.80,.105),(3.36,.48),(3.63,.90),(3.52,1.26),(3.12,1.47),(-3.10,1.47),(-3.54,1.23),(-3.65,.91),(-3.38,.46)]

def track(side):
    s=side;x=s*1.445;g='track_L' if s<0 else 'track_R';path=track_path();k=len(path)
    center=Vector((0,.79));inner=[]
    for yz in path:
        v=Vector(yz);inner.append(tuple(v+(center-v).normalized()*.105))
    vs=[]
    for xx,loop in [(x-.29,path),(x+.29,path),(x-.29,inner),(x+.29,inner)]:vs.extend((xx,y,z) for y,z in loop)
    fs=[]
    for i in range(k):
        j=(i+1)%k;fs.extend([(i,j,k+j,k+i),(2*k+i,3*k+i,3*k+j,2*k+j),(i,2*k+i,2*k+j,j),(k+i,k+j,3*k+j,3*k+i)])
    o=mesh_obj(g+'_continuous_band',vs,fs,g,'steel')
    # wrap repeating atlas chain detail around the whole loop
    o.data.materials.clear();o.data.materials.append(MATS['reference_atlas'])
    uv=o.data.uv_layers.active
    for p in o.data.polygons:
        tile=(20,879,585,939) if p.index%4==0 else (18,965,587,1010)
        for li,co in zip(p.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=((tile[0]+co[0]*(tile[2]-tile[0]))/1254,1-(tile[3]-co[1]*(tile[3]-tile[1]))/1254)
    if HIGH:
        for a,b in zip(path,path[1:]+path[:1]):
            d=Vector(b)-Vector(a);length=d.length;n=max(1,round(length/.155))
            for i in range(n):
                yz=Vector(a)+d*(i+.5)/n;theta=math.atan2(d.y,d.x)
                loc=(x,yz.x,yz.y)
                box('Track_link_shoe',loc,(.60,length/n*.88,.068),g,'steel',.009,rot=(theta,0,0))
                for off in (-.20,.20):
                    yy=yz.x+math.sin(theta)*.055;zz=yz.y-math.cos(theta)*.055
                    box('Track_grouser',(x+off,yy,zz),(.16,length/n*.79,.028),g,'steel',.004,rot=(theta,0,0))
                yy=yz.x+math.sin(theta)*.073;zz=yz.y-math.cos(theta)*.073
                box('Track_cross_cleat',(x,yy,zz),(.57,.027,.024),g,'steel',.004,rot=(theta,0,0))
                cyl('Track_pin',(x-.32,yz.x,yz.y),(x+.32,yz.x,yz.y),.023,g,'steel',8,bevel=0)

def wheels(side):
    s=side;g='wheels_L' if s<0 else 'wheels_R';x=s*1.445
    n=64 if HIGH else 16 if LEVEL==4000 else 10 if LEVEL==2000 else 6
    positions=[-2.48,-1.49,-.50,.49,1.48,2.47]
    for i,y in enumerate(positions):
        a=(x-.225,y,.61);b=(x+.225,y,.61)
        cyl(f'RoadWheel_{i+1:02d}_rubber',a,b,.477,g,'rubber',n,bevel=.01)
        outward=x+s*.231
        if HIGH or LEVEL>=2000:
            cyl(f'RoadWheel_{i+1:02d}_rim',(outward-s*.02,y,.61),(outward+s*.013,y,.61),.389,g,'rim',n,bevel=.007)
        if HIGH:
            cyl('Wheel_bowl',(outward+s*.013,y,.61),(outward+s*.027,y,.61),.301,g,'dark',48)
            cyl('Wheel_inner_dish',(outward+s*.028,y,.61),(outward+s*.039,y,.61),.263,g,'rim',48)
            cyl('Wheel_hub',(outward+s*.04,y,.61),(outward+s*.084,y,.61),.125,g,'rim',32)
            for t in range(8):
                angle=2*PI*t/8
                yy=y+math.sin(angle)*.214;zz=.61+math.cos(angle)*.214
                cyl('Wheel_recess',(outward+s*.039,yy,zz),(outward+s*.041,yy,zz),.048,g,'dark',16,bevel=.001)
                bolt('Hub_bolt',(outward+s*.086,y+math.sin(angle)*.087,.61+math.cos(angle)*.087),(s,0,0),g,.014)
            cyl('Suspension_swingarm',(s*1.13,y-.17,.93),(s*1.25,y,.61),.062,g,'steel',12)
    for name,y,r in [('Drive_sprocket',-3.18,.34),('Front_idler',3.20,.335)]:
        cyl(name,(x-.22,y,.95),(x+.22,y,.95),r,g,'steel',48 if HIGH else max(n,8),bevel=.007)
        if HIGH:
            xx=x+s*.226
            cyl(name+'_dish',(xx,y,.95),(xx+s*.025,y,.95),r*.78,g,'rim',48)
            cyl(name+'_hub',(xx,y,.95),(xx+s*.082,y,.95),.105,g,'steel',24)
            for i in range(12):
                a=i*2*PI/12
                if y<0:box('Sprocket_tooth',(x,y+math.sin(a)*r,.95+math.cos(a)*r),(.46,.075,.055),g,'steel',.004,rot=(-a,0,0))
                cyl('Idler_recess',(xx+s*.027,y+math.sin(a)*r*.56,.95+math.cos(a)*r*.56),(xx+s*.030,y+math.sin(a)*r*.56,.95+math.cos(a)*r*.56),.042,g,'dark',12)

def hull():
    bottom=[(-1.18,-3.38),(1.18,-3.38),(1.18,2.85),(.98,3.27),(-.98,3.27),(-1.18,2.85)]
    middle=[(-1.34,-3.62),(1.34,-3.62),(1.36,3.30),(1.1,3.76),(-1.1,3.76),(-1.36,3.30)]
    top=[(-1.39,-3.65),(1.39,-3.65),(1.36,2.17),(1.1,2.62),(-1.1,2.62),(-1.36,2.17)]
    rings('Hull_welded_armor',[(.46,bottom),(1.02,middle),(1.52,top)],'hull',bevel=.015)
    # upper glacis ERA courses with physically stepped edges
    if HIGH or LEVEL>=2000:
        cols=8 if HIGH else 4
        rows=3 if HIGH else 1
        for i in range(cols):
            for j in range(rows):
                xa=-1.08+i*2.16/cols+.007;xb=-1.08+(i+1)*2.16/cols-.007
                ya=2.32+j*1.22/rows+.006;yb=2.32+(j+1)*1.22/rows-.006
                z=lambda y:1.55-(y-2.32)*.425
                plate('Glacis_ERA',[(xa,ya,z(ya)),(xb,ya,z(ya)),(xb,yb,z(yb)),(xa,yb,z(yb))],.055,'hull')
                if HIGH:
                    for xx in (xa+.04,xb-.04):bolt('ERA_fastener',(xx,ya+.04,z(ya)+.014),(0,.38,.92),'hull')
    for s in (-1,1):
        # skirt hull is continuous in lower LOD, high model has eight separated plates.
        g='skirt_L' if s<0 else 'skirt_R';x=s*1.748
        count=8 if HIGH or LEVEL==4000 else 3 if LEVEL==2000 else 1
        for i in range(count):
            ya=-3.47+i*6.74/count;yb=-3.47+(i+1)*6.74/count-.012
            za=.79 if i<count-1 else 1.02
            plate('Side_skirt_panel',[(x,ya,za),(x,yb,.84 if i>0 else .96),(x,yb,1.52),(x,ya,1.52)],.065,g,tile=(18,594,747,655),axes=(1,2),bounds=(-3.48,3.28,.77,1.52))
            if HIGH:
                for y in (ya+.075,yb-.075):bolt('Skirt_upper_bolt',(x+s*.016,y,1.47),(s,0,0),g)
                box('Skirt_access_slot',(x+s*.007,(ya+yb)/2,.98),(.014,.095,.052),g,'dark',.002)
                box('Skirt_hinge',(x-s*.015,(ya+yb)/2,1.54),(.095,.16,.06),g,'steel',.006)
        box('Fender_upper_armor',(s*1.51,-.06,1.56),(.53,6.85,.19),'hull',bevel=.028)
        # rounded front fenders preserve the track nose silhouette
        seg=10 if HIGH else 3 if LEVEL>=2000 else 2
        v=[]
        for xx in (s*1.14,s*1.77):
            for i in range(seg+1):
                a=i/seg*PI*.46;v.append((xx,3.12+math.sin(a)*.69,1.28+math.cos(a)*.37))
        mesh_obj('Front_mudguard',v,[(i,i+1,seg+2+i,seg+1+i) for i in range(seg)],'hull',bevel=.005)
        if HIGH:
            for xx in (s*1.2,s*1.49,s*1.70):
                for i in range(10):
                    a=i/10*PI*.46;b=(i+1)/10*PI*.46
                    cyl('Fender_stamped_rib',(xx,3.12+math.sin(a)*.694,1.285+math.cos(a)*.375),(xx,3.12+math.sin(b)*.694,1.285+math.cos(b)*.375),.009,'hull','rim',8,bevel=0)
        box('Headlamp_housing',(s*.95,2.67,1.49),(.23,.18,.19),'hull','paint',.025)
        if HIGH or LEVEL==4000:cyl('Headlamp_lens',(s*.95,2.757,1.49),(s*.95,2.777,1.49),.074,'hull','glass',32 if HIGH else 8)
    # Rear deck and actual engine louvers
    for x in (-.61,.61):
        box('Engine_grille_recess',(x,-2.87,1.545),(1.09,1.05,.025),'hull','dark',.006,tile=(496,417,589,550),axes=(0,1))
        if HIGH:
            for j in range(26):box('Engine_grille_louver',(x,-3.36+j*.039,1.571),(1.035,.015,.027),'hull','steel',.002)
            for xx in (x-.545,x+.545):box('Grille_frame',(xx,-2.87,1.575),(.033,1.08,.04),'hull','rim',.004)
    box('Rear_engine_plate',(0,-3.64,1.115),(2.62,.10,.65),'hull',tile=(960,351,1230,478),axes=(0,2))
    for s in (-1,1):
        if HIGH:
            for j in range(15):box('Rear_exhaust_louver',(s*.63,-3.705,.99+j*.026),(1.05,.028,.012),'hull','steel',.002)
        if HIGH or LEVEL>=2000:
            box('Tail_light_case',(s*1.51,-3.5,1.25),(.24,.11,.15),'hull','dark',.012)
            box('Tail_light_red',(s*1.51,-3.562,1.25),(.15,.025,.075),'hull','red',.008)
    cyl('Driver_hatch',(0,1.85,1.52),(0,1.85,1.58),.31,'hull',n=48 if HIGH else 8)
    if HIGH:
        box('Driver_periscope',(0,1.61,1.62),(.29,.13,.09),'hull','paint')
        box('Driver_periscope_glass',(0,1.681,1.62),(.21,.012,.043),'hull','glass',.003)
        for s in (-1,1):
            # Tow cable follows the front lower hull; shackles have an open interior.
            for y,z in [(3.32,.77),(-3.73,.65)]:
                cyl('Tow_lug',(s*.83,y-.05,z+.04),(s*.83,y+.07,z+.04),.055,'hull','steel',16)
                for j in range(12):
                    a=j/12*PI*1.6-.3;b=(j+1)/12*PI*1.6-.3
                    cyl('Tow_shackle',(s*.83+.085*math.cos(a),y+.09,z+.09*math.sin(a)),(s*.83+.085*math.cos(b),y+.09,z+.09*math.sin(b)),.018,'hull','steel',8,bevel=0)
            for j in range(18):
                ya=-3.14+j*.27;yb=ya+.27
                cyl('Side_tow_cable',(s*1.69,ya,1.695),(s*1.69,yb,1.695),.018,'hull','steel',8,bevel=0)
    for s in (-1,1):track(s);wheels(s)

def star(s,x,y,z,r,group):
    # Real geometry decals on high model, transferred onto low shell by Cycles.
    for scale,mat,offset in [(1,'yellow',0),(.83,'red',.0008)]:
        vs=[(x+s*offset,y,z)]+[(x+s*offset,y+math.sin(i*PI/5)*(r if i%2==0 else r*.41)*scale,z+math.cos(i*PI/5)*(r if i%2==0 else r*.41)*scale) for i in range(10)]
        mesh_obj('PLA_star_decal',vs,[(0,i+1,(i+1)%10+1) for i in range(10)],group,mat)
    for a,b in [((-.025,.058),(-.058,-.026)),((.007,.058),(.056,-.026)),((-.057,-.057),(.057,-.057))]:
        aa=Vector(a);bb=Vector(b);d=(bb-aa).normalized();perp=Vector((-d.y,d.x))*.006
        pts=[aa+perp,bb+perp,bb-perp,aa-perp]
        mesh_obj('PLA_Bayi_gold_strokes',[(x+s*.0017,y+p.x,z+p.y) for p in pts],[(0,1,2,3)],group,'yellow')


def gun():
    box('Gun_mantlet', (0,1.365,2.06),(.59,.40,.46),'mantlet','canvas',.07)
    cyl('Gun_trunnion',(-.32,1.22,2.06),(.32,1.22,2.06),.19,'mantlet','steel',48 if HIGH else 8)
    if HIGH:
        for y in (1.45,1.49,1.53,1.57):tube('Mantlet_seal',[(y,.213),(y+.019,.213),(y+.019,.19),(y,.19)],'mantlet','canvas',48)
    if HIGH:
        profile=[(1.53,.153),(1.79,.153),(1.83,.134),(2.50,.134),(2.53,.16),(3.08,.16),(3.12,.134),(4.38,.134),(4.43,.168),(4.88,.168),(4.92,.119),(6.89,.107),(6.91,.132),(7.14,.132),(7.20,.117),(7.20,.064),(6.81,.064)]
    else:
        profile=[(1.53,.153),(2.50,.135),(2.54,.16),(3.10,.16),(3.14,.13),(4.42,.125),(4.46,.165),(4.87,.165),(4.91,.115),(7.12,.108),(7.20,.12),(7.20,.064),(6.87,.064)] if LEVEL>=2000 else [(1.53,.145),(4.41,.13),(4.44,.17),(4.9,.17),(4.93,.114),(7.2,.112),(7.2,.064),(6.85,.064)]
    tube('125mm_ZPT98_barrel_with_open_bore',profile,'gun')
    # Actual closed dark bore end, well behind the visible muzzle lip.
    cyl('Bore_shadow',(0,6.805,2.06),(0,6.810,2.06),.063,'gun','dark',32 if HIGH else 6,bevel=0)
    if HIGH:
        for y in (1.86,2.49,3.13,3.85,4.38,4.9,5.7,6.49,6.93):
            rr=.14 if y<4.39 else .126 if y<6.9 else .139
            tube('Thermal_sleeve_clamp',[(y,rr),(y+.027,rr),(y+.027,rr-.012),(y,rr-.012)],'gun','steel',64)
            bolt('Sleeve_clamp_bolt',(rr, y+.012,2.06),(1,0,0),'gun',.009)
        for i in range(8):
            a=i*PI/4;box('Muzzle_collar_slot',(.134*math.cos(a),7.035,2.06+.134*math.sin(a)),(.012,.061,.019),'gun','dark',.001,rot=(0,-a,0))

def build_geometry(high=True,level=4000):
    global HIGH,LEVEL,GROUPS
    HIGH=high;LEVEL=level;GROUPS=defaultdict(list)
    hull()
    import turret_multiview
    turret_multiview.build(sys.modules[__name__])
    gun()
    return dict(GROUPS)

def apply_all(o):
    select([o])
    for m in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=m.name)

def join_group(obs,name):
    select(obs)
    bpy.ops.object.convert(target='MESH')
    if len(obs)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o


def triangles(o):o.data.calc_loop_triangles();return len(o.data.loop_triangles)

def triangulate(o):
    select([o]);m=o.modifiers.new('Export triangulation','TRIANGULATE');m.quad_method='FIXED';bpy.ops.object.modifier_apply(modifier=m.name)

def rig(obs,prefix=''):
    empties={}
    for name,loc,parent in [('hull',(0,0,0),None),('turret',(0,-.25,1.64),'hull'),('barrel',(0,1.22,2.06),'turret'),('gun_recoil',(0,1.22,2.06),'barrel'),('muzzle',(0,7.20,2.06),'gun_recoil')]:
        o=bpy.data.objects.new(prefix+name,None);bpy.context.collection.objects.link(o);o.location=loc;o.empty_display_size=.25
        bpy.context.view_layer.update()
        if parent:
            world=o.matrix_world.copy();o.parent=empties[parent];o.matrix_world=world
        empties[name]=o
    for group,olist in obs.items():
        for o in olist if isinstance(olist,list) else [olist]:
            motion='turret' if group=='turret' else 'gun_recoil' if group=='gun' else 'barrel' if group=='mantlet' else 'hull'
            world=o.matrix_world.copy();o.parent=empties[motion];o.matrix_world=world
    return empties

def look_at(o,at):o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()

def studio():
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True
    world=bpy.data.worlds.new('Studio_world');world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.22,.255,.28,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.45;sc.world=world
    for name,loc,power,size in [('Key',(-4,5,10),2100,7),('Fill',(6,1,7),1700,6),('Rim',(0,-7,8),2500,5)]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name='Studio_'+name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;look_at(o,(0,0,1))
    bpy.ops.object.camera_add(location=(10,13,8));o=bpy.context.object;o.name='Studio_camera';look_at(o,(0,1.1,1.6));o.data.type='ORTHO';o.data.ortho_scale=13.7;sc.camera=o
    floor=material('studio_floor',(.11,.135,.15),.85)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,.018));bpy.context.object.name='Studio_ground';bpy.context.object.data.materials.append(floor)
    sc.render.resolution_x=1600;sc.render.resolution_y=1100;sc.render.resolution_percentage=100
    sc.view_settings.view_transform='AgX';sc.render.image_settings.file_format='PNG'
    sc.render.threads_mode='FIXED';sc.render.threads=8

def render(path,view='hero',clay=False):
    sc=bpy.context.scene;cam=sc.camera
    params={'hero':((10,14,5.8),(0,1.1,1.7),13.7),'rear':((-10,-12,7),(0,-.1,1.55),11.5),'side':((14,1.5,2.0),(0,1.5,2.0),12.5),'front':((0,15,2.1),(0,0,2.1),8.6),'top':((0,1,17),(0,1,0),12.5),'turret_side':((-14,-.4,2.47),(0,-.4,2.47),5.6),'turret_front':((0,15,2.5),(0,0,2.5),5.8),'turret_hero':((-7,10,5.6),(0,-.35,2.17),6.5),'turret_top':((0,-.4,15),(0,-.4,0),5.9)}
    loc,at,scale=params[view];cam.location=loc;look_at(cam,at);cam.data.ortho_scale=scale
    sc.render.filepath=str(path)
    if clay:
        ma=bpy.data.materials.get('Clay_check') or material('Clay_check',(.35,.40,.42),.65)
        sc.view_layers[0].material_override=ma
    bpy.ops.render.render(write_still=True)
    sc.view_layers[0].material_override=None

def high_build():
    bpy.ops.wm.read_factory_settings(use_empty=True);materials()
    log('Building high-resolution source');groups=build_geometry(True)
    obs=[o for ls in groups.values() for o in ls]
    rig(groups)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'ztz99a_high_checkpoint.blend'))
    studio()
    dg=bpy.context.evaluated_depsgraph_get();count=0
    for o in obs:
        evaluated=o.evaluated_get(dg);me=evaluated.to_mesh();me.calc_loop_triangles();count+=len(me.loop_triangles);evaluated.to_mesh_clear()
    metadata={'vehicle':'ZTZ-99A reference interpretation','source':'user-provided multiview, concept and atlas','dimensions_m':{'hull_length':7.6,'width':3.55,'overall_gun_forward':10.95,'turret_roof_height':2.38},'road_wheels_per_side':6,'high_triangles_evaluated':count,'high_mesh_objects':len(obs),'blender':bpy.app.version_string,'evidence':'Reference artwork conflicts on wheel count. Six chosen for 99A; proportions and unseen details estimated, not surveyed engineering data.'}
    (ROOT/'source_manifest.json').write_text(json.dumps(metadata,indent=2),encoding='utf8')
    bpy.context.scene['asset_description']='99A high source; editable mechanical objects and bevel modifiers; six wheels/side; reference-based estimated reconstruction.'
    select([obs[0]])
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'ztz99a_high.blend'))
    log(f'High source saved: {count} evaluated triangles, {len(obs)} editable meshes')
    for v in ('turret_hero','turret_side','turret_front','turret_top','hero','rear','side','top'):render(ROOT/'renders'/f'high_{v}.png',v)
    render(ROOT/'renders/high_clay.png','hero',True)

def simplify(obs,budget):
    for o in obs.values():triangulate(o)
    raw=sum(triangles(o) for o in obs.values());log(f'LOD {budget} authored triangles {raw}')
    if raw>budget:
        # Preserve the gun silhouette and rectangular armor; allocate reduction to over-resolved round details.
        weights={'hull':1.0,'turret':1.0,'gun':1.35,'mantlet':1.25,'skirt_L':1.2,'skirt_R':1.2,'track_L':1.15,'track_R':1.15,'wheels_L':1,'wheels_R':1}
        if budget==1000:
            weights['wheels_L']=weights['wheels_R']=2.4
            weights['turret']=.78
        elif budget==2000:weights['wheels_L']=weights['wheels_R']=1.35
        original={g:triangles(o) for g,o in obs.items()}
        total=sum(original[g]*weights[g] for g in obs)
        targets={g:min(original[g],max(12,int(budget*original[g]*weights[g]/total))) for g in obs}
        spare=budget-sum(targets.values())
        while spare>0:
            g=max(obs,key=lambda g:original[g]-targets[g])
            if targets[g]>=original[g]:break
            targets[g]+=1;spare-=1
        for g,o in obs.items():
            target=targets[g]
            if target>=triangles(o):continue
            select([o]);mod=o.modifiers.new('Budget constrained collapse','DECIMATE');mod.ratio=target/triangles(o);mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
    total=sum(triangles(o) for o in obs.values())
    while total>budget:
        o=max(obs.values(),key=triangles);select([o]);mod=o.modifiers.new('Budget final reduction','DECIMATE');mod.ratio=(triangles(o)-(total-budget)-2)/triangles(o);mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
        total=sum(triangles(o) for o in obs.values())
    for o in obs.values():
        triangulate(o)
        o.data.validate(verbose=True,clean_customdata=False)
        o.data.update()
    return {g:triangles(o) for g,o in obs.items()}

def unwrap(obs):
    # Split the projection cage at hard shading edges. Averaging across box corners
    # otherwise sends rays through the opposite wall and bakes inverted normals.
    for o in obs.values():
        adjacency=defaultdict(list)
        for p in o.data.polygons:
            for key in p.edge_keys:adjacency[tuple(sorted(key))].append(p)
        for e in o.data.edges:
            faces=adjacency.get(tuple(sorted(e.vertices)),[])
            e.use_edge_sharp=len(faces)==2 and (not faces[0].use_smooth or not faces[1].use_smooth) and faces[0].normal.dot(faces[1].normal)<.999
        select([o]);mod=o.modifiers.new('Hard-edge projection splits','EDGE_SPLIT');mod.use_edge_angle=False;mod.use_edge_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    select(list(obs.values()))
    for o in obs.values():
        for uv in list(o.data.uv_layers):o.data.uv_layers.remove(uv)
        o.data.uv_layers.new(name='UV_Bake')
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003,area_weight=.25,correct_aspect=True,scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')

def bake_lod(budget):
    global MATS
    log(f'Loading high source for LOD {budget}')
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'ztz99a_high.blend'))
    MATS={m.name:m for m in bpy.data.materials}
    high_groups=defaultdict(list)
    source_empties=[]
    bpy.context.view_layer.update()
    saved_world={o:o.matrix_world.copy() for o in bpy.context.scene.objects if o.type=='MESH'}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH' and 'bake_group' in o:
            o.parent=None;o.matrix_world=saved_world[o];high_groups[o['bake_group']].append(o)
        elif o.type=='EMPTY':o.name='SOURCE_'+o.name;source_empties.append(o)
    bpy.context.view_layer.update()
    high={}
    for g,ls in high_groups.items():
        log('Joining high '+g)
        high[g]=join_group(ls,'HIGH_'+g)
    log('High projection groups joined')
    low_groups=build_geometry(False,budget)
    low={g:join_group(ls,'LOD'+str(budget)+'_'+g) for g,ls in low_groups.items()}
    counts=simplify(low,budget);log(f'LOD counts: {counts} total {sum(counts.values())}')
    unwrap(low)
    cages={}
    for group,lo in low.items():
        cage=bpy.data.objects.new('CAGE_'+group,lo.data.copy());bpy.context.collection.objects.link(cage)
        cage.matrix_world=lo.matrix_world.copy();cage.hide_render=True;cage.hide_set(True)
        cage.display_type='WIRE'
        for v,original in zip(cage.data.vertices,lo.data.vertices):
            co=original.co
            distance=.28 if group.startswith('wheels') else .12
            if group=='turret':
                distance=.065
                if abs(co.x)>1.30 and -.12<co.y<.60 and 1.75<co.z<2.46:distance=.24
            v.co=original.co+original.normal*distance
        cage.data.update();cages[group]=cage
    for o in high.values():o.hide_render=True;o.hide_set(True)
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.use_denoising=False
    sc.render.bake.use_selected_to_active=True;sc.render.bake.use_clear=False;sc.render.bake.margin=6
    sc.render.bake.normal_space='TANGENT';sc.render.bake.normal_r='POS_X';sc.render.bake.normal_g='POS_Y';sc.render.bake.normal_b='POS_Z'
    sc.render.bake.cage_extrusion=.26;sc.render.bake.max_ray_distance=.52
    size=2048 if budget==4000 else 1024
    images={}
    defaults={'BaseColor':(.18,.22,.12,1),'Normal':(.5,.5,1,1),'ORM':(1,.8,0,1)}
    for channel in defaults:
        img=bpy.data.images.new(f'99A_{budget}_{channel}',width=size,height=size,alpha=False,float_buffer=False)
        img.generated_color=defaults[channel];img.colorspace_settings.name='sRGB' if channel=='BaseColor' else 'Non-Color'
        images[channel]=img
    target=bpy.data.materials.new(f'99A_{budget}_BakedPBR');target.use_nodes=True
    nodes=target.node_tree.nodes;links=target.node_tree.links;bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    tex={}
    for channel,img in images.items():
        t=nodes.new('ShaderNodeTexImage');t.name=channel;t.image=img;tex[channel]=t
    for o in low.values():o.data.materials.clear();o.data.materials.append(target)
    # Store source material outputs before a temporary packed ORM emission bake.
    source_mats=set(m for o in high.values() for m in o.data.materials if m)
    for channel in ('BaseColor','Normal','ORM'):
        nodes.active=tex[channel]
        changed=[]
        if channel=='ORM':
            for m in source_mats:
                n=m.node_tree.nodes;l=m.node_tree.links;out=n.get('Material Output');old=list(out.inputs['Surface'].links)
                original=old[0].from_socket if old else None
                ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.16;ao.samples=16;ao.only_local=True
                combine=n.new('ShaderNodeCombineColor');combine.mode='RGB';combine.inputs[1].default_value=m.get('roughness_value',.8);combine.inputs[2].default_value=m.get('metallic_value',.05)
                source_bs=n.get('Principled BSDF')
                if source_bs:
                    for prop,index in [('Roughness',1),('Metallic',2)]:
                        if source_bs.inputs[prop].is_linked:l.new(source_bs.inputs[prop].links[0].from_socket,combine.inputs[index])
                em=n.new('ShaderNodeEmission');l.new(ao.outputs['AO'],combine.inputs[0]);l.new(combine.outputs[0],em.inputs[0]);l.new(em.outputs[0],out.inputs['Surface']);changed.append((m,original,[ao,combine,em]))
        for group,lo in low.items():
            hi=high[group];hi.hide_render=False;hi.hide_set(False)
            select([lo,hi]);bpy.context.view_layer.objects.active=lo
            sc.render.bake.cage_extrusion=.28 if group.startswith('wheels') else .40 if group=='turret' else .12
            sc.render.bake.max_ray_distance=sc.render.bake.cage_extrusion*2
            sc.render.bake.use_cage=True;sc.render.bake.cage_object=cages[group]
            sc.render.bake.max_ray_distance=.56
            log(f'Bake {budget} {channel} {group}')
            if channel=='BaseColor':bpy.ops.object.bake(type='DIFFUSE',pass_filter={'COLOR'})
            elif channel=='Normal':bpy.ops.object.bake(type='NORMAL')
            else:bpy.ops.object.bake(type='EMIT')
            hi.hide_render=True;hi.hide_set(True)
        for m,original,created in changed:
            if original:m.node_tree.links.new(original,m.node_tree.nodes.get('Material Output').inputs['Surface'])
            for n in created:m.node_tree.nodes.remove(n)
        img=images[channel];img.filepath_raw=str(ASSET/'textures'/f'ztz99a_{budget}_{channel.lower()}.png');img.file_format='PNG';img.save();log(f'Saved {img.filepath_raw}')
    links.new(tex['BaseColor'].outputs['Color'],bs.inputs['Base Color'])
    normal=nodes.new('ShaderNodeNormalMap');links.new(tex['Normal'].outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    split=nodes.new('ShaderNodeSeparateColor');links.new(tex['ORM'].outputs['Color'],split.inputs[0]);links.new(split.outputs['Green'],bs.inputs['Roughness']);links.new(split.outputs['Blue'],bs.inputs['Metallic'])
    # Official glTF exporter recognizes this named Occlusion input.
    tree=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree');tree.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat');group=nodes.new('ShaderNodeGroup');group.node_tree=tree;links.new(split.outputs['Red'],group.inputs['Occlusion'])
    for o in high.values():bpy.data.objects.remove(o,do_unlink=True)
    for o in source_empties:bpy.data.objects.remove(o,do_unlink=True)
    empties=rig(low)
    for img in images.values():img.pack()
    for o in low.values():o['triangle_budget']=budget
    select(list(low.values())+list(empties.values()))
    out=ASSET/f'ztz99a_{budget}.glb'
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_tangents=True,export_normals=True,export_texcoords=True,export_materials='EXPORT')
    manifest={'id':f'cn_ztz99a_lod_{budget}','budget_triangles':budget,'actual_triangles':sum(counts.values()),'triangles_by_group':counts,'texture_size':[size,size],'bake':'Cycles selected-to-active, corresponding mechanical groups; source high evaluated geometry; tangent OpenGL normal; diffuse COLOR only; ORM emission with local AO, roughness, metallic','bake_margin_px':6,'uv':'unique nonoverlapping smart projection, separate unwrap per LOD','rig':['hull','turret','barrel','gun_recoil','muzzle'],'axes':'Blender +Y forward / +Z up -> glTF -Z forward / +Y up','source_high_manifest':json.loads((ROOT/'source_manifest.json').read_text()),'textures':{k:Path(v.filepath_raw).name for k,v in images.items()}}
    (ASSET/f'ztz99a_{budget}.manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'ztz99a_{budget}.blend'))
    sc.cycles.use_denoising=True;sc.cycles.samples=24
    render(ROOT/'renders'/f'lod{budget}_hero.png')
    render(ROOT/'renders'/f'lod{budget}_side.png','side')
    log(f'LOD {budget} COMPLETE actual={sum(counts.values())}')

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['all']
    if args[0] in ('all','high'):high_build()
    if args[0]=='lod':bake_lod(int(args[1]))
    elif args[0]=='all':
        for budget in (4000,2000,1000):bake_lod(budget)
