"""Read-only external reference ingestion; generated data NEVER admits combat vehicles.

Python standard library only. TXT is a lossy game-reference summary, not historical
evidence or a complete inherited vehicle definition. Paths/IDs are not fuzzy matched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

SCHEMA = 1
NATIONS = ("USSR_苏联", "Germany_德国")
DEEP_IDS = ("ussr_t_80b", "germ_leopard_2a4")
IDENTIFIER = re.compile(r"^[A-Za-z0-9_-]+$")
NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)"
REPOSITORY = Path(__file__).resolve().parents[2]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True,
                       allow_nan=False) + "\n").encode("utf-8")


def write_changed(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def raw_atom(raw: str) -> object:
    if raw == "是":
        return True
    if raw == "否":
        return False
    if not raw.strip():
        return None
    if re.fullmatch(NUMBER, raw):
        value = float(raw)
        return int(value) if value.is_integer() else value
    return raw


class Summary:
    def __init__(self, data: bytes, expected_id: str):
        if not IDENTIFIER.fullmatch(expected_id):
            raise ValueError("invalid expected vehicle ID")
        self.text = data.decode("utf-8-sig")
        self.lines = self.text.splitlines()
        self.fields: list[dict] = []
        self.rows: list[dict] = []
        section, group = "header", ""
        for number, line in enumerate(self.lines, 1):
            clean = line.strip()
            title = re.fullmatch(r"【(.+)】", clean)
            if title:
                section, group = title[1], ""
                continue
            heading = re.match(r"\[([^]]+)\]", clean)
            if heading:
                group = heading[1]
            row = {"line": number, "section": section, "group": group, "text": line}
            self.rows.append(row)
            field = re.match(r"\s*([^:：]+?)\s*[:：]\s*(.*?)\s*$", line)
            if field and not clean.startswith("战争雷霆"):
                self.fields.append({**row, "name": field[1].strip(), "raw": field[2]})
        identities = self.select("载具 ID")
        if len(identities) != 1 or identities[0]["raw"] != expected_id:
            raise ValueError("filename/declared vehicle ID mismatch or duplicate identity")
        self.id = expected_id
        versions = re.findall(r"资源版本\s+([0-9.]+)", self.text)
        self.version = versions[0] if len(set(versions)) == 1 else None
        self.source = {"vehicle_id": expected_id, "sha256": sha256(data),
                       "resource_version": self.version, "origin": "warthunder_reference",
                       "historical_verified": False, "format": "lossy_text_summary"}

    def select(self, name: str, section: str | None = None,
               group: str | None = None) -> list[dict]:
        return [r for r in self.fields if r["name"] == name
                and (section is None or section in r["section"])
                and (group is None or group == r["group"])]

    def value(self, name: str) -> str | None:
        rows = self.select(name)
        return rows[0]["raw"] if len(rows) == 1 else None

    def field(self, key: str, name: str, *, section: str | None = None,
              group: str | None = None, source_unit: str | None = None,
              unit: str | None = None, factor: float = 1.0,
              suffix: str | None = None, numeric: bool = False,
              note: str = "") -> dict:
        rows = self.select(name, section, group)
        result = {"key": key, "origin": "warthunder_reference", "historical_verified": False,
                  "locator": [{"line": r["line"], "section": r["section"], "group": r["group"]}
                              for r in rows], "raw_value": [r["raw"] for r in rows],
                  "source_unit": source_unit, "unit": unit, "candidate_value": None,
                  "resolution_state": "missing", "runtime_admitted": False, "note": note}
        duplicate_consistent = len(rows) > 1 and len({row["raw"] for row in rows}) == 1
        if len(rows) > 1 and not duplicate_consistent:
            result["resolution_state"] = "conflict_duplicate_field"
        elif rows and not rows[0]["raw"].strip():
            result["resolution_state"] = "unresolved_empty"
        elif rows:
            raw = rows[0]["raw"]
            if numeric:
                match = re.fullmatch(rf"({NUMBER})\s*{re.escape(suffix or '')}", raw)
                if not match:
                    result["resolution_state"] = "unresolved_unit_or_format"
                    return result
                number = float(match[1]) * factor
                if not math.isfinite(number):
                    result["resolution_state"] = "unresolved_nonfinite"
                    return result
                result["candidate_value"] = number
            else:
                result["candidate_value"] = raw
            result["resolution_state"] = "explicit_reference_duplicate_consistent" if duplicate_consistent else "explicit_reference_candidate"
        return result

    def armor_nodes(self) -> list[dict]:
        """Retain group defaults and local overrides; presence/geometry unresolved."""
        groups: dict[str, dict] = {}
        for row in self.rows:
            if "复合与附加" not in row["section"] or not row["group"]:
                continue
            group = groups.setdefault(row["group"], {"id": row["group"], "defaults": {}, "nodes": []})
            clean = row["text"].strip()
            default = re.match(r"节属性\s+(\w+)\s*=\s*(.*)", clean)
            if default:
                group["defaults"][default[1]] = {"raw_value": default[2],
                    "candidate_value": raw_atom(default[2]), "line": row["line"]}
                continue
            node = re.match(r"([\w]+)\s+(.*)", clean)
            if not node or not (node[1].endswith("_dm") or node[1] == "timber"):
                continue
            explicit = {m[1]: {"raw_value": m[2], "candidate_value": raw_atom(m[2]),
                               "line": row["line"]}
                        for m in re.finditer(r"(\w+)=([^\s]+)", node[2])}
            # Defaults are material/parameter candidates, never proof of active mesh presence.
            resolved = {k: {**v, "resolution_state": "group_inherited_candidate"}
                        for k, v in group["defaults"].items()}
            resolved.update({k: {**v, "resolution_state": "explicit_reference_candidate"}
                             for k, v in explicit.items()})
            group["nodes"].append({"id": node[1], "line": row["line"], "raw_value": clean,
                "properties": resolved, "presence": "unresolved_requires_active_geometry",
                "geometry": None, "runtime_admitted": False})
        return list(groups.values())

    def crew(self) -> list[dict]:
        output = []
        for row in self.rows:
            if row["section"] != "乘员岗位与替补":
                continue
            match = re.match(r"(\w+)\s+模块=(\w+)\s+角色=(.*?)\s+替补自=(.*)", row["text"].strip())
            if match:
                output.append({"station": match[1], "module_reference": match[2],
                    "roles": [v.strip() for v in match[3].split(",") if v.strip()],
                    "replacement_from": [v.strip() for v in match[4].split(",") if v.strip()],
                    "line": row["line"], "raw_value": row["text"].strip(),
                    "resolution_state": "explicit_roster_candidate", "geometry": None})
        return output

    def racks(self) -> list[dict]:
        output, weapon, current = [], None, None
        for row in self.rows:
            if row["section"] != "弹药架与补弹":
                continue
            clean = row["text"].strip()
            header = re.match(r"\[([^]]+)\] 武器=(\w+)\s+补弹时间=([\d.]+)s\s+补弹延迟=([\d.]+)s\s+取出已装填=(.*)", clean)
            if header:
                weapon = {"group": header[1], "weapon_trigger": header[2],
                    "replenish_seconds": float(header[3]), "replenish_delay_seconds": float(header[4]),
                    "remove_loaded_candidate": raw_atom(header[5]), "line": row["line"],
                    "raw_value": clean, "unit": "s", "shot_reload_seconds": None}
                continue
            flags = re.match(r"弹组 首发=(.*?) 起火预设=(.*?) 致命起火=(.*?) 致命殉爆=(.*)", clean)
            if flags:
                current = {"supply": weapon, "flags": {}, "count": None, "slots": None,
                           "geometry": None, "resolution_state": "partial_reference_candidate"}
                for key, raw in zip(("ready_rack", "fire_preset", "lethal_fire", "lethal_detonation"), flags.groups()):
                    current["flags"][key] = {"raw_value": raw, "candidate_value": raw_atom(raw),
                        "line": row["line"], "resolution_state": "explicit_reference_candidate" if raw else "unresolved_empty"}
                output.append(current)
            count = re.match(r"弹格 (\d+) 个，合计 (\d+) 发", clean)
            if count and current is not None:
                current.update(slots=int(count[1]), count=int(count[2]), count_line=row["line"])
        return output

    def detailed(self) -> dict:
        fields = []
        for key, label, suffix, unit, factor in (
            ("drive.forward_speed_candidate", "前进极速", "km/h", "m/s", 1 / 3.6),
            ("drive.reverse_speed_candidate", "倒车极速", "km/h", "m/s", 1 / 3.6),
            ("drive.hull_turn_candidate", "最大车体转速", "°/s", "deg/s", 1),
            ("drive.design_mass", "质量（设计）", "kg", "kg", 1),
        ):
            fields.append(self.field(key, label, section="总体", numeric=True, suffix=suffix,
                source_unit=suffix, unit=unit, factor=factor,
                note="Reference summary only; mode, inheritance and physical interpretation require confirmation."))
        for key, label in (("drive.mass_variants", "物理质量"), ("drive.engine", "发动机"),
                           ("drive.rpm", "转速"), ("drive.arcade_power_multiplier", "街机功率倍率"),
                           ("drive.acceleration_unspecified_units", "加减速度"),
                           ("drive.inertia_unspecified_units", "转动惯量"),
                           ("identity.game_release_date", "首发日期")):
            fields.append(self.field(key, label, section="总体" if key.startswith("drive.") else "header",
                note="Do not infer units, historical year, absent multipliers or mass summation."))
        for key, label, unit, factor in (
            ("shell.caliber_mm", "caliber", "mm", 1000),
            ("shell.muzzle_velocity_mps", "speed", "m/s", 1),
            ("shell.mass_kg", "mass", "kg", 1),
            ("shell.max_distance_m", "maxDistance", "m", 1),
            ("shell.explosive_mass_kg", "explosiveMass", "kg", 1),
        ):
            fields.append(self.field(key, label, group="primary", numeric=True,
                source_unit="m" if label == "caliber" else unit, unit=unit, factor=factor,
                note="Projectile source convention; candidate only, not an admitted shell definition."))
        for label in ("bulletName", "bulletType", "explosiveType", "Cx", "hitPower", "stabilityThreshold",
                      "normalizationPreset", "ricochetPreset", "secondaryShattersPreset", "fuseDelayDist", "explodeTreshold"):
            fields.append(self.field("shell.reference." + label, label, group="primary",
                note="Opaque source parameter/preset. hitPower is not penetration_mm; stabilityThreshold is not a gun stabilizer."))
        fields.append(self.field("primary.capacity", "备弹", group="primary", numeric=True,
                                 suffix="发", source_unit="rounds", unit="rounds"))
        traverse = self.field("primary.traverse", "转速", group="primary", source_unit="deg/s", unit="deg/s")
        if traverse["candidate_value"] is not None:
            match = re.fullmatch(rf"yaw ({NUMBER}) °/s, pitch ({NUMBER}) °/s", traverse["candidate_value"])
            traverse["candidate_value"] = {"yaw": float(match[1]), "pitch": float(match[2])} if match else None
            if not match:
                traverse["resolution_state"] = "unresolved_unit_or_format"
        fields.append(traverse)
        fields.append(self.field("armor.card_hull", "armorThicknessHull", note="Card summary; never override local layered armor."))
        fields.append(self.field("armor.card_turret", "armorThicknessTurret", note="Card summary; never override local layered armor."))
        optics = self.field("optics.raw_ir", "夜视/热成像", note="IR is not automatically thermal; missing fields may be inherited; upgrade names do not specify capability.")
        if optics["candidate_value"] is not None:
            try:
                optics["candidate_value"] = json.loads(optics["candidate_value"])
            except (ValueError, TypeError):
                optics["candidate_value"] = None
                optics["resolution_state"] = "unresolved_invalid_json"
        fields.append(optics)
        fields.append(self.field("equipment.modification_references", "改装项", note="Inventory of references, not proof modifications are installed or implemented."))
        for field in fields:
            structured = {
                "drive.engine": (rf"(.+?) / ({NUMBER}) hp", ("engine_id", "power_hp"), "hp"),
                "drive.rpm": (rf"怠速 ({NUMBER}) / 额定 ({NUMBER}) RPM", ("idle", "rated"), "RPM"),
                "drive.mass_variants": (rf"空车 ({NUMBER}) kg / 含油 ({NUMBER}) kg（油 ({NUMBER}) kg，履带 ({NUMBER}) kg）", ("empty", "fueled", "fuel", "tracks"), "kg"),
            }
            if field["key"] in structured and field["candidate_value"] is not None:
                pattern, keys, unit = structured[field["key"]]
                match = re.fullmatch(pattern, field["candidate_value"])
                field["source_unit"] = unit
                field["unit"] = unit
                field["candidate_value"] = {key: raw_atom(value) for key, value in zip(keys, match.groups())} if match else None
                if not match:
                    field["resolution_state"] = "unresolved_unit_or_format"
            if field["key"] in ("drive.acceleration_unspecified_units", "drive.inertia_unspecified_units") and field["candidate_value"] is not None:
                field["candidate_value"] = None
                field["resolution_state"] = "unresolved_units_and_semantics"
            if field["key"] == "drive.arcade_power_multiplier" and field["candidate_value"] is not None:
                match = re.fullmatch(rf"×({NUMBER})", field["candidate_value"])
                field["candidate_value"] = float(match[1]) if match else None
                if not match:
                    field["resolution_state"] = "unresolved_empty"
        truncations = [{"line": r["line"], "raw_value": r["text"].strip()} for r in self.rows
                       if "其余" in r["text"] and "略" in r["text"]]
        gaps = [
            {"id": "lossy_summary", "detail": "Defaults/includes, modes and modification application are not fully resolved."},
            {"id": "active_geometry", "detail": "Generic module lists are not active crew/equipment. Positions, sizes, transforms and armor layer ordering require an authored geometry map."},
            {"id": "ballistics_and_materials", "detail": "No complete penetration curve, equivalent armor or preset definitions; existing engine lacks these modern effects. Never use hitPower as penetration."},
            {"id": "fire_control", "detail": "Shot reload time, pitch limits, stabilizer and sight FOV/offset/rangefinder behavior are missing; rack replenishment is not reload."},
            {"id": "equipment_resolution", "detail": "IR versus thermal, installed upgrades and autoloader presence require explicit resolution; dummy_weapon cannot fire."},
            {"id": "historical_evidence", "detail": "All source data remains warthunder_reference; game release date is not historical variant year."},
        ]
        if truncations:
            gaps.append({"id": "truncated_sections", "detail": "Some module entries were omitted by the source exporter.", "evidence": truncations})
        if self.version is None:
            gaps.append({"id": "source_version_unresolved", "detail": "Missing or conflicting resource versions."})
        modules, weapons = [], []
        for row in self.rows:
            clean = row["text"].strip()
            if "模块 / 内构" in row["section"]:
                node = re.match(r"(\w+_dm)\s+(.*)", clean)
                if node:
                    modules.append({"id": node[1], "group": row["group"], "line": row["line"],
                                    "raw_value": clean, "presence": "unresolved_generic_reference",
                                    "geometry": None, "runtime_admitted": False})
            if row["section"] == "武器与弹药":
                heading = re.match(r"\[([^]]+)\]\s+(\w+)", clean)
                if heading:
                    weapons.append({"slot": heading[1], "source_weapon_id": heading[2],
                                    "line": row["line"], "raw_value": clean,
                                    "kind": "dummy_reference_only" if heading[2] == "dummy_weapon" else "weapon_reference",
                                    "runtime_admitted": False})
        return {"schema": SCHEMA, "id": self.id, "source": self.source,
                "admission": "candidate_only", "combat_definition": None, "historical_verified": False,
                "fields": fields, "raw_fields": self.fields, "armor_groups": self.armor_nodes(),
                "crew_roster": self.crew(), "ammo_racks": self.racks(),
                "damage_module_references": modules, "weapon_references": weapons, "gaps": gaps}


def model_index(root: Path) -> dict:
    """Snapshot exact-ID report associations; never select/copy/publish a model."""
    models, rejected = [], []
    for report in sorted(root.rglob("build_report.json"), key=lambda p: p.as_posix()):
        data = report.read_bytes()
        try:
            value = json.loads(data)
            model_id = value.get("id")
            if not isinstance(model_id, str) or not IDENTIFIER.fullmatch(model_id):
                raise ValueError("missing/invalid exact report ID")
            if model_id not in report.relative_to(root).parts:
                raise ValueError("declared ID has no exact directory match")
            glb = report.parent / "vehicle.glb"
            models.append({"id": model_id, "report_path": report.as_posix(), "report_sha256": sha256(data),
                "declared_status": value.get("status", "unspecified"), "admission": "candidate_only",
                "glb_path": glb.as_posix() if glb.is_file() else None,
                "glb_sha256": sha256(glb.read_bytes()) if glb.is_file() else None,
                "triangles_reported": value.get("triangles"), "published": False})
        except (ValueError, TypeError, AttributeError) as error:
            rejected.append({"report_path": report.as_posix(), "report_sha256": sha256(data), "reason": str(error)})
    return {"schema": SCHEMA, "root": root.as_posix(), "matching": "exact_report_id_and_directory_component",
            "models": models, "rejected": rejected, "selected_for_publication": []}


def import_all(cache_root: Path, model_root: Path, output: Path, deep_ids=DEEP_IDS) -> dict:
    cache_root, model_root, output = cache_root.resolve(), model_root.resolve(), output.resolve()
    # API fixture callers may use arbitrary output, but neither CLI nor API can write into a source tree.
    if output == cache_root or cache_root in output.parents or output == model_root or model_root in output.parents:
        raise ValueError("output must not be within either read-only source tree")
    if not cache_root.is_dir() or not model_root.is_dir():
        raise ValueError("both read-only source roots must exist")
    for nation in NATIONS:
        if not (cache_root / nation).is_dir():
            raise ValueError("required nation directory missing: " + nation)
    models = model_index(model_root)
    rows, errors, deep = [], [], {}
    sources_seen, snapshot_bytes = {}, {}
    for nation in NATIONS:
        for path in sorted((cache_root / nation).glob("*.txt"), key=lambda p: p.name):
            data = path.read_bytes()
            try:
                summary = Summary(data, path.stem)
                if summary.id in sources_seen:
                    raise ValueError("duplicate exact ID across nation directories")
                sources_seen[summary.id] = path
                links = [m for m in models["models"] if m["id"] == summary.id]
                row = {**summary.source, "nation_directory": nation, "source_path": path.as_posix(),
                       "snapshot": "source_snapshots/" + path.name,
                       "model_name": summary.value("模型名"), "admission": "candidate_only",
                       "model_report_paths": [m["report_path"] for m in links],
                       "model_link_state": "exact_candidates_unselected" if links else "no_exact_candidate",
                       "deep_candidate": "candidates/" + summary.id + ".json" if summary.id in deep_ids else None}
                rows.append(row)
                snapshot_bytes[row["snapshot"]] = data
                if summary.id in deep_ids:
                    deep[summary.id] = summary.detailed()
                    deep[summary.id]["source"].update(source_path=path.as_posix(), snapshot=row["snapshot"])
                    deep[summary.id]["model_candidates"] = links
            except (ValueError, UnicodeError) as error:
                errors.append({"source_path": path.as_posix(), "sha256": sha256(data), "reason": str(error)})
    missing = sorted(set(deep_ids) - set(deep))
    if missing:
        raise ValueError("required deep candidate IDs missing or rejected: " + ", ".join(missing))
    # Only after reading/validating the complete batch do any generated files change.
    write_changed(output / ".gdignore", b"")
    for row in rows:
        write_changed(output / row["snapshot"], snapshot_bytes[row["snapshot"]])
    write_changed(output / "model_candidates.json", json_bytes(models))
    for model_id, candidate in deep.items():
        write_changed(output / "candidates" / (model_id + ".json"), json_bytes(candidate))
    index = {"schema": SCHEMA, "origin": "warthunder_reference", "historical_verified": False,
             "admission": "candidate_only", "cache_root": cache_root.as_posix(),
             "nations": list(NATIONS), "count": len(rows), "entries": rows,
             "errors": errors, "deep_ids": sorted(deep), "model_manifest": "model_candidates.json"}
    write_changed(output / "index.json", json_bytes(index))
    report = {"schema": SCHEMA, "entries": len(rows), "per_nation": {n: sum(r["nation_directory"] == n for r in rows) for n in NATIONS},
              "deep_candidates": sorted(deep), "source_errors": len(errors),
              "model_candidates": len(models["models"]), "rejected_model_reports": len(models["rejected"]),
              "exact_model_links": sum(bool(r["model_report_paths"]) for r in rows),
              "index_sha256": sha256(json_bytes(index)), "historical_verified": False,
              "combat_vehicles_admitted": 0, "models_published": 0,
              "importer_sha256": sha256(Path(__file__).read_bytes())}
    write_changed(output / "IMPORT_REPORT.json", json_bytes(report))
    return report


def main() -> int:
    # Stable readable redirected logs on Windows regardless of the legacy console code page.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-root", type=Path, default=Path("E:/AIprogram/tank_data/cache"))
    parser.add_argument("--model-root", type=Path, default=Path("E:/AIprogram/aimodel"))
    parser.add_argument("--output", type=Path, default=REPOSITORY / "assets/reference_data")
    args = parser.parse_args()
    try:
        if args.output.resolve() != (REPOSITORY / "assets/reference_data").resolve():
            raise ValueError("CLI output is restricted to this repository's assets/reference_data directory")
        print(json.dumps(import_all(args.cache_root, args.model_root, args.output), ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError) as error:
        print("IMPORT FAILED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
