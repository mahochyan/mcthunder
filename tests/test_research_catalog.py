"""Validate family identity, source provenance, and portable raw model snapshots."""
import hashlib
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
C = json.loads((ROOT/'assets/research/soviet_german_tree.json').read_text(encoding='utf-8'))
ROWS = {r['id']: r for r in C['vehicles']}
P = json.loads((ROOT/'assets/research/research_runtime_profiles.json').read_text(encoding='utf-8'))
PROFILES = {r['id']: r for r in P['profiles']}
I = json.loads((ROOT/'assets/research/research_model_interfaces.json').read_text(encoding='utf-8'))
INTERFACES = {r['id']: r for r in I['interfaces']}

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
        bound = set(C['alignment']['bound_ids'])
        for row in C['cache_entries']:
            self.assertEqual(row['source_sha256'], entries[row['id']]['sha256'])
        for row in ROWS.values():
            self.assertEqual(row['combat_package'] is not None, row['id'] in bound)
            self.assertFalse(row['historical_verified'])
            self.assertIsNone(row['rank'])
            self.assertIsNone(row['battle_rating'])

    def test_raw_models_and_thumbnails_are_self_contained(self):
        thumbnails = json.loads((ROOT/'assets/research/thumbnails/manifest.json').read_text(encoding='utf-8'))
        modeled = {r['id'] for r in ROWS.values() if r['model']}
        self.assertEqual(set(thumbnails), modeled)
        self.assertEqual(len(modeled), 141)
        for identity in modeled:
            model = ROWS[identity]['model']
            raw = (ROOT/model['path'].removeprefix('res://')).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), model['sha256'])
            self.assertEqual(model['combat_admitted'], identity in set(C['alignment']['bound_ids']))
            magic, version, length = struct.unpack_from('<III', raw)
            self.assertEqual((magic, version, length), (0x46546c67, 2, len(raw)))
            json_length = struct.unpack_from('<I', raw, 12)[0]
            gltf = json.loads(raw[20:20+json_length])
            for resource in gltf.get('buffers', [])+gltf.get('images', []):
                self.assertTrue(not resource.get('uri') or resource['uri'].startswith('data:'))
            selected = ROWS[identity]['combat_package']['runtime_model'] if ROWS[identity]['combat_package'] else model
            thumb = thumbnails[identity]
            self.assertEqual(thumb['model_sha256'], selected['sha256'])
            self.assertTrue((ROOT/thumb['path'].removeprefix('res://')).read_bytes().startswith(b'\x89PNG\r\n\x1a\n'))

    def test_exact_combat_bindings(self):
        intent = json.loads((ROOT/'authoring/reference_data/research_combat_bindings.json').read_text(encoding='utf-8'))
        expected = {row['vehicle_id'] for row in intent['bindings']}
        actual = {row['id'] for row in ROWS.values() if row['combat_package'] is not None}
        self.assertEqual(expected, actual)
        self.assertEqual(actual, {'ussr_t_80b', 'germ_leopard_2a4'})
        self.assertEqual(C['alignment']['set_policy'], 'exact_id_no_alias_no_missing_no_extra')
        for vehicle_id in actual:
            link = ROWS[vehicle_id]['combat_package']
            packet_path = ROOT/link['path'].removeprefix('res://')
            runtime_path = ROOT/link['runtime_model']['path'].removeprefix('res://')
            packet = json.loads(packet_path.read_text(encoding='utf-8'))
            self.assertEqual(packet['id'], vehicle_id)
            self.assertEqual(packet['source_binding']['source_vehicle_id'], vehicle_id)
            self.assertEqual(packet['model_binding']['vehicle_id'], vehicle_id)
            self.assertEqual(packet['model_binding']['model']['source_vehicle_id'], vehicle_id)
            self.assertEqual(hashlib.sha256(packet_path.read_bytes()).hexdigest(), link['sha256'])
            self.assertEqual(hashlib.sha256(runtime_path.read_bytes()).hexdigest(), link['runtime_model']['sha256'])

    def test_runtime_reference_profiles_are_exact_and_complete(self):
        self.assertEqual(P['schema_version'], 1)
        self.assertEqual(P['set_policy'], 'exact_tree_id_no_alias_no_missing_no_extra')
        self.assertEqual(set(PROFILES), set(ROWS))
        self.assertEqual(P['vehicle_count'], 212)
        self.assertEqual(P['trial_mobility_count'], 141)
        self.assertEqual(P['combat_count'], 2)
        for vehicle_id, profile in PROFILES.items():
            row = ROWS[vehicle_id]
            source = profile['source']
            snapshot = ROOT/source['snapshot'].removeprefix('res://')
            self.assertEqual(hashlib.sha256(snapshot.read_bytes()).hexdigest(), source['sha256'])
            self.assertEqual(source['sha256'], row['source_sha256'])
            mobility = profile['mobility']
            for key in ('forward_max_mps', 'reverse_max_mps', 'hull_turn_deg_s', 'design_mass_kg'):
                self.assertEqual(mobility[key]['resolution_state'], 'explicit_reference_candidate')
                if key in ('forward_max_mps', 'reverse_max_mps'):
                    self.assertGreaterEqual(mobility[key]['value'], 0)
                else:
                    self.assertGreater(mobility[key]['value'], 0)
            self.assertEqual(mobility['trial_acceleration_mps2']['resolution_state'], 'project_design_fallback')
            self.assertEqual(profile['runtime_use']['research_trial_mobility'], row['model'] is not None)
            self.assertEqual(profile['runtime_use']['combat'], row['combat_package'] is not None)

    def test_model_interfaces_match_every_selected_model(self):
        modeled = {vehicle_id for vehicle_id, row in ROWS.items() if row['model']}
        self.assertEqual(I['schema_version'], 2)
        self.assertEqual(I['set_policy'], 'exact_modeled_tree_id_no_alias_no_missing_no_extra')
        self.assertEqual(set(INTERFACES), modeled)
        self.assertEqual((I['model_count'], I['trial_rig_ready_count'], I['combat_interface_ready_count']), (141, 141, 2))
        self.assertEqual((I['tracked_count'], I['wheeled_count']), (127, 14))
        self.assertEqual((I['weapon_rig_ready_count'], I['nonstandard_weapon_count'], I['unarmed_count']), (136, 2, 3))
        for vehicle_id, interface in INTERFACES.items():
            row = ROWS[vehicle_id]
            selected = row['combat_package']['runtime_model'] if row['combat_package'] else row['model']
            self.assertEqual(interface['model']['path'], selected['path'])
            self.assertEqual(interface['model']['sha256'], selected['sha256'])
            model_path = ROOT/interface['model']['path'].removeprefix('res://')
            self.assertEqual(hashlib.sha256(model_path.read_bytes()).hexdigest(), interface['model']['sha256'])
            self.assertTrue(interface['trial_rig_ready'])
            self.assertEqual(interface['combat_interface_ready'], row['combat_package'] is not None)
            nodes = interface['nodes']
            self.assertEqual(nodes['hull'], 'HullArmour')
            if interface['weapon_control'] == 'yaw_pitch':
                self.assertTrue(interface['weapon_rig_ready'])
                self.assertEqual((nodes['turret_pivot'], nodes['gun_pivot']), ('TurretPivot', 'GunPivot'))
                self.assertTrue(nodes['main_gun'].startswith('MainGun'))
            else:
                self.assertFalse(interface['weapon_rig_ready'])
                self.assertIn(interface['weapon_control'], ('unavailable_nonstandard', 'none'))
                self.assertTrue(interface['weapon_unavailable_reason'])
            if interface['locomotion'] == 'tracked':
                self.assertEqual((nodes['left_track'], nodes['right_track']), ('track_l', 'track_r'))
            else:
                paired = len(nodes['left_wheels']) == len(nodes['right_wheels']) and len(nodes['left_wheels']) > 0
                aggregate = isinstance(nodes['wheel_assembly'], str) and bool(nodes['wheel_assembly'])
                self.assertNotEqual(paired, aggregate)

if __name__ == '__main__':
    unittest.main()
