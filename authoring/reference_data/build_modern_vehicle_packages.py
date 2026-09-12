"""Build reproducible, unadmitted combat packages from frozen project sources.

External tank/model workspaces are never read or written. --check detects drift.
This authoring tool does not modify the runtime roster or waive model admission.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
IDS = ("ussr_t_80b", "germ_leopard_2a4")
RULES = HERE / "modern_vehicles/design_rules.json"
UNITS = dict(distance="m", speed="m/s", acceleration="m/s2", angle="deg",
             angular_speed="deg/s", time="s", mass="kg", armor="mm", caliber="mm")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def artifact(path):
    return "res://" + path.relative_to(ROOT).as_posix()


def build(identity):
    design = copy.deepcopy(read(RULES)["vehicles"][identity])
    candidate_path = ROOT / f"assets/reference_data/candidates/{identity}.json"
    candidate = read(candidate_path)
    equipment_path = HERE / f"modern_equipment/{identity}.json"
    equipment = read(equipment_path)
    if candidate["id"] != identity or candidate["source"]["vehicle_id"] != identity:
        raise ValueError("wrong source vehicle identity")
    if equipment["id"] != identity or equipment["source_candidate"] != {
            "artifact": artifact(candidate_path), "sha256": sha(candidate_path)}:
        raise ValueError("equipment source identity/hash drift")
    source = candidate["source"]
    snapshot = ROOT / "assets/reference_data/source_snapshots" / f"{identity}.txt"
    if sha(snapshot) != source["sha256"]:
        raise ValueError("frozen reference snapshot hash drift")
    sources = {}
    for key, path, origin in [("reference", snapshot, "warthunder_reference"),
                              ("design", RULES, "game_rule"),
                              ("equipment", equipment_path, "game_rule"),
                              ("builder", Path(__file__).resolve(), "game_rule")]:
        sources[key] = dict(origin=origin, source_vehicle_id=identity,
                            applies_to_identity_ids=[identity], excluded_identity_ids=[],
                            sha256=sha(path), artifact=artifact(path),
                            read_state="text_read" if key == "reference" else "authored")
        if key == "reference":
            sources[key]["resource_version"] = source["resource_version"]

    def claim(value, unit="structured", location="design_rules.json", reference=False, refs=None):
        return dict(value=copy.deepcopy(value), status="estimated",
                    origin="warthunder_reference" if reference else "game_rule",
                    source_refs=refs or (["reference"] if reference else ["design", "builder"]),
                    location=location, unit=unit,
                    note=("Frozen War Thunder summary candidate; not historically verified." if reference
                          else "Explicit original game design; unresolved source facts remain in reference_trace. Not historical performance or model delivery."))

    def field(key):
        rows = [row for row in candidate["fields"] if row["key"] == key]
        if len(rows) != 1 or rows[0]["candidate_value"] is None:
            raise ValueError("missing/conflicting required explicit reference field: " + key)
        return rows[0]

    def field_location(key):
        return snapshot.name + ":" + "; ".join(
            "L" + str(row["line"]) + " " + row.get("section", "") + "/" + row.get("group", "")
            for row in field(key)["locator"])

    primary = [row for row in candidate["weapon_references"] if row["slot"] == "primary"]
    if len(primary) != 1 or primary[0]["kind"] != "weapon_reference":
        raise ValueError("primary gun identity unresolved")
    gun = primary[0]["source_weapon_id"]
    caliber = field("shell.caliber_mm")["candidate_value"]
    capacity = field("primary.capacity")["candidate_value"]
    if sum(row["count"] for row in candidate["ammo_racks"]) != capacity:
        raise ValueError("reference rack count conflicts with primary capacity")
    roles = [row["station"] for row in candidate["crew_roster"]]
    if sorted(roles) != sorted(row["role"] for row in design["crew"]):
        raise ValueError("authored crew roster differs from explicit source stations")
    for index, rack_id in enumerate(["ammo_ready", "ammo_reserve"]):
        modules = [row for row in design["modules"] if row["id"] == rack_id]
        if len(modules) != 1 or modules[0]["ammo_capacity"] != candidate["ammo_racks"][index]["count"]:
            raise ValueError("authored rack capacity conflicts with explicit source")
    shells = []
    reason = "Original candidate combat tuning; not a decoded historical or War Thunder penetration/material curve."
    for family in ("APFSDS", "HEAT"):
        rod = family == "APFSDS"
        name = "game_" + family.lower() + "_" + str(int(caliber)) + "_v1"
        speed = design["rod_velocity"] if rod else field("shell.muzzle_velocity_mps")["candidate_value"]
        budget = design["heat_budget"]
        shell = dict(id=name, label=f"{int(caliber)} mm {family} (game tuning)", gun=gun,
                     family=family, source_bullet_type="game_rule_apfsds" if rod else "heat_fs_tank",
                     effect_policy="long_rod" if rod else "chemical", caliber_mm=caliber,
                     muzzle_velocity_mps=speed, penetration_curve=design["rod_curve"] if rod else [[0, budget], [2500, budget]],
                     gravity_scale=1.0, max_flight_time_s=12.0)
        impact = dict(version="wt012-long-rod-v1" if rod else "wt012-chemical-v1",
                      family=family, material_coefficients={"rolled": 1.0, "cast": .95},
                      provenance="game_rule", reason=reason)
        if rod:
            impact.update(ricochet_deg=82, angle_resistance_curve=[[0, 1], [30, 1.2], [60, 1.6], [90, 4]])
            shell["post_penetration_profile"] = dict(
                version="wt013-directional-spall-v1", count=6, cone_deg=25, range_m=3,
                budget_fraction=.2, max_total_mm=60, min_residual_mm=5,
                provenance="game_rule", reason=reason,
                fragment_impact_profile=dict(version="wt012-full-caliber-v1", family="fragment",
                                            normalization_deg=0, overmatch_ratio=0, ricochet_deg=75,
                                            material_coefficients={"rolled": 1.0, "cast": .95},
                                            provenance="game_rule", reason=reason))
        else:
            shell["chemical_profile"] = dict(version="wt013-chemical-jet-v1", penetration_mm=budget,
                                             range_m=4, path_loss_mm_per_m=20, provenance="game_rule", reason=reason)
        shell["impact_profile"] = impact
        shell["evidence"] = {
            "identity": claim({key: shell[key] for key in ["id", "gun", "family", "source_bullet_type", "caliber_mm"]}),
            "ballistics": claim({key: shell[key] for key in ["muzzle_velocity_mps", "penetration_curve", "gravity_scale", "max_flight_time_s"]}),
            "effect": claim(shell["effect_policy"], "text"), "impact": claim(impact)}
        for key, evidence_key in [("post_penetration_profile", "post_penetration"), ("chemical_profile", "chemical")]:
            if key in shell:
                shell["evidence"][evidence_key] = claim(shell[key])
        shells.append(shell)
    runtime = design["runtime"]
    runtime.update(rounds=capacity, muzzle_velocity=shells[0]["muzzle_velocity_mps"],
                   penetration_curve=shells[0]["penetration_curve"])
    assembly = dict(variant=identity, year=2026, suspension="game_rule_tracked",
                    gun=gun, mount="game_rule_trunnion", caliber_mm=caliber, shell=shells[0]["id"])
    facts = {}
    for key, fact, unit in [("variant", "identity.variant", "text"), ("year", "identity.year", "year"),
                            ("suspension", "identity.suspension", "text"), ("gun", "weapon.gun", "text"),
                            ("mount", "weapon.mount", "text"), ("caliber_mm", "weapon.caliber_mm", "mm"),
                            ("shell", "weapon.ammunition", "text")]:
        facts[fact] = claim(assembly[key], unit, "primary weapon/explicit candidate identity" if key in ["gun", "caliber_mm", "variant"] else "build: assembly", key in ["gun", "caliber_mm", "variant"])
    facts["identity.year"]["note"] = "2026 is the project design revision year, not vehicle introduction/service year; historical year remains unresolved."
    facts["weapon.gun"]["location"] = snapshot.name + ":L" + str(primary[0]["line"]) + " [primary]"
    facts["weapon.caliber_mm"]["location"] = field_location("shell.caliber_mm")
    g = design["geometry"]
    facts.update({"crew.roles": claim(roles, "roles", "crew_roster explicit stations", True),
                  "crew.placement": claim("Provisional authored crew locations; exact internal geometry review pending", "text"),
                  "dimensions.width_m": claim(max(row[1] * 2 + g["track_width"] * 2 for row in g["hull_rings"]), "m"),
                  "dimensions.reference_length_m": claim(max(row[3] - row[2] for row in g["hull_rings"]), "m"),
                  "mobility.forward_speed_mps": claim(runtime["forward_max_speed"], "m/s"),
                  "weapon.capacity": claim(capacity, "count", "primary.capacity and ammo_racks.count", True)})
    facts["crew.roles"]["location"] = snapshot.name + ":" + ",".join("L" + str(row["line"]) for row in candidate["crew_roster"])
    facts["weapon.capacity"]["location"] = field_location("primary.capacity")
    facts["reference.heat_carrier_velocity"] = claim(field("shell.muzzle_velocity_mps")["candidate_value"], "m/s", field_location("shell.muzzle_velocity_mps"), True)
    for key, fact in [("geometry", "geometry.exterior"), ("modules", "geometry.modules"), ("crew", "geometry.crew"), ("runtime", "runtime.simulation")]:
        facts[fact] = claim(design[key])
    armor = {}
    for zone, thickness in design["armor_mm"].items():
        facts["armor." + zone] = claim(thickness, "mm")
        armor[zone] = dict(fact="armor." + zone, material="rolled")
        if zone in design["composite_zones"]:
            armor[zone].update(material="composite", response_profile=dict(
                version="wt012-passive-composite-v1", provenance="game_rule", reason=reason,
                coefficients={"kinetic": 1.6 if zone == "turret_front" else 1.2, "chemical": 2.4, "fragment": 1.0}))
            facts["protection.zone." + zone] = claim({"material": "composite", "response_profile": armor[zone]["response_profile"]})
    packet = dict(id=identity, display_name=design["display_name"], license="Original project-authored geometry/rules; reference data use authorized by project owner",
                  evidence_profile="game_reference", admission_status="candidate", historical_verified=False,
                  source_binding={"source_vehicle_id": identity, "primary_source": "reference"}, unit_contract=UNITS,
                  sources=sources, facts=facts, assembly=assembly, compatible_shells=[shell["id"] for shell in shells],
                  geometry=g, modules=design["modules"], crew=design["crew"], armor=armor, runtime=runtime,
                  loading_profile=design["loading_profile"], shell_catalog={"schema_version": 1, "default": shells[0]["id"], "shells": shells},
                  completion={"status": "candidate_only", "remaining": design["remaining"]},
                  reference_trace={"artifact": artifact(candidate_path), "sha256": sha(candidate_path),
                                   "fields": candidate["fields"], "ammo_racks": candidate["ammo_racks"], "crew_roster": candidate["crew_roster"],
                                   "weapon_references": candidate["weapon_references"], "unresolved": candidate["gaps"]})
    facts["loading.profile"] = claim(packet["loading_profile"])
    facts["equipment.loading"] = claim({key: packet["loading_profile"][key] for key in ["mode", "crew_role", "required_module_ids"]})
    for kind in ("drive", "optics", "fire_control"):
        packet[kind + "_profile"] = equipment[kind + "_profile"]
        facts[kind + ".profile"] = claim(packet[kind + "_profile"], refs=["equipment"], location=kind + "_profile")
    facts["equipment.stabilizer"] = claim({"mode": packet["fire_control_profile"]["values"]["stabilizer_mode"], "module_ids": ["stabilizer"]})
    return packet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for identity in IDS:
        output = HERE / f"modern_vehicles/{identity}.json"
        text = json.dumps(build(identity), ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if not output.exists() or output.read_text(encoding="utf-8") != text:
                raise SystemExit("Generated package is stale: " + str(output))
        else:
            output.write_text(text, encoding="utf-8")
        print(("CHECKED " if args.check else "BUILT ") + identity + " (not admitted)")


if __name__ == "__main__":
    main()
