"""Shared palette application and provenance for all three Blender export workflows."""
import hashlib
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PATH = ROOT / 'assets/art_palette.json'
PALETTE = json.loads(PALETTE_PATH.read_text(encoding='utf-8'))
NAMES = {'Olive drab': 'olive', 'Paint on fittings': 'edge', 'Recesses': 'dark',
         'Rubber': 'rubber', 'Worn steel': 'steel', 'Canvas': 'canvas', 'Optics': 'glass'}

def linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

def apply_palette():
    for material in bpy.data.materials:
        key = NAMES.get(material.name)
        if key is None:
            continue
        h = PALETTE['colors'][key]
        color = tuple(linear(int(h[i:i+2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)
        material.diffuse_color = color
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = color
        shader.inputs['Roughness'].default_value = PALETTE['roughness']
        shader.inputs['Metallic'].default_value = 0.2 if key == 'steel' else 0.0
    bpy.context.scene['art_style'] = PALETTE['style']

def metadata(manifest, source, output):
    manifest.update({
        'schema_version': 2,
        'author': 'MCTHUNDER project original procedural artwork',
        'license_status': 'project_original_no_third_party_model_restrictions',
        'redistribute_source_allowed': True,
        'source_file': source.relative_to(ROOT).as_posix(),
        'runtime_file': output.relative_to(ROOT).as_posix(),
        'generator': manifest.get('generator', 'authoring/vehicles/build_models.py'),
        'edited_export': 'authoring/vehicles/export_current.py',
        'art_style': PALETTE['style'],
        'palette_sha256': hashlib.sha256(PALETTE_PATH.read_bytes()).hexdigest(),
        'blender_version': bpy.app.version_string,
        'blend_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'glb_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'units': 'metres', 'runtime_axes': '+Y up, -Z forward',
        'preserve_gameplay_geometry': True,
        'lod_policy': manifest.get('lod_policy', 'shared exact armor skin; small fittings end at 140m; track pads end at 100m'),
        'triangle_budget_with_runtime_tracks': manifest.get('triangle_budget_with_runtime_tracks', 25000)
    })
    return manifest
