"""Export a saved, edited vehicle .blend without regenerating its authored meshes.

Blender -b authoring/vehicles/<id>.blend -P authoring/vehicles/export_current.py
Run tests/run_blender_asset_checks.gd afterwards; changes to armor need matching
gameplay layout changes, not an unchecked visual-only replacement.
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path

author = Path(__file__).resolve().parent
sys.path.insert(0, str(author))
import style_metadata as style
source = Path(bpy.data.filepath).resolve()
if source.parent != author or source.suffix != '.blend':
    raise RuntimeError('Open a saved vehicle .blend from authoring/vehicles first')
target = author.parents[1]/'assets/vehicles'
manifest_path = target/(source.stem+'.manifest.json')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
if bpy.context.scene.get('vehicle_id') != source.stem:
    raise RuntimeError('Scene vehicle identity and source filename disagree')
if 'texture_file' in manifest:
    # Copy authored UV edits back to the runtime query skin's matching vertex indices.
    seed = json.loads((author/'seeds'/(source.stem+'.json')).read_text(encoding='utf-8'))
    from mathutils import Vector
    atlas_uv = {}
    for patch in seed['armor']:
        obj = bpy.data.objects['Armor_'+patch['id']]
        mesh = obj.data
        values = [None]*len(patch['vertices'])
        for face in mesh.polygons:
            for loop_index in face.loop_indices:
                vertex = obj.matrix_local @ mesh.vertices[mesh.loops[loop_index].vertex_index].co
                local = Vector((vertex.x,vertex.z,-vertex.y))
                index = min(range(len(values)),key=lambda i:(Vector(patch['vertices'][i])-local).length)
                if (Vector(patch['vertices'][index])-local).length>.0001:
                    raise RuntimeError('Armor geometry edit requires matching gameplay seed: '+patch['id'])
                uv = tuple(mesh.uv_layers.active.data[loop_index].uv)
                if values[index] is not None and (Vector(values[index])-Vector(uv)).length>.0001:
                    raise RuntimeError('Place UV seams at patch boundaries: '+patch['id'])
                values[index] = uv
        if any(uv is None for uv in values): raise RuntimeError('Missing armor UV vertex: '+patch['id'])
        atlas_uv[patch['id']] = values
    manifest['armor_uv'] = atlas_uv
    manifest['actual_triangles'] = sum(len(p.vertices)-2 for o in bpy.data.objects if o.type=='MESH' for p in o.data.polygons)
    if manifest['actual_triangles']>1100: raise RuntimeError('Edited model exceeds the approved triangle budget')

style.apply_palette()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(target/(source.stem+'.glb')),export_format='GLB',
                          export_apply=True,export_extras=True,export_yup=True,
                          export_cameras=False,export_lights=False)
manifest['blender_version'] = bpy.app.version_string
manifest['blend_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
manifest['glb_sha256'] = hashlib.sha256((target/(source.stem+'.glb')).read_bytes()).hexdigest()
style.metadata(manifest, source, target/(source.stem+'.glb'))
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('BLENDER_EDIT_EXPORT_PASS '+source.stem)
