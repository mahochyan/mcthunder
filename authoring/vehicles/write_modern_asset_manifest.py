"""Record the integrated local models without modifying geometry or textures."""
import hashlib
import json
import pathlib
import struct

root = pathlib.Path(__file__).resolve().parents[2]
models = {
    'leopard2a7v/leopard2a7v.glb': 'artifacts/leopard2a7_source_corrected/Leopard2A7V_10000_Redesigned.glb',
    'm1a1/m1a1.glb': 'authoring/m1a1_rebuild/production_lods/4k_tri/m1a1.glb',
    'm1a1/m1a1_1k.glb': 'authoring/m1a1_rebuild/production_lods/1k_tri/m1a1.glb',
    'm1a1/m1a1_2k.glb': 'authoring/m1a1_rebuild/production_lods/2k_tri/m1a1.glb',
    'ztz99a/ztz99a_1000.glb': 'assets/vehicles/ztz99a/ztz99a_1000.glb',
    'ztz99a/ztz99a_2000.glb': 'assets/vehicles/ztz99a/ztz99a_2000.glb',
    'ztz99a/ztz99a_4000.glb': 'assets/vehicles/ztz99a/ztz99a_4000.glb',
}
out = {'status': 'art_showroom_only_combat_integration_pending', 'assets': []}
for relative, source in models.items():
    p = root / 'assets/vehicles' / relative
    data = p.read_bytes()
    assert data[:4] == b'glTF'
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + length])
    triangles = 0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4
            accessor = primitive.get('indices', primitive['attributes']['POSITION'])
            triangles += doc['accessors'][accessor]['count'] // 3
    assert all('bufferView' in image or image.get('uri', '').startswith('data:') for image in doc.get('images', []))
    out['assets'].append({'path': 'res://assets/vehicles/' + relative, 'original_path_in_archive': 'mcthunder/' + source, 'sha256': hashlib.sha256(data).hexdigest(), 'triangles': triangles, 'meshes': len(doc['meshes']), 'embedded_images': len(doc.get('images', []))})
target = root / 'assets/vehicles/MODERN_ASSETS.json'
target.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(out, ensure_ascii=False, indent=2))
