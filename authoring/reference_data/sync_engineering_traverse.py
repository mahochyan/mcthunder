"""Copy source-backed turret traverse rates into the admitted engineering packets."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IDS = ("ussr_t_80b", "germ_leopard_2a4")


def read(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sync() -> None:
    for vehicle_id in IDS:
        authored_path = ROOT / f"authoring/reference_data/modern_vehicles/{vehicle_id}.json"
        runtime_path = ROOT / f"configs/vehicles/engineering/{vehicle_id}.json"
        authored = read(authored_path)
        runtime = read(runtime_path)
        if authored.get("id") != vehicle_id or runtime.get("id") != vehicle_id:
            raise ValueError(f"package identity mismatch: {vehicle_id}")
        snapshot = ROOT / f"assets/reference_data/source_snapshots/{vehicle_id}.txt"
        if not snapshot.is_file():
            raise ValueError(f"reference snapshot missing: {vehicle_id}")
        source_hash = sha(snapshot)
        authored_reference = authored.get("sources", {}).get("reference", {})
        runtime_source_id = runtime.get("source_binding", {}).get("primary_source")
        runtime_reference = runtime.get("sources", {}).get(runtime_source_id, {})
        if authored_reference.get("sha256") != source_hash or runtime_reference.get("sha256") != source_hash:
            raise ValueError(f"packet reference hash mismatch: {vehicle_id}")
        authored_tuning = authored.get("arcade_tuning")
        if authored.get("gameplay_mode") != "arcade" or not isinstance(authored_tuning, dict):
            raise ValueError(f"authored arcade tuning missing: {vehicle_id}")
        multiplier = authored_tuning.get("arcade_power_multiplier_applied")
        if not isinstance(multiplier, (int, float)) or multiplier <= 0:
            raise ValueError(f"authored arcade multiplier invalid: {vehicle_id}")
        existing_tuning = runtime.get("arcade_tuning")
        base_acceleration = (
            existing_tuning.get("base_acceleration_mps2")
            if isinstance(existing_tuning, dict)
            else runtime.get("runtime", {}).get("acceleration")
        )
        if not isinstance(base_acceleration, (int, float)) or base_acceleration <= 0:
            raise ValueError(f"runtime base acceleration invalid: {vehicle_id}")
        runtime["gameplay_mode"] = "arcade"
        runtime["arcade_tuning"] = copy.deepcopy(authored_tuning)
        runtime["arcade_tuning"]["base_acceleration_mps2"] = float(base_acceleration)
        runtime["runtime"]["acceleration"] = float(base_acceleration) * float(multiplier)
        runtime["facts"]["gameplay.ruleset"] = {
            "value": {"mode": "arcade", "tuning": copy.deepcopy(runtime["arcade_tuning"])},
            "status": "design",
            "origin": "game_rule",
            "source_refs": ["mcthunder_pipeline"],
            "location": "arcade runtime binding; source field drive.arcade_power_multiplier remains in the frozen candidate trace",
            "unit": "structured",
            "note": runtime["arcade_tuning"]["note"],
        }
        for key in ("turret_yaw_speed", "turret_pitch_speed"):
            value = authored["runtime"][key]
            fact_key = "runtime." + key
            fact = authored["facts"][fact_key]
            if not isinstance(value, (int, float)) or value <= 0 or fact.get("value") != value:
                raise ValueError(f"authored traverse value/fact mismatch: {vehicle_id}/{key}")
            runtime["runtime"][key] = value
            runtime_fact = copy.deepcopy(fact)
            runtime_fact["source_refs"] = [runtime_source_id]
            runtime["facts"][fact_key] = runtime_fact
        runtime["facts"]["runtime.simulation"]["value"] = copy.deepcopy(runtime["runtime"])
        runtime_path.write_text(json.dumps(runtime, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(vehicle_id, runtime["runtime"]["turret_yaw_speed"], runtime["runtime"]["turret_pitch_speed"])


if __name__ == "__main__":
    sync()
