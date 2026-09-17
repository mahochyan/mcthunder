"""Restore the already-authored T-80B loading policy into its runtime packet.

No new reload/capacity/shape values: use the frozen bound authoring packet and
verify each transferred attachment against the exact delivered GLB. The old
runtime packet remains identifiable in the immutable migration evidence.
"""
import argparse
import copy
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = "ussr_t_80b"
SOURCE_ID = "loading_restoration_20260917"
RUNTIME = ROOT / f"configs/vehicles/engineering/{ID}.json"
AUTHORING = ROOT / f"authoring/reference_data/modern_bound/{ID}.json"
RECORD = ROOT / "configs/vehicles/evidence/t80_loading_restoration_20260917.json"
BEFORE = "97848196d24136273ee6b06ff088294809572a04b372aa91cc3d3176b4f384c6"
AUTHORING_SHA = "b958ea5770ec994f6329c3aa00038a68485ea206f62a4ea9e333779f9b248e79"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2)+"\n").encode("utf-8")


def anchor_positions(raw):
    magic, version, total = struct.unpack_from("<4sII", raw)
    size, kind = struct.unpack_from("<I4s", raw, 12)
    if magic != b"glTF" or version != 2 or total != len(raw) or kind != b"JSON":
        raise ValueError("Unexpected GLB container")
    document = json.loads(raw[20:20+size])
    positions = {}

    def visit(index, parent=""):
        node = document["nodes"][index]
        if not node.get("name"):
            if set(node) != {"children"}:
                raise ValueError("Unnamed transformed/mesh node needs explicit handling")
            for child in node["children"]:
                visit(child, parent)
            return
        path = parent+"/"+node["name"] if parent else node["name"]
        # The transferred T-80B anchors are direct children of the hull. Refuse
        # a transformed parent/anchor instead of approximating its position.
        if path == ID or node["name"].startswith("Attachment_"):
            if "matrix" in node or node.get("rotation", [0, 0, 0, 1]) != [0, 0, 0, 1] or node.get("scale", [1, 1, 1]) != [1, 1, 1]:
                raise ValueError("Transformed attachment requires explicit frame conversion: "+path)
        positions[path] = node.get("translation", [0, 0, 0])
        for child in node.get("children", []):
            visit(child, path)

    for index in document["scenes"][document.get("scene", 0)]["nodes"]:
        visit(index)
    return positions


def prepare():
    raw = RUNTIME.read_bytes()
    authored_raw = AUTHORING.read_bytes()
    if digest(raw) != BEFORE or digest(authored_raw) != AUTHORING_SHA:
        raise ValueError("Source changed or already restored; inspect before migration")
    packet, authored = json.loads(raw), json.loads(authored_raw)
    assert packet["id"] == authored["id"] == ID
    model = packet["model_binding"]["model"]
    glb = (ROOT / model["path"].removeprefix("res://")).read_bytes()
    if digest(glb) != model["sha256"].lower() or authored["model_binding"]["model"] != model:
        raise ValueError("Runtime and authored model identity must match")
    positions = anchor_positions(glb)
    additions = [copy.deepcopy(m) for m in authored["modules"] if m["kind"] in ("ammo", "autoloader")]
    bindings = authored["model_binding"]["internal_attachments"]["modules"]
    for module in additions:
        path = bindings[module["id"]]
        if path.rsplit("/", 1)[0] != packet["model_binding"]["nodes"][module["part"]]:
            raise ValueError("Expected direct part-local attachment: "+path)
        if max(abs(a-b) for a, b in zip(positions[path], module["position"])) > .0001:
            raise ValueError("Authored module does not match delivered anchor: "+path)
        module["position_source"] = "Exact delivered GLB part-local anchor: "+path
    old_ammo = [m for m in packet["modules"] if m["kind"] == "ammo"]
    if sum(m["ammo_capacity"] for m in old_ammo) != sum(m.get("ammo_capacity", 0) for m in additions):
        raise ValueError("This restoration must preserve total ammunition capacity")
    final_modules = additions+[m for m in packet["modules"] if m["kind"] not in ("ammo", "autoloader")]
    record = dict(schema_version=1, vehicle_id=ID, origin="game_rule", historical_verified=False,
                  before_packet_sha256=BEFORE, authored_path="res://"+AUTHORING.relative_to(ROOT).as_posix(),
                  authored_sha256=AUTHORING_SHA, model=model, before_ammo=old_ammo,
                  after_loading=authored["loading_profile"], after_modules=final_modules,
                  transferred_module_ids=[m["id"] for m in additions],
                  reason="Runtime conversion omitted the explicit loading profile and autoloader. Restore the existing 28 ready / 10 reserve game design at verified model anchors; do not infer hardware from crew count. Shot reload, shell values, external armor and total capacity stay unchanged.")
    payload = encoded(record)
    packet["sources"][SOURCE_ID] = dict(origin="game_rule", source_vehicle_id=ID, applies_to_identity_ids=[ID],
                                       excluded_identity_ids=[], read_state="authored", artifact="res://"+RECORD.relative_to(ROOT).as_posix(), sha256=digest(payload))
    packet["modules"] = final_modules
    mounts = packet["model_binding"]["internal_attachments"]["modules"]
    for module in old_ammo:
        mounts.pop(module["id"], None)
    for module in additions:
        mounts[module["id"]] = bindings[module["id"]]
    packet["loading_profile"] = copy.deepcopy(authored["loading_profile"])
    for field, value in {
        "geometry.modules": packet["modules"], "loading.profile": packet["loading_profile"],
        "equipment.loading": {key: packet["loading_profile"][key] for key in ("mode", "crew_role", "required_module_ids")},
    }.items():
        refs = packet["facts"].get(field, {}).get("source_refs", [])+[SOURCE_ID]
        packet["facts"][field] = dict(value=copy.deepcopy(value), status="design", origin="game_rule", source_refs=refs,
                                      location=SOURCE_ID+": "+field, unit="structured", note=record["reason"])
    return packet, payload


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    packet, payload = prepare()
    if args.apply:
        if RECORD.exists():
            raise ValueError("Refusing to replace existing provenance")
        RECORD.write_bytes(payload)
        RUNTIME.write_bytes(encoded(packet))
    print(json.dumps(dict(applied=args.apply, vehicle=ID, loading=packet["loading_profile"],
                          module_ids=[m["id"] for m in packet["modules"]]), indent=2))


if __name__ == "__main__":
    main()
