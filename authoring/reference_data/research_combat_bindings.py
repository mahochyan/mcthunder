"""Bind one exact data row, reviewed preview model, runtime model and combat packet.

This is deliberately strict. A binding is admitted only when all four artifacts use the
same vehicle id and every stored hash matches current project bytes. The generated
research catalog contains the complete provenance chain and never guesses aliases.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TREE = ROOT / "assets/research/soviet_german_tree.json"
INTENT = ROOT / "authoring/reference_data/research_combat_bindings.json"
ENGINEERING = ROOT / "configs/vehicles/engineering"


def _read(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _project_path(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value.startswith("res://"):
        raise ValueError(f"project path must start with res://: {value!r}")
    path = (root / value.removeprefix("res://")).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"project path escapes repository: {value}")
    if not path.is_file():
        raise ValueError(f"project artifact missing: {value}")
    return path


def apply_bindings(catalog: dict, root: Path = ROOT) -> dict:
    intent = _read(root / INTENT.relative_to(ROOT))
    if intent.get("schema_version") != 1 or not isinstance(intent.get("bindings"), list):
        raise ValueError("research combat binding manifest has an unsupported schema")

    rows = catalog.get("vehicles")
    cache_rows = catalog.get("cache_entries")
    if not isinstance(rows, list) or not isinstance(cache_rows, list):
        raise ValueError("research catalog must contain vehicles and cache_entries arrays")
    by_id = {row.get("id"): row for row in rows if isinstance(row, dict)}
    cache = {row.get("id"): row for row in cache_rows if isinstance(row, dict)}
    if len(by_id) != len(rows) or len(cache) != len(cache_rows):
        raise ValueError("research catalog contains missing or duplicate vehicle ids")

    specs: dict[str, dict] = {}
    required_keys = {"vehicle_id", "package_path", "runtime_model_path"}
    for spec in intent["bindings"]:
        if not isinstance(spec, dict) or set(spec) != required_keys:
            raise ValueError("each combat binding must contain only vehicle_id/package_path/runtime_model_path")
        vehicle_id = spec.get("vehicle_id")
        if not isinstance(vehicle_id, str) or vehicle_id in specs:
            raise ValueError(f"missing or duplicate combat binding id: {vehicle_id!r}")
        specs[vehicle_id] = spec

    # Every engineering packet for a technology-tree identity must be listed, and the
    # intent must not name a packet that does not exist. This is the no-extra/no-missing gate.
    packet_ids: set[str] = set()
    for path in sorted((root / ENGINEERING.relative_to(ROOT)).glob("*.json")):
        packet = _read(path)
        vehicle_id = packet.get("id")
        if vehicle_id in by_id:
            if vehicle_id in packet_ids:
                raise ValueError(f"duplicate engineering packet id: {vehicle_id}")
            packet_ids.add(vehicle_id)
    if packet_ids != set(specs):
        raise ValueError(
            "engineering binding set mismatch: "
            f"missing={sorted(packet_ids-set(specs))}, extra={sorted(set(specs)-packet_ids)}"
        )

    for row in rows:
        row["combat_package"] = None
        model = row.get("model")
        if isinstance(model, dict):
            model["combat_admitted"] = False
            row["admission_status"] = "static_preview_only"
        else:
            row["admission_status"] = "awaiting_model"

    for vehicle_id, spec in sorted(specs.items()):
        if vehicle_id not in by_id or vehicle_id not in cache:
            raise ValueError(f"combat binding has no exact research/cache identity: {vehicle_id}")
        row = by_id[vehicle_id]
        preview = row.get("model")
        if not isinstance(preview, dict):
            raise ValueError(f"combat binding has no reviewed preview model: {vehicle_id}")
        preview_path = _project_path(root, preview.get("path"))
        preview_sha = _sha(preview_path)
        if preview.get("sha256") != preview_sha:
            raise ValueError(f"reviewed preview model hash mismatch: {vehicle_id}")

        package_path = _project_path(root, spec["package_path"])
        packet = _read(package_path)
        if packet.get("id") != vehicle_id:
            raise ValueError(f"combat packet id mismatch: {vehicle_id}")
        source_binding = packet.get("source_binding")
        if not isinstance(source_binding, dict) or source_binding.get("source_vehicle_id") != vehicle_id:
            raise ValueError(f"combat packet data identity mismatch: {vehicle_id}")
        model_binding = packet.get("model_binding")
        if not isinstance(model_binding, dict) or model_binding.get("vehicle_id") != vehicle_id:
            raise ValueError(f"combat packet model binding identity mismatch: {vehicle_id}")
        runtime = model_binding.get("model")
        if not isinstance(runtime, dict) or runtime.get("source_vehicle_id") != vehicle_id:
            raise ValueError(f"runtime model source identity mismatch: {vehicle_id}")
        if runtime.get("path") != spec["runtime_model_path"]:
            raise ValueError(f"runtime model path differs from binding intent: {vehicle_id}")
        runtime_path = _project_path(root, spec["runtime_model_path"])
        runtime_sha = _sha(runtime_path)
        if runtime.get("sha256") != runtime_sha:
            raise ValueError(f"runtime model hash mismatch: {vehicle_id}")

        source_sha = cache[vehicle_id].get("source_sha256")
        if row.get("source_sha256") != source_sha:
            raise ValueError(f"research row does not use the exact cache record: {vehicle_id}")
        row["combat_package"] = {
            "vehicle_id": vehicle_id,
            "path": spec["package_path"],
            "sha256": _sha(package_path),
            "evidence_profile": packet.get("evidence_profile"),
            "source_data": {"vehicle_id": vehicle_id, "sha256": source_sha},
            "preview_model": {"path": preview["path"], "sha256": preview_sha},
            "runtime_model": {"path": spec["runtime_model_path"], "sha256": runtime_sha},
        }
        preview["combat_admitted"] = True
        row["admission_status"] = "combat_engineering"

    catalog["alignment"] = {
        "schema_version": 1,
        "binding_manifest": "res://authoring/reference_data/research_combat_bindings.json",
        "data_rows": len(rows),
        "reviewed_models": sum(isinstance(row.get("model"), dict) for row in rows),
        "combat_bindings": len(specs),
        "bound_ids": sorted(specs),
        "set_policy": "exact_id_no_alias_no_missing_no_extra",
    }
    return catalog


def main() -> None:
    from sync_engineering_traverse import sync as sync_engineering_traverse
    sync_engineering_traverse()
    catalog = apply_bindings(_read(TREE))
    TREE.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    from build_research_runtime_profiles import build as build_runtime_profiles
    from build_research_model_interfaces import build as build_model_interfaces
    build_runtime_profiles()
    build_model_interfaces()
    print(json.dumps(catalog["alignment"], ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
