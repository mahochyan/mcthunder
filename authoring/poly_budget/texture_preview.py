"""UV-map the approved ~1000-triangle M4 study to a concept-derived atlas.

Run inside Blender. Atlas tiles are shared deliberately; no floating decal geometry.
The render is an asset study, not a claim of gameplay integration.
"""
import bpy
import sys
import json
import math
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from build_preview import Model, coord, studio, aim

OUT = HERE / 'textured'
OUT.mkdir(exist_ok=True)
ATLAS = OUT / 'm4_concept_atlas_v1.png'


def tile_uv(tile, u, v, padding=.018):
    col, row = tile % 4, tile // 4
    u=max(0,min(1,u)); v=max(0,min(1,v))
    u = padding + u * (1 - 2 * padding)
    v = padding + v * (1 - 2 * padding)
    return ((col + u) / 4, (3 - row + v) / 4)


def project(points, ax, ay, bounds=None):
    if bounds is None:
        bounds = (min(p[ax] for p in points), max(p[ax] for p in points),
                  min(p[ay] for p in points), max(p[ay] for p in points))
    a,b,c,d = bounds
    return [((p[ax]-a)/max(b-a,.00001), (p[ay]-c)/max(d-c,.00001)) for p in points]


def face_uv(part, points, color):
    normal = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
    center = sum(points, Vector()) / len(points)
    tile = {'rubber':12, 'track':13, 'steel':13, 'canvas':14, 'recess':13,
            'dark_paint':1}.get(color, 0)
    axis = max(range(3), key=lambda i: abs(normal[i]))
    axes = [(2,1),(0,2),(0,1)][axis]
    uv = project(points, *axes)
    if part == 'wheels' and abs(normal.x) > .99:
        z = min([-2.52,-1.75,-1.05,-.35,.35,1.05,1.75,2.52], key=lambda z: abs(z-center.z))
        r = .435 if abs(z)>2 else .33
        y = .54 if abs(z)>2 else .45
        tile = 3 if z < -2 else 2
        uv = [(.5+(p.z-z)/r*.465, .5+(p.y-y)/r*.465) for p in points]
    elif part == 'tracks':
        # Each external tread quad represents four links; subdivisions preserve silhouette.
        if max(p.x for p in points)-min(p.x for p in points) > .4:
            tile = 4
            a,b,c,d=points
            uv=[(0,0),(0,1),(1,1),(1,0)]
        else:
            tile = 13
    elif part == 'hull':
        if abs(normal.z)>.60 and center.z < -1.8 and center.y > 1.0 and abs(center.x)<.2:
            tile=5; uv=project(points,0,1)
        elif abs(normal.z)>.90 and center.z > 2.5:
            tile=10; uv=project(points,0,1)
        elif abs(normal.x)>.98 and center.y>1.25:
            tile=8; uv=project(points,2,1)
        elif normal.y != 0 and abs(normal.y)>.98 and center.y>1.85 and center.z>1:
            tile=7; uv=project(points,0,2)
        elif abs(normal.y)>.98 and 1.90<center.y<2 and center.z<-.7:
            tile=15; uv=project(points,0,2)
    elif part == 'turret':
        if abs(normal.x)>.80 and center.y<2.6:
            tile=6
            uv=project(points,2,1,(-.75,.20,2.0,2.66))
        elif abs(normal.y)>.99 and center.y>2.7:
            tile=9; uv=project(points,0,2)
    elif part == 'suspension' and abs(normal.x)>.99:
        tile=11; uv=project(points,2,1)
    return [tile_uv(tile,u,v) for u,v in uv]


def subdivide_treads(model):
    vertices, faces, colors = model.groups['tracks']
    result_faces=[]; result_colors=[]
    for index,(face,color) in enumerate(zip(faces,colors)):
        pts=[Vector(vertices[i]) for i in face]
        if index%40<10 and max(p.x for p in pts)-min(p.x for p in pts)>.4 and (pts[1]-pts[0]).length>4:
            a,b,c,d=pts
            for i in range(4):
                t0,t1=i/4,(i+1)/4
                quad=[a.lerp(b,t0),a.lerp(b,t1),d.lerp(c,t1),d.lerp(c,t0)]
                start=len(vertices); vertices.extend(tuple(p) for p in quad)
                result_faces.append(tuple(range(start,start+4))); result_colors.append(color)
        else:
            result_faces.append(face); result_colors.append(color)
    model.groups['tracks']=(vertices,result_faces,result_colors)


def make_model():
    model=Model(1000)
    optional=model.optional
    model.optional=lambda label,build: False if label=='low-budget flat wheel hub' else optional(label,build)
    model.build()
    # Extruded yokes visibly join each paired wheel to its bogie; back faces are hidden.
    model.groups['suspension']=([],[],[])
    for side in [-1,1]:
        for z in [-1.40,0,1.40]:
            outline=[(-.14,.97),(.14,.97),(.14,.75),(.42,.50),(.32,.40),(0,.66),(-.32,.40),(-.42,.50),(-.14,.75)]
            points=[(side*x,y,z+dz) for x in [1.445,1.485] for dz,y in outline]
            n=len(outline)
            faces=[tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            model.add('suspension',points,faces,'dark_paint')
    # Divide the coplanar deck into front and rear UV panels (two extra triangles).
    vertices,faces,colors=model.groups['hull']
    new_faces=[]; new_colors=[]
    for face,color in zip(faces,colors):
        points=[Vector(vertices[i]) for i in face]
        if len(face)>4 and all(abs(p.y-1.86)<.001 for p in points):
            for rear in (False,True):
                polygon=[]
                for a,b in zip(points,points[1:]+points[:1]):
                    inside_a=(a.z>=.90) if rear else (a.z<=.90)
                    inside_b=(b.z>=.90) if rear else (b.z<=.90)
                    if inside_a: polygon.append(a)
                    if inside_a!=inside_b: polygon.append(a.lerp(b,(.90-a.z)/(b.z-a.z)))
                start=len(vertices); vertices.extend(tuple(p) for p in polygon)
                new_faces.append(tuple(range(start,start+len(polygon)))); new_colors.append(color)
        else:
            new_faces.append(face); new_colors.append(color)
    model.groups['hull']=(vertices,new_faces,new_colors)
    subdivide_treads(model)
    # Only details which change the silhouette spend the newly available geometry.
    model.box('turret',(.4,2.96,.05),(.11,.13,.32),'dark_paint')
    model.rod('turret',(.4,2.79,.15),(.4,2.96,.15),.03,'steel',n=4,cap_a=False,cap_b=False)
    model.rod('turret',(.4,2.99,-.11),(.4,2.99,-.59),.022,'steel',n=4,cap_a=False,cap_b=False)
    model.rod('turret',(-.66,2.53,.3),(-.66,3.22,.3),.009,'steel',n=3,cap_a=False,cap_b=False)
    return model


def create(model):
    material=bpy.data.materials.new('M4_concept_atlas'); material.use_nodes=True
    shader=material.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value=.86
    texture=material.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image=bpy.data.images.load(str(ATLAS)); texture.image.pack()
    texture.interpolation='Linear'
    material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    objects=[]
    for part,(vertices,faces,colors) in model.groups.items():
        mesh=bpy.data.meshes.new(part); mesh.from_pydata([coord(v) for v in vertices],[],faces); mesh.update()
        obj=bpy.data.objects.new(part,mesh); bpy.context.collection.objects.link(obj)
        mesh.materials.append(material)
        layer=mesh.uv_layers.new(name='ConceptAtlasUV')
        for poly,face,color in zip(mesh.polygons,faces,colors):
            values=face_uv(part,[Vector(vertices[i]) for i in face],color)
            for loop,uv in zip(poly.loop_indices,values): layer.data[loop].uv=uv
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
        tri=obj.modifiers.new('Actual triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
        obj.select_set(False); objects.append(obj)
    return objects


def run():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    model=make_model(); objects=create(model)
    count=sum(len(o.data.polygons) for o in objects)
    assert 900<=count<=1100,count
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'m4_textured_1000.glb'),export_format='GLB',use_selection=True,export_yup=True)
    camera=studio(); scene=bpy.context.scene
    scene.render.engine='CYCLES'; scene.cycles.samples=32
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type='OPTIX'; prefs.get_devices()
        for device in prefs.devices: device.use=device.type=='OPTIX'
        if any(d.use for d in prefs.devices): scene.cycles.device='GPU'
    except Exception as error:
        print('GPU unavailable:',error,flush=True)
        scene.render.engine='CYCLES'; scene.cycles.samples=12
    scene['actual_tank_triangles']=count; scene['asset_preview_only']=True
    scene['texture_origin']='Built-in ImageGen, user concept reference, see ATLAS_PROMPT.txt'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'m4_textured_1000.blend'))
    for view,location,target,scale in [('hero',(8,10,6),(0,0,1.25),9.5),('side',(11,0,3),(0,0,1.4),8.1),
                                      ('rear',(7,-10,7),(0,0,1.3),9.1)]:
        camera.location=location; aim(camera,target); camera.data.ortho_scale=scale
        scene.render.filepath=str(OUT/f'm4_textured_{view}.png'); bpy.ops.render.render(write_still=True)
    report={'triangles':count,'parts':{o.name:len(o.data.polygons) for o in objects},'materials':1,
            'texture':ATLAS.name,'texture_size':list(bpy.data.images.get('m4_concept_atlas_v1.png').size),
            'uv_layers':1,'gameplay_integrated':False,'reference':'User M4-style concept sheet',
            'geometry':'Original authored low-poly mesh; real open bore, wheels and silhouette attachments',
            'texture_detail':'Road wheel spokes, track links, armor seams, markings, hatches, grilles'}
    (OUT/'TEXTURED_REPORT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('TEXTURED_MODEL_PASS',count,flush=True)


if __name__=='__main__': run()
