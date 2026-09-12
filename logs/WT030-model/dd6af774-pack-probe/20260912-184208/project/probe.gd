extends SceneTree
func _init() -> void:
	var path := "res://assets/vehicles/binding/vehicle.glb"
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var ok := FileAccess.file_exists(path) and not FileAccess.get_sha256(path).is_empty() and document.append_from_file(path,state)==OK
	print("RAW_MODEL_PACK_CHECKS_PASS" if ok else "RAW_MODEL_PACK_CHECKS_FAIL")
	quit(0 if ok else 1)
