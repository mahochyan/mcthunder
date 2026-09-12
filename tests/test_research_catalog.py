"""Validate family identity, source provenance, and portable raw model snapshots."""
import hashlib
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
C = json.loads((ROOT/'assets/research/soviet_german_tree.json').read_text(encoding='utf-8'))
ROWS = {r['id']: r for r in C['vehicles']}

class ResearchCatalogChecks(unittest.TestCase):
    def test_base_identity_and_variant_partition(self):
        self.assertEqual(len(ROWS), 212)
        cache = {r['id']: r for r in C['cache_entries']}
        self.assertEqual(len(cache), 393)
        accounted = set(C['unmapped_cache_ids']) | {r['id'] for r in C['excluded_references']}
        for nation in ['ussr', 'germany']:
            frozen = json.loads((ROOT/f'assets/research/plans/{nation}.json').read_text(encoding='utf-8'))
            mappings = frozen['mappings']
            self.assertEqual({r['id'] for r in mappings if r['selection']=='base'}, {r['id'] for r in ROWS.values() if r['nation']==nation})
            for row in mappings:
                if row['selection']=='non_vehicle_reference': continue
                base = ROWS[row['base_id']]
                self.assertEqual(base['family'], row['family'])
                self.assertEqual(base['nation'], nation)
                if row['id']!=row['base_id']:
                    self.assertNotIn(row['id'], ROWS)
                    self.assertIn(row['id'], {r['id'] for r in base['variant_refs']})
                accounted.add(row['id'])
        self.assertEqual(accounted, set(cache))

    def test_exact_source_hashes(self):
        index = json.loads((ROOT/'assets/reference_data/index.json').read_text(encoding='utf-8'))
        entries = {r['vehicle_id']:r for r in index['entries']}
        for row in C['cache_entries']:
            self.assertEqual(row['source_sha256'], entries[row['id']]['sha256'])
        for row in ROWS.values():
            self.assertIsNone(row['combat_package'])
            self.assertFalse(row['historical_verified'])
            self.assertIsNone(row['rank'])
            self.assertIsNone(row['battle_rating'])

    def test_raw_models_and_thumbnails_are_self_contained(self):
        thumbnails = json.loads((ROOT/'assets/research/thumbnails/manifest.json').read_text(encoding='utf-8'))
        modeled = {r['id'] for r in ROWS.values() if r['model']}
        self.assertEqual(set(thumbnails), modeled)
        self.assertEqual(len(modeled), 113)
        for identity in modeled:
            model = ROWS[identity]['model']
            raw = (ROOT/model['path'].removeprefix('res://')).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), model['sha256'])
            self.assertFalse(model['combat_admitted'])
            magic, version, length = struct.unpack_from('<III', raw)
            self.assertEqual((magic, version, length), (0x46546c67, 2, len(raw)))
            json_length = struct.unpack_from('<I', raw, 12)[0]
            gltf = json.loads(raw[20:20+json_length])
            for resource in gltf.get('buffers', [])+gltf.get('images', []):
                self.assertTrue(not resource.get('uri') or resource['uri'].startswith('data:'))
            thumb = thumbnails[identity]
            self.assertEqual(thumb['model_sha256'], model['sha256'])
            self.assertTrue((ROOT/thumb['path'].removeprefix('res://')).read_bytes().startswith(b'\x89PNG\r\n\x1a\n'))

if __name__ == '__main__':
    unittest.main()
