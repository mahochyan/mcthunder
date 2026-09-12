"""Source provenance and deterministic authoring checks; no external writes."""
import copy
import importlib.util
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("modern_builder", ROOT / "authoring/reference_data/build_modern_vehicle_packages.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class ModernPackageBuilderChecks(unittest.TestCase):
    def test_reproducible_and_project_local(self):
        for identity in builder.IDS:
            packet = builder.build(identity)
            path = ROOT / f"authoring/reference_data/modern_vehicles/{identity}.json"
            self.assertEqual(packet, json.loads(path.read_text(encoding="utf-8")))
            self.assertEqual(packet, builder.build(identity))
            self.assertNotIn("model_binding", packet)
            self.assertEqual(packet["completion"]["status"], "candidate_only")
            for source in packet["sources"].values():
                self.assertTrue(source["artifact"].startswith("res://"))
                self.assertEqual(source["sha256"], builder.sha(ROOT / source["artifact"][6:]))
                self.assertEqual(source["source_vehicle_id"], identity)

    def test_preserves_raw_reference_and_independent_rules(self):
        for identity in builder.IDS:
            packet = builder.build(identity)
            candidate = builder.read(ROOT / f"assets/reference_data/candidates/{identity}.json")
            for field in ["fields", "ammo_racks", "crew_roster", "weapon_references"]:
                self.assertEqual(packet["reference_trace"][field], candidate[field])
            self.assertEqual(packet["reference_trace"]["unresolved"], candidate["gaps"])
            self.assertEqual(packet["facts"]["runtime.simulation"]["origin"], "game_rule")
            self.assertEqual(packet["facts"]["geometry.modules"]["origin"], "game_rule")
            self.assertNotEqual(packet["runtime"]["reload_time"], candidate["ammo_racks"][0]["supply"]["replenish_seconds"])
            self.assertIsNone(candidate["ammo_racks"][0]["supply"]["shot_reload_seconds"])
            self.assertIn("project design revision", packet["facts"]["identity.year"]["note"])
            self.assertEqual([s["family"] for s in packet["shell_catalog"]["shells"]], ["APFSDS", "HEAT"])
            self.assertTrue(all(s["id"].startswith("game_") for s in packet["shell_catalog"]["shells"]))
            self.assertFalse(any(row["kind"] == "dummy_weapon" for row in packet["modules"]))

    def reject_candidate_mutation(self, mutate):
        identity = builder.IDS[0]
        path = ROOT / f"assets/reference_data/candidates/{identity}.json"
        changed = copy.deepcopy(builder.read(path))
        mutate(changed)
        original = builder.read
        with patch.object(builder, "read", side_effect=lambda p: changed if p == path else original(p)):
            with self.assertRaises(ValueError):
                builder.build(identity)

    def test_wrong_vehicle(self):
        self.reject_candidate_mutation(lambda p: p.update(id="ussr_t_80u"))

    def test_missing_muzzle_velocity(self):
        self.reject_candidate_mutation(lambda p: p.update(fields=[r for r in p["fields"] if r["key"] != "shell.muzzle_velocity_mps"]))

    def test_duplicate_field(self):
        self.reject_candidate_mutation(lambda p: p["fields"].append(copy.deepcopy(next(r for r in p["fields"] if r["key"] == "shell.caliber_mm"))))

    def test_null_caliber(self):
        self.reject_candidate_mutation(lambda p: next(r for r in p["fields"] if r["key"] == "shell.caliber_mm").update(candidate_value=None))

    def test_ambiguous_primary(self):
        self.reject_candidate_mutation(lambda p: p["weapon_references"].append(copy.deepcopy(p["weapon_references"][0])))

    def test_rack_count_conflict(self):
        self.reject_candidate_mutation(lambda p: p["ammo_racks"][0].update(count=27))

    def test_extra_loader_not_in_original_roster(self):
        self.reject_candidate_mutation(lambda p: p["crew_roster"].append({"station": "loader"}))

    def test_frozen_snapshot_hash_drift(self):
        self.reject_candidate_mutation(lambda p: p["source"].update(sha256="0" * 64))

    def test_wrong_equipment_identity(self):
        identity = builder.IDS[0]
        path = ROOT / f"authoring/reference_data/modern_equipment/{identity}.json"
        changed = builder.read(path); changed["id"] = "germ_leopard_2a4"
        original = builder.read
        with patch.object(builder, "read", side_effect=lambda p: changed if p == path else original(p)):
            with self.assertRaises(ValueError):
                builder.build(identity)


if __name__ == "__main__":
    unittest.main(verbosity=2)
