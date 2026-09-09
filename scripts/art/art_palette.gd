class_name ArtPalette
extends RefCounted
## Shared, immutable-by-convention materials. Never tint a shared material per vehicle.
static var _definition: Dictionary = {}
static var _materials: Dictionary = {}

static func definition() -> Dictionary:
	if _definition.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_palette.json"))
		if parsed is Dictionary: _definition = parsed
	return _definition

static func color(key: String) -> Color:
	return Color(str(definition().get("colors",{}).get(key,"ff00ff")))

static func material(key: String, vertex_colors: bool = false, two_sided: bool = false) -> StandardMaterial3D:
	var cache_key := key+str(vertex_colors)+str(two_sided)
	if not _materials.has(cache_key):
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Palette_"+key
		mat.albedo_color = Color.WHITE if vertex_colors else color(key)
		mat.vertex_color_use_as_albedo = vertex_colors
		mat.roughness = float(definition().get("roughness",0.9))
		mat.metallic = 0.2 if key == "steel" else 0.0
		if two_sided: mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[cache_key] = mat
	return _materials[cache_key]
