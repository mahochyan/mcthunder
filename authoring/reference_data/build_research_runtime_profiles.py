"""Build compact, runtime-readable research profiles from frozen cache snapshots.

The source summaries are game-reference material, not historical evidence. Only fields
with explicit units are exposed as reference values. Unknown, duplicate and ambiguous
fields retain their resolution state instead of receiving guessed values.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

from import_reference_data import Summary

ROOT = Path(__file__).resolve().parents[2]
TREE = ROOT / "assets/research/soviet_german_tree.json"
INDEX = ROOT / "assets/reference_data/index.json"
TARGET = ROOT / "assets/research/research_runtime_profiles.json"


def _read(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _field(fields: dict[str, dict], key: str) -> dict:
    source = fields[key]
    out = {
        "resolution_state": source["resolution_state"],
        "value": source.get("candidate_value"),
        "source_unit": source.get("source_unit"),
        "unit": source.get("unit"),
        "locator": source.get("locator", []),
        "raw_value": source.get("raw_value", []),
        "origin": "warthunder_reference",
        "historical_verified": False,
    }
    return out


def _armor_card(field: dict) -> dict:
    out = _field({"armor": field}, "armor")
    values = None
    raw = out["value"]
    if isinstance(raw, str):
        pieces = [part.strip() for part in raw.split(",")]
        if pieces and all(re.fullmatch(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)", part) for part in pieces):
            values = [float(part) for part in pieces]
    out["values_mm"] = values
    out["value"] = None
    out["unit"] = "mm"
    return out


def build() -> dict:
    tree = _read(TREE)
    index = _read(INDEX)
    rows = tree.get("vehicles")
    entries = index.get("entries")
    if not isinstance(rows, list) or not isinstance(entries, list):
        raise ValueError("research tree or reference index has no vehicle array")
    by_id = {entry.get("vehicle_id"): entry for entry in entries if isinstance(entry, dict)}
    if len(by_id) != len(entries):
        raise ValueError("reference index contains missing or duplicate vehicle ids")

    profiles = []
    for row in rows:
        vehicle_id = row.get("id")
        if not isinstance(vehicle_id, str) or vehicle_id not in by_id:
            raise ValueError(f"tree identity has no exact reference entry: {vehicle_id!r}")
        entry = by_id[vehicle_id]
        snapshot = ROOT / "assets/reference_data" / entry["snapshot"]
        digest = _sha(snapshot)
        if digest != entry.get("sha256") or digest != row.get("source_sha256"):
            raise ValueError(f"source snapshot hash mismatch: {vehicle_id}")
        parsed = Summary(snapshot.read_bytes(), vehicle_id).detailed()
        fields = {item["key"]: item for item in parsed["fields"]}
        crew = parsed["crew_roster"]
        profile = {
            "id": vehicle_id,
            "nation": row.get("nation"),
            "source": {
                "origin": "warthunder_reference",
                "resource_version": entry.get("resource_version"),
                "snapshot": "res://assets/reference_data/" + entry["snapshot"],
                "sha256": digest,
                "historical_verified": False,
            },
            "mobility": {
                "forward_max_mps": _field(fields, "drive.forward_speed_candidate"),
                "reverse_max_mps": _field(fields, "drive.reverse_speed_candidate"),
                "hull_turn_deg_s": _field(fields, "drive.hull_turn_candidate"),
                "design_mass_kg": _field(fields, "drive.design_mass"),
                "trial_acceleration_mps2": {
                    "resolution_state": "project_design_fallback",
                    "value": 4.0,
                    "unit": "m/s2",
                    "origin": "mcthunder_design",
                    "reason": "cache acceleration units/semantics are unresolved; no historical claim",
                },
            },
            "primary_weapon": {
                "caliber_mm": _field(fields, "shell.caliber_mm"),
                "muzzle_velocity_mps": _field(fields, "shell.muzzle_velocity_mps"),
                "capacity_rounds": _field(fields, "primary.capacity"),
                "traverse_deg_s": _field(fields, "primary.traverse"),
            },
            "armor_cards": {
                "hull": _armor_card(fields["armor.card_hull"]),
                "turret": _armor_card(fields["armor.card_turret"]),
                "runtime_admitted": False,
                "reason": "card values do not define local plate geometry or material layers",
            },
            "crew": {
                "resolution_state": "explicit_roster_candidate" if crew else "missing",
                "count": len(crew) if crew else None,
                "stations": [item["station"] for item in crew],
                "geometry": None,
                "runtime_admitted": False,
            },
            "optics": {"raw_ir": _field(fields, "optics.raw_ir"), "runtime_admitted": False},
            "runtime_use": {
                "research_trial_mobility": row.get("model") is not None,
                "combat": row.get("combat_package") is not None,
            },
        }
        profiles.append(profile)

    result = {
        "schema_version": 1,
        "origin": "warthunder_reference",
        "historical_verified": False,
        "set_policy": "exact_tree_id_no_alias_no_missing_no_extra",
        "vehicle_count": len(profiles),
        "trial_mobility_count": sum(p["runtime_use"]["research_trial_mobility"] for p in profiles),
        "combat_count": sum(p["runtime_use"]["combat"] for p in profiles),
        "profiles": profiles,
    }
    encoded = (json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False) + "\n").encode("utf-8")
    if not TARGET.exists() or TARGET.read_bytes() != encoded:
        TARGET.write_bytes(encoded)
    print(json.dumps({key: result[key] for key in ("vehicle_count", "trial_mobility_count", "combat_count", "set_policy")}, ensure_ascii=False, sort_keys=True))
    return result


if __name__ == "__main__":
    build()
