"""Inspect the exact runtime GLB selected for every modeled research-tree vehicle."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
TREE = ROOT / "assets/research/soviet_german_tree.json"
TARGET = ROOT / "assets/research/research_model_interfaces.json"


def _read(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _project_path(value: str) -> Path:
    if not isinstance(value, str) or not value.startswith("res://"):
        raise ValueError(f"model path must be project-local: {value!r}")
    path = (ROOT / value.removeprefix("res://")).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError(f"model path missing or outside project: {value}")
    return path


def _glb(path: Path) -> dict:
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError(f"truncated GLB: {path}")
    magic, version, length = struct.unpack_from("<III", raw)
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    if (magic, version, length, json_type) != (0x46546C67, 2, len(raw), 0x4E4F534A):
        raise ValueError(f"invalid GLB header: {path}")
    return json.loads(raw[20:20 + json_length].decode("utf-8").rstrip("\x00 "))


def _is_descendant(child: int, ancestor: int, parents: dict[int, int]) -> bool:
    cursor = child
    while cursor in parents:
        cursor = parents[cursor]
        if cursor == ancestor:
            return True
    return False


def build() -> dict:
    tree = _read(TREE)
    rows = tree.get("vehicles")
    if not isinstance(rows, list):
        raise ValueError("research tree has no vehicles array")
    interfaces = []
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("model"), dict):
            continue
        vehicle_id = row.get("id")
        selected = row["model"]
        source_kind = "reviewed_preview_model"
        if isinstance(row.get("combat_package"), dict):
            selected = row["combat_package"].get("runtime_model")
            source_kind = "combat_runtime_model"
        if not isinstance(selected, dict):
            raise ValueError(f"selected model record is malformed: {vehicle_id}")
        path = _project_path(selected.get("path"))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != selected.get("sha256"):
            raise ValueError(f"selected model hash mismatch: {vehicle_id}")
        gltf = _glb(path)
        nodes = gltf.get("nodes")
        scenes = gltf.get("scenes")
        if not isinstance(nodes, list) or not isinstance(scenes, list) or not scenes:
            raise ValueError(f"GLB scene graph missing: {vehicle_id}")
        names: dict[str, list[int]] = {}
        parents: dict[int, int] = {}
        for index, node in enumerate(nodes):
            if not isinstance(node, dict):
                raise ValueError(f"malformed GLB node: {vehicle_id}/{index}")
            name = node.get("name")
            if isinstance(name, str) and name:
                names.setdefault(name, []).append(index)
            for child in node.get("children", []):
                if child in parents:
                    raise ValueError(f"GLB node has multiple parents: {vehicle_id}/{child}")
                parents[child] = index

        def unique(name: str) -> int:
            matches = names.get(name, [])
            if len(matches) != 1:
                raise ValueError(f"required unique node {name!r} occurs {len(matches)} times: {vehicle_id}")
            return matches[0]

        def optional_unique(name: str) -> int | None:
            matches = names.get(name, [])
            if len(matches) > 1:
                raise ValueError(f"optional node {name!r} is ambiguous ({len(matches)}): {vehicle_id}")
            return matches[0] if matches else None

        hull = unique("HullArmour")
        turret = optional_unique("TurretPivot")
        gun = optional_unique("GunPivot")
        gun_names = sorted(name for name in names if name.startswith("MainGun"))
        if any(len(names[name]) != 1 for name in gun_names):
            raise ValueError(f"main-gun mesh name is ambiguous: {vehicle_id}")
        main_gun = names[gun_names[0]][0] if len(gun_names) == 1 else None
        if turret is not None and _is_descendant(hull, turret, parents):
            raise ValueError(f"hull is incorrectly parented below turret: {vehicle_id}")
        if turret is not None and gun is not None and main_gun is not None:
            if not _is_descendant(gun, turret, parents):
                raise ValueError(f"GunPivot is not below TurretPivot: {vehicle_id}")
            if not _is_descendant(main_gun, gun, parents):
                raise ValueError(f"main gun is not below GunPivot: {vehicle_id}")
            weapon_control = "yaw_pitch"
            weapon_reason = None
        else:
            weapon_markers = [name for name in names if any(token in name.lower() for token in ("missile", "launcher", "maingun"))]
            weapon_control = "unavailable_nonstandard" if weapon_markers else "none"
            weapon_reason = "nonstandard_weapon_nodes_require_explicit_adapter" if weapon_markers else "model_has_no_controllable_weapon"
        left_track = names.get("track_l", [])
        right_track = names.get("track_r", [])
        left_wheels = sorted(name for name in names if name.lower().startswith("wheel_l_"))
        right_wheels = sorted(name for name in names if name.lower().startswith("wheel_r_"))
        wheel_assemblies = sorted(name for name in names if "wheels" in name.lower() and ("suspension" in name.lower() or "axles" in name.lower()))
        wheel_assembly = None
        if len(left_track) == len(right_track) == 1:
            locomotion = "tracked"
        elif not left_track and not right_track and len(left_wheels) >= 2 and len(right_wheels) >= 2:
            locomotion = "wheeled"
        elif not left_track and not right_track and not left_wheels and not right_wheels and len(wheel_assemblies) == 1:
            locomotion = "wheeled"
            wheel_assembly = wheel_assemblies[0]
        else:
            raise ValueError(f"left/right locomotion nodes do not form an exact pair: {vehicle_id}")
        muzzle = names.get("Muzzle", [])
        weapon_rig_ready = weapon_control == "yaw_pitch"
        combat_interface = source_kind == "combat_runtime_model" and weapon_rig_ready and len(muzzle) == 1
        interfaces.append({
            "id": vehicle_id,
            "model": {"path": selected["path"], "sha256": digest, "source_kind": source_kind},
            "scene": {"node_count": len(nodes), "mesh_count": len(gltf.get("meshes", []))},
            "nodes": {
                "hull": "HullArmour",
                "turret_pivot": "TurretPivot" if turret is not None else None,
                "gun_pivot": "GunPivot" if gun is not None else None,
                "main_gun": gun_names[0] if len(gun_names) == 1 else None,
                "muzzle": "Muzzle" if len(muzzle) == 1 else None,
                "left_track": "track_l" if locomotion == "tracked" else None,
                "right_track": "track_r" if locomotion == "tracked" else None,
                "left_wheels": left_wheels,
                "right_wheels": right_wheels,
                "wheel_assembly": wheel_assembly,
            },
            "locomotion": locomotion,
            "weapon_control": weapon_control,
            "weapon_unavailable_reason": weapon_reason,
            "trial_rig_ready": True,
            "weapon_rig_ready": weapon_rig_ready,
            "combat_interface_ready": combat_interface,
        })

    result = {
        "schema_version": 2,
        "set_policy": "exact_modeled_tree_id_no_alias_no_missing_no_extra",
        "model_count": len(interfaces),
        "tracked_count": sum(row["locomotion"] == "tracked" for row in interfaces),
        "wheeled_count": sum(row["locomotion"] == "wheeled" for row in interfaces),
        "trial_rig_ready_count": sum(row["trial_rig_ready"] for row in interfaces),
        "weapon_rig_ready_count": sum(row["weapon_rig_ready"] for row in interfaces),
        "nonstandard_weapon_count": sum(row["weapon_control"] == "unavailable_nonstandard" for row in interfaces),
        "unarmed_count": sum(row["weapon_control"] == "none" for row in interfaces),
        "combat_interface_ready_count": sum(row["combat_interface_ready"] for row in interfaces),
        "interfaces": interfaces,
    }
    encoded = (json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False) + "\n").encode("utf-8")
    if not TARGET.exists() or TARGET.read_bytes() != encoded:
        TARGET.write_bytes(encoded)
    print(json.dumps({key: result[key] for key in ("model_count", "tracked_count", "wheeled_count", "trial_rig_ready_count", "weapon_rig_ready_count", "nonstandard_weapon_count", "unarmed_count", "combat_interface_ready_count")}, sort_keys=True))
    return result


if __name__ == "__main__":
    build()
