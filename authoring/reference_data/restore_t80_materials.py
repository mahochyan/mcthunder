"""Fill only missing runtime hull materials with the existing authored game policy.

Keep known reference materials, thickness, geometry, ammunition, and raw unknowns.
This is a guarded one-time migration, not an inference about historical protection.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = "ussr_t_80b"
SOURCE_ID = "hull_material_policy_20260917"
RUNTIME = ROOT / f"configs/vehicles/engineering/{ID}.json"
AUTHORING = ROOT / f"authoring/reference_data/modern_bound/{ID}.json"
RECORD = ROOT / "configs/vehicles/evidence/t80_material_restoration_20260917.json"
BEFORE = "3f5e464ac440324d1cb14c9cf76921decf5c5880e5791b5eb1ac1aafacd6c597"
AUTHORED = "b958ea5770ec994f6329c3aa00038a68485ea206f62a4ea9e333779f9b248e79"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encode(data):
    return (json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2)+"\n").encode("utf-8")


def prepare():
    raw, source = RUNTIME.read_bytes(), AUTHORING.read_bytes()
    if digest(raw) != BEFORE or digest(source) != AUTHORED:
        raise ValueError("Changed/already migrated packet; inspect before applying")
    packet, authored = json.loads(raw), json.loads(source)
    assert packet["id"] == authored["id"] == ID
    assert packet["model_binding"]["model"] == authored["model_binding"]["model"]
    model = packet["model_binding"]["model"]
    assert digest((ROOT / model["path"].removeprefix("res://")).read_bytes()) == model["sha256"].lower()
    zones = sorted(k for k, v in packet["armor"].items() if v["material"] == "unknown")
    assert len(zones) == 12 and all(k.startswith("hull_") for k in zones)
    before_armor = copy.deepcopy(packet["armor"])
    for zone in zones:
        policy = {"material": authored["armor"][zone]["material"],
                  "response_profile": copy.deepcopy(authored["armor"][zone].get("response_profile", {}))}
        assert policy["material"] in ("rolled", "cast", "composite")
        packet["armor"][zone].update(policy)
        packet["facts"]["protection.zone."+zone] = dict(
            value=policy, status="estimated", origin="game_rule", unit="structured",
            source_refs=[SOURCE_ID], location=SOURCE_ID+": after_armor."+zone,
            note="Existing authored game material policy at unchanged geometry/thickness. Raw material remains unknown; not historical verification.")
        packet["facts"]["raw.material."+zone] = dict(
            value=None, status="unknown", origin="warthunder_reference", unit="text",
            source_refs=[packet["source_binding"]["primary_source"]],
            location=packet["facts"]["armor."+zone]["location"]+"; no applicable armorClass in hull section",
            note="Original runtime material was unknown. Gameplay policy is separately registered in protection.zone."+zone)
    # Do not blanket-replace the author's different turret/mantlet material choices.
    assert all(packet["armor"][k] == v for k, v in before_armor.items() if k not in zones)
    record = dict(schema_version=1, vehicle_id=ID, origin="game_rule", historical_verified=False,
                  before_packet_sha256=BEFORE, authored_path="res://"+AUTHORING.relative_to(ROOT).as_posix(),
                  authored_sha256=AUTHORED, model=model, source_binding=packet["source_binding"],
                  changed_zones=zones, before_armor=before_armor, after_armor=packet["armor"],
                  reason="Restore only the 12 missing hull materials from the existing game design; preserve all known reference materials, thickness, geometry, shell rules, and raw unknown facts.")
    payload = encode(record)
    packet["sources"][SOURCE_ID] = dict(origin="game_rule", source_vehicle_id=ID,
                                       applies_to_identity_ids=[ID], excluded_identity_ids=[], read_state="authored",
                                       artifact="res://"+RECORD.relative_to(ROOT).as_posix(), sha256=digest(payload))
    return packet, payload


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    packet, payload = prepare()
    if args.apply:
        if RECORD.exists():
            raise ValueError("Refusing to replace immutable evidence")
        RECORD.write_bytes(payload)
        RUNTIME.write_bytes(encode(packet))
    print(json.dumps({"applied": args.apply, "materials": {k:v["material"] for k,v in packet["armor"].items()}}, indent=2))


if __name__ == "__main__":
    main()
