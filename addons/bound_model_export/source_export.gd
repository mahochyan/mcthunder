@tool
extends EditorExportPlugin
## Resource import exports .scn replacements; bindings also need original GLB bytes.
const REGISTRY := "res://configs/vehicles/model_sources.json"

func _get_name() -> String: return "BoundModelSources"

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not registry is Dictionary or registry.get("schema_version")!=1 or not registry.get("models") is Dictionary:
		push_error("BoundModelSources: malformed source registry"); return
	for id in registry.models:
		var source: Variant=registry.models[id]
		if not source is Dictionary:
			push_error("BoundModelSources: malformed source "+str(id)); continue
		if source.get("delivery_status")!="delivered": continue
		var path := str(source.get("path",""))
		var relative := path.trim_prefix("res://")
		if source.get("id")!=id or not path.begins_with("res://assets/vehicles/") or not path.ends_with(".glb") or relative.contains(":") or relative.contains("\\") or relative.contains("%") or relative.split("/").has("..") or relative.split("/").has(".") or relative.split("/").has(""):
			push_error("BoundModelSources: invalid source path/identity "+str(id)); continue
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path).to_lower()!=str(source.get("sha256","")).to_lower():
			push_error("BoundModelSources: missing or changed artifact "+str(id)); continue
		add_file(path,FileAccess.get_file_as_bytes(path),false)
