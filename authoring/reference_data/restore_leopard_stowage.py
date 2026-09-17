"""Restore existing Leopard stowage/loading/compartment design at delivered anchors."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from restore_t80_loading import anchor_positions

ROOT = Path(__file__).resolve().parents[2]
ID = "germ_leopard_2a4"
SOURCE_ID = "stowage_restoration_20260917"
RUNTIME = ROOT / f"configs/vehicles/engineering/{ID}.json"
AUTHORING = ROOT / f"authoring/reference_data/modern_bound/{ID}.json"
RECORD = ROOT / "configs/vehicles/evidence/leopard_stowage_restoration_20260917.json"
BEFORE = "af5c4066d20ff0fc3b2a592fcf263137546cc384c9fbda15534a893d9306cc0e"
AUTHORED = "1c2fe887ffea08c9f5260b15a55f448489c82f6baf786bd547cd97d992b1c714"


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
    model = packet["model_binding"]["model"]
    assert model == authored["model_binding"]["model"]
    glb = (ROOT / model["path"].removeprefix("res://")).read_bytes()
    assert digest(glb) == model["sha256"].lower()
    positions = anchor_positions(glb)
    additions = [copy.deepcopy(m) for m in authored["modules"] if m["kind"] in ("ammo", "ammo_partition", "blowout_panel")]
    assert {m["id"] for m in additions} == {"ammo_ready", "ammo_reserve", "bustle_partition", "bustle_vent"}
    mounts = authored["model_binding"]["internal_attachments"]["modules"]
    for module in additions:
        path = mounts[module["id"]]
        assert path.rsplit("/", 1)[0] == packet["model_binding"]["nodes"][module["part"]]
        assert len(positions[path]) == len(module["position"]) == 3
        assert max(abs(a-b) for a,b in zip(positions[path], module["position"])) < .0001
        module["position_source"] = "Exact delivered GLB part-local anchor: "+path
    before_modules = copy.deepcopy(packet["modules"])
    assert sum(m.get("ammo_capacity",0) for m in additions) == sum(m.get("ammo_capacity",0) for m in before_modules) == 42
    packet["modules"] = additions+[m for m in packet["modules"] if m["kind"] not in ("ammo", "ammo_partition", "blowout_panel")]
    packet["loading_profile"] = copy.deepcopy(authored["loading_profile"])
    attached = packet["model_binding"]["internal_attachments"]["modules"]
    for module in before_modules:
        if module["kind"] == "ammo": attached.pop(module["id"],None)
    for module in additions: attached[module["id"]] = mounts[module["id"]]
    reason = "Restore the existing authored 15 ready / 27 reserve, explicit manual loading and partition/vent policy at verified GLB anchors. Total 42, shot reload, shell rules, armor and drive parameters unchanged. Game rules, not verified historical pressure simulation."
    claims = {"geometry.modules":packet["modules"], "loading.profile":packet["loading_profile"],
              "equipment.loading":{k:packet["loading_profile"][k] for k in ("mode","crew_role","required_module_ids")},
              "protection.ammo.ammo_ready":next(m["ammo_protection"] for m in additions if m["id"] == "ammo_ready")}
    for key, value in claims.items():
        packet["facts"][key] = dict(value=copy.deepcopy(value), status="estimated", origin="game_rule", unit="structured",
                                    source_refs=packet["facts"].get(key,{}).get("source_refs",[])+[SOURCE_ID],
                                    location=SOURCE_ID+": "+key, note=reason)
    record = dict(schema_version=1, vehicle_id=ID, origin="game_rule", historical_verified=False,
                  before_packet_sha256=BEFORE, authored_path="res://"+AUTHORING.relative_to(ROOT).as_posix(),
                  authored_sha256=AUTHORED, model=model, before_modules=before_modules,
                  after_modules=packet["modules"], after_loading=packet["loading_profile"], reason=reason)
    payload = encode(record)
    packet["sources"][SOURCE_ID] = dict(origin="game_rule", source_vehicle_id=ID, applies_to_identity_ids=[ID],
                                       excluded_identity_ids=[], read_state="authored", artifact="res://"+RECORD.relative_to(ROOT).as_posix(), sha256=digest(payload))
    return packet, payload


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    packet, payload = prepare()
    if args.apply:
        if RECORD.exists(): raise ValueError("Refusing to replace immutable evidence")
        RECORD.write_bytes(payload)
        RUNTIME.write_bytes(encode(packet))
    print(json.dumps({"applied":args.apply,"loading":packet["loading_profile"],"module_ids":[m["id"] for m in packet["modules"]]},indent=2))


if __name__ == "__main__":
    main()
