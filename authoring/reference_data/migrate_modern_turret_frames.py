"""One-time, hash-guarded conversion of two frozen packets' world-space turret data.

The GLBs and historic source facts are unchanged. This preserves the authored
proxy shape and taper; it corrects its coordinate frame only, to millimetres.
"""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BEFORE = {
    "ussr_t_80b": "b85fb19ac18bbc85b411b1e98d57f9d98b195869fdddc10957a4fc156f44046b",
    "germ_leopard_2a4": "37f72ca5ac3cb375157d0b8e30861afa3be1eb2e8c91fcb22c969e3c547a703c",
}
SOURCE_ID = "turret_local_frame_20260917"
RECORD = ROOT / "configs/vehicles/evidence/modern_turret_frame_20260917.json"


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def main():
    pending = []
    rows = []
    for vehicle_id, expected in BEFORE.items():
        path = ROOT / f"configs/vehicles/engineering/{vehicle_id}.json"
        raw = path.read_bytes()
        packet = json.loads(raw)
        if SOURCE_ID in packet["sources"]:
            raise SystemExit(f"Already converted: {vehicle_id}; refusing a second translation")
        if hashlib.sha256(raw).hexdigest() != expected:
            raise SystemExit(f"Packet changed: {vehicle_id}; inspect before migration")
        binding = packet["model_binding"]
        model = ROOT / binding["model"]["path"].removeprefix("res://")
        if hashlib.sha256(model.read_bytes()).hexdigest() != binding["model"]["sha256"].lower():
            raise SystemExit(f"Model identity changed: {vehicle_id}")
        geometry = packet["geometry"]
        before = copy.deepcopy(geometry)
        x, y, z = geometry["turret_origin"]
        for key in ["turret_bottom", "turret_top"]:
            geometry[key] = round(geometry[key] - y, 3)
        geometry["turret_outline"] = [[round(px-x, 3), round(pz-z, 3)] for px, pz in geometry["turret_outline"]]
        rows.append(dict(vehicle_id=vehicle_id, original_packet_sha256=expected,
                         model_path=binding["model"]["path"], model_sha256=binding["model"]["sha256"],
                         from_frame="model rest coordinates", to_frame="TurretPivot local",
                         translation=[x,y,z], before=before, after=copy.deepcopy(geometry)))
        pending.append((path, packet))
    record = dict(schema_version=1, origin="game_rule", status="estimated",
                  method="Subtract the model-verified turret origin from the frozen measured turret Y extents and X/Z outline. Existing proxy shape/taper and all armor thicknesses are retained. Historical accuracy remains unverified.",
                  rows=rows)
    payload = encoded(record)
    digest = hashlib.sha256(payload).hexdigest()
    for path, packet in pending:
        packet["sources"][SOURCE_ID] = dict(origin="game_rule", source_vehicle_id=packet["id"],
              applies_to_identity_ids=[packet["id"]], excluded_identity_ids=[], read_state="authored",
              artifact="res://"+RECORD.relative_to(ROOT).as_posix(), sha256=digest)
        fact = packet["facts"]["geometry.exterior"]
        fact["value"] = copy.deepcopy(packet["geometry"])
        fact["source_refs"].append(SOURCE_ID)
        fact["location"] = f"{SOURCE_ID}: rows[vehicle_id={packet['id']}].after"
        fact["note"] = "Measured proxy exterior, with turret coordinates converted from model rest space to TurretPivot local. Engineering estimate; no historical accuracy claim."
    RECORD.parent.mkdir(parents=True, exist_ok=True)
    RECORD.write_bytes(payload)
    for path, packet in pending:
        path.write_bytes(encoded(packet))
        print(f"Converted {packet['id']}: turret Y {packet['geometry']['turret_bottom']}..{packet['geometry']['turret_top']}")


if __name__ == "__main__":
    main()
