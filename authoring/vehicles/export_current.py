"""Export a saved, edited vehicle .blend without regenerating its authored meshes.

Blender -b authoring/vehicles/<id>.blend -P authoring/vehicles/export_current.py
Run tests/run_blender_asset_checks.gd afterwards; changes to armor need matching
gameplay layout changes, not an unchecked visual-only replacement.
"""
import bpy
import hashlib
import json
from pathlib import Path

author = Path(__file__).resolve().parent
source = Path(bpy.data.filepath).resolve()
if source.parent != author or source.suffix != '.blend':
    raise RuntimeError('Open a saved vehicle .blend from authoring/vehicles first')
target = author.parents[1]/'assets/vehicles'
manifest_path = target/(source.stem+'.manifest.json')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
if bpy.context.scene.get('vehicle_id') != source.stem:
    raise RuntimeError('Scene vehicle identity and source filename disagree')
bpy.ops.export_scene.gltf(filepath=str(target/(source.stem+'.glb')),export_format='GLB',
                          export_apply=True,export_extras=True,export_yup=True,
                          export_cameras=False,export_lights=False)
manifest['blender_version'] = bpy.app.version_string
manifest['blend_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
manifest['glb_sha256'] = hashlib.sha256((target/(source.stem+'.glb')).read_bytes()).hexdigest()
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('BLENDER_EDIT_EXPORT_PASS '+source.stem)
