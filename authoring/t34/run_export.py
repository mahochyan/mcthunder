# headless export runner — build_t34.py is the asset truth (MCP-iterated, persisted verbatim)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_t34 as B

model = B.Builder()
model.build()
B.create(model)
import bpy
bpy.ops.object.select_all(action='DESELECT')
for ob in bpy.data.objects:
    if ob.hide_viewport or ob.name.startswith('RIG_'):
        continue
    if ob.name.startswith('Cosmetic_') or ob.name in ('hull', 'turret', 'barrel', 'gun_recoil'):
        ob.select_set(True)
out = Path(__file__).resolve().parent / 'output'
out.mkdir(exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out / 't34_replica.glb'), export_format='GLB',
                          export_extras=True, export_yup=True, export_cameras=False,
                          export_lights=False, use_selection=True)
tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Cosmetic'))
print('HEADLESS_EXPORT_OK tris=', tris)
