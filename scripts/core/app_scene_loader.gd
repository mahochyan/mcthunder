class_name AppSceneLoader
extends RefCounted
## Script inheritance shares global classes with the live world. Resolve on the
## main thread, between AppFlow's yielding/cancellable preparation stages.
static func load_scene(path: String) -> Dictionary:
	if not path.begins_with("res://scenes/") or not path.ends_with(".tscn") or not ResourceLoader.exists(path,"PackedScene"):
		return {"ok":false,"reason":LocalizationService.text("flow_missing_scene") % path}
	var scene := ResourceLoader.load(path,"PackedScene") as PackedScene
	return {"ok":scene != null,"scene":scene,"reason":"" if scene != null else LocalizationService.text("flow_missing_scene") % path}
