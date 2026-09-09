"""Refresh original procedural-art provenance; run from any working directory."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {
    "house_warehouse_wall_tree_rocks": ["scripts/art/world_art_kit.gd", "scripts/art/world_props.gd"],
    "ground_and_roads": ["scripts/maps/village_world.gd", "scripts/maps/industrial_world.gd"],
    "destructible_shed_and_brick": ["scripts/art/special_structures.gd", "scripts/art/destructible_section.gd", "scripts/art/structure_collapse.gd", "scripts/art/structure_dust.gd"],
    "wreck_effects": ["scripts/damage/recovery_visuals.gd", "scripts/damage/wreck_turret_motion.gd"],
    "shared_rendering": ["scripts/art/art_palette.gd", "scripts/art/static_art_batch.gd", "scripts/art/world_lighting.gd", "assets/art_palette.json"],
}
data = {
    "schema_version": 1,
    "author": "MCTHUNDER project, original procedural geometry and shaders/materials",
    "source": "Original project scripts; no extracted game models, textures, or third-party artwork",
    "license_status": "Project-authored source; redistribution with this project allowed; no third-party attribution obligations",
    "redistribute_source_allowed": True,
    "generator": "authoring/update_world_manifest.py",
    "runtime_generation": "Godot 4.7.2-stable GDScript; no Blender or Python needed to play",
    "scale": "1 Godot unit = 1 meter; Y up, forward -Z",
    "assets": [{"id": key, "purpose": key.replace("_", " "), "files": [
        {"path": path, "sha256": hashlib.sha256((ROOT / path).read_text(encoding="utf-8").encode("utf-8")).hexdigest()}
        for path in paths]} for key, paths in GROUPS.items()],
}
destination = ROOT / "assets/world_art.manifest.json"
destination.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(destination)
