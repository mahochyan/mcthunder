"""Real summary fixtures plus adversarial parsing/import tests; no engine/external writes."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("reference_import", ROOT / "authoring/reference_data/import_reference_data.py")
IMPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORT)
FIXTURES = Path(__file__).parent / "fixtures"


def source(model_id):
    return (FIXTURES / (model_id + ".txt")).read_bytes()


def detailed(model_id):
    return IMPORT.Summary(source(model_id), model_id).detailed()


def fields(packet):
    return {row["key"]: row for row in packet["fields"]}


class RealSummaryTests(unittest.TestCase):
    def test_fixture_identity_and_version(self):
        for model_id in IMPORT.DEEP_IDS:
            result = detailed(model_id)
            self.assertEqual(result["source"]["resource_version"], "2.57.1.137")
            self.assertFalse(result["historical_verified"])
            self.assertEqual(result["admission"], "candidate_only")
            self.assertIsNone(result["combat_definition"])

    def test_caliber_speed_and_capacity_units(self):
        for model_id, caliber, speed, capacity in (("ussr_t_80b", 125, 905, 38), ("germ_leopard_2a4", 120, 1140, 42)):
            values = fields(detailed(model_id))
            self.assertEqual(values["shell.caliber_mm"]["candidate_value"], caliber)
            self.assertEqual(values["shell.muzzle_velocity_mps"]["candidate_value"], speed)
            self.assertEqual(values["primary.capacity"]["candidate_value"], capacity)
            self.assertAlmostEqual(values["drive.forward_speed_candidate"]["candidate_value"], 75 / 3.6)
            self.assertEqual(values["shell.caliber_mm"]["source_unit"], "m")
            self.assertTrue(values["shell.caliber_mm"]["locator"][0]["line"] > 400)

    def test_distinct_traverse_and_roster_not_generic_module_counts(self):
        t80, leopard = detailed("ussr_t_80b"), detailed("germ_leopard_2a4")
        self.assertEqual(len(t80["crew_roster"]), 3)
        self.assertEqual(len(leopard["crew_roster"]), 4)
        self.assertNotIn("loader", [r["station"] for r in t80["crew_roster"]])
        self.assertEqual(fields(t80)["primary.traverse"]["candidate_value"], {"yaw": 24.0, "pitch": 3.35})
        self.assertEqual(fields(leopard)["primary.traverse"]["candidate_value"], {"yaw": 40.0, "pitch": 40.0})

    def test_rack_replenishment_is_not_shot_reload(self):
        for model_id, count, time in (("ussr_t_80b", 38, 20), ("germ_leopard_2a4", 42, 13)):
            racks = detailed(model_id)["ammo_racks"]
            self.assertEqual(sum(r["count"] for r in racks), count)
            self.assertEqual(racks[0]["supply"]["replenish_seconds"], time)
            self.assertIsNone(racks[0]["supply"]["shot_reload_seconds"])
        first = detailed("germ_leopard_2a4")["ammo_racks"][0]
        self.assertEqual(first["count"], 15)
        self.assertTrue(first["flags"]["ready_rack"]["candidate_value"])
        self.assertFalse(first["flags"]["lethal_detonation"]["candidate_value"])

    def test_empty_not_false_or_one(self):
        result = detailed("ussr_t_80b")
        self.assertIsNone(fields(result)["drive.arcade_power_multiplier"]["candidate_value"])
        flag = result["ammo_racks"][0]["flags"]["ready_rack"]
        self.assertIsNone(flag["candidate_value"])
        self.assertEqual(flag["resolution_state"], "unresolved_empty")

    def test_engine_and_mass_variants_preserve_distinct_meanings(self):
        t80, leo = fields(detailed("ussr_t_80b")), fields(detailed("germ_leopard_2a4"))
        self.assertEqual(t80["drive.engine"]["candidate_value"]["power_hp"], 1100)
        self.assertEqual(leo["drive.engine"]["candidate_value"]["power_hp"], 1500)
        self.assertEqual(t80["drive.rpm"]["candidate_value"]["idle"], 1500)
        self.assertEqual(leo["drive.mass_variants"]["candidate_value"]["fueled"], 55150)
        self.assertEqual(leo["drive.design_mass"]["candidate_value"], 47000)

    def test_generic_autoloader_and_dummy_not_installed_weapons(self):
        packet = detailed("germ_leopard_2a4")
        module = next(r for r in packet["damage_module_references"] if r["id"] == "autoloader_dm")
        self.assertEqual(module["presence"], "unresolved_generic_reference")
        self.assertFalse(module["runtime_admitted"])
        weapon = next(r for r in packet["weapon_references"] if r["slot"] == "commander")
        self.assertEqual(weapon["kind"], "dummy_reference_only")
        self.assertFalse(weapon["runtime_admitted"])

    def test_ir_and_upgrades_not_automatic_thermal_capability(self):
        a = fields(detailed("germ_leopard_2a4"))
        self.assertNotIn("gunnerIr", a["optics.raw_ir"]["candidate_value"])
        self.assertNotIn("thermal_enabled", a)
        self.assertIn("nightVisionDmPart", a["optics.raw_ir"]["candidate_value"])
        self.assertFalse(a["equipment.modification_references"]["runtime_admitted"])

    def test_hitpower_and_stability_not_armor_or_stabilizer(self):
        result = fields(detailed("ussr_t_80b"))
        self.assertEqual(result["shell.reference.hitPower"]["candidate_value"], "260.0")
        self.assertNotIn("penetration_mm", result)
        self.assertNotIn("stabilizer", result)
        self.assertIsNone(result["drive.acceleration_unspecified_units"]["candidate_value"])

    def test_card_and_local_armor_remain_separate_with_inheritance(self):
        result = detailed("germ_leopard_2a4")
        self.assertEqual(fields(result)["armor.card_hull"]["candidate_value"], "80, 65, 25")
        hull = next(g for g in result["armor_groups"] if g["id"] == "hull")
        top = next(n for n in hull["nodes"] if n["id"] == "superstructure_top_dm")
        front = next(n for n in hull["nodes"] if n["id"] == "superstructure_front_dm")
        self.assertEqual(top["properties"]["armorThickness"]["candidate_value"], 35)
        self.assertEqual(top["properties"]["armorClass"]["resolution_state"], "group_inherited_candidate")
        self.assertEqual(front["properties"]["armorClass"]["candidate_value"], "RHAHH_tank")
        self.assertIsNone(top["geometry"])
        self.assertFalse(top["runtime_admitted"])

    def test_source_truncation_is_an_explicit_gap(self):
        gaps = {g["id"]: g for g in detailed("ussr_t_80b")["gaps"]}
        self.assertIn("truncated_sections", gaps)
        self.assertIn("148", gaps["truncated_sections"]["evidence"][0]["raw_value"])

    def test_wrong_id_rejected(self):
        with self.assertRaisesRegex(ValueError, "mismatch"):
            IMPORT.Summary(source("ussr_t_80b"), "germ_leopard_2a4")

    def test_duplicate_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate identity"):
            IMPORT.Summary(source("ussr_t_80b") + b"\n" + "载具 ID : ussr_t_80b".encode(), "ussr_t_80b")

    def test_duplicate_numeric_values_are_conflicts_not_last_wins(self):
        data = source("ussr_t_80b").decode().replace("前进极速      : 75.0 km/h", "前进极速 : 75.0 km/h\n前进极速 : 80.0 km/h").encode()
        value = fields(IMPORT.Summary(data, "ussr_t_80b").detailed())["drive.forward_speed_candidate"]
        self.assertEqual(value["resolution_state"], "conflict_duplicate_field")
        self.assertIsNone(value["candidate_value"])
        self.assertEqual(len(value["locator"]), 2)

    def test_wrong_units_do_not_silently_convert(self):
        data = source("ussr_t_80b").replace(b"75.0 km/h", b"75.0 mph")
        value = fields(IMPORT.Summary(data, "ussr_t_80b").detailed())["drive.forward_speed_candidate"]
        self.assertEqual(value["resolution_state"], "unresolved_unit_or_format")
        self.assertIsNone(value["candidate_value"])

    def test_truncated_tail_preserves_missing_fields(self):
        data = source("ussr_t_80b").decode().split("【武器与弹药】")[0].encode()
        value = fields(IMPORT.Summary(data, "ussr_t_80b").detailed())["shell.caliber_mm"]
        self.assertEqual(value["resolution_state"], "missing")
        self.assertIsNone(value["candidate_value"])


class ImportTests(unittest.TestCase):
    def test_real_fixture_import_is_idempotent_and_sources_unchanged(self):
        with tempfile.TemporaryDirectory() as name:
            base = Path(name); cache = base / "cache"; models = base / "models"; output = base / "output"
            models.mkdir()
            for nation, model_id in zip(IMPORT.NATIONS, IMPORT.DEEP_IDS):
                folder = cache / nation; folder.mkdir(parents=True)
                (folder / (model_id + ".txt")).write_bytes(source(model_id))
            valid = models / "ussr_t_80b" / "制作中"; valid.mkdir(parents=True)
            (valid / "build_report.json").write_text(json.dumps({"id": "ussr_t_80b", "status": "WIP"}))
            (valid / "vehicle.glb").write_bytes(b"fixture only, not parsed or published")
            wrong = models / "wrong_variant"; wrong.mkdir()
            (wrong / "build_report.json").write_text(json.dumps({"id": "germ_leopard_2a4"}))
            before = {p: p.read_bytes() for root in (cache, models) for p in root.rglob("*") if p.is_file()}
            first = IMPORT.import_all(cache, models, output)
            after = {p: p.read_bytes() for p in output.rglob("*") if p.is_file()}
            second = IMPORT.import_all(cache, models, output)
            self.assertEqual(first, second)
            self.assertEqual(after, {p: p.read_bytes() for p in output.rglob("*") if p.is_file()})
            self.assertEqual(before, {p: p.read_bytes() for root in (cache, models) for p in root.rglob("*") if p.is_file()})
            self.assertEqual(first["exact_model_links"], 1)
            self.assertEqual(first["rejected_model_reports"], 1)
            self.assertEqual(first["models_published"], 0)
            self.assertFalse(list(output.rglob("*.glb")))
            self.assertEqual((output / "source_snapshots/ussr_t_80b.txt").read_bytes(), source("ussr_t_80b"))

    def test_output_cannot_modify_source_tree(self):
        with tempfile.TemporaryDirectory() as name:
            base = Path(name)
            with self.assertRaisesRegex(ValueError, "read-only"):
                IMPORT.import_all(base, base / "models", base / "output")


if __name__ == "__main__":
    unittest.main(verbosity=2)
