"""Apply shared materials to saved .blend files, preserving authored vertices and pivots.

Blender --background --threads 4 --python-exit-code 1 --python authoring/vehicles/apply_style.py
Optional '-- <vehicle_id>' applies the prototype before the remaining assets.
"""
import sys
import json
from pathlib import Path
import bpy

AUTHOR = Path(__file__).resolve().parent
sys.path.insert(0, str(AUTHOR))
import style_metadata as style

ids = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for source in sorted(AUTHOR.glob('*.blend')):
    if ids and source.stem not in ids:
        continue
    bpy.ops.wm.open_mainfile(filepath=str(source))
    bpy.context.preferences.filepaths.save_version = 0
    before = {o.name: ([tuple(v.co) for v in o.data.vertices], tuple(v for row in o.matrix_local for v in row))
              for o in bpy.data.objects if o.type == 'MESH'}
    style.apply_palette()
    after = {o.name: ([tuple(v.co) for v in o.data.vertices], tuple(v for row in o.matrix_local for v in row))
             for o in bpy.data.objects if o.type == 'MESH'}
    if before != after:
        raise RuntimeError('Palette operation altered geometry or pivots')
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    output = style.ROOT / 'assets/vehicles' / (source.stem + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_apply=True,
                              export_extras=True, export_yup=True, export_cameras=False, export_lights=False)
    manifest_path = output.with_suffix('.manifest.json')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest_path.write_text(json.dumps(style.metadata(manifest, source, output), indent=2)+'\n', encoding='utf-8')
    print('STYLE_PRESERVED_GEOMETRY_PASS ' + source.stem)
