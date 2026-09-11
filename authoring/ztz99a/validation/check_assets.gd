extends SceneTree

var failed := false
var report: Array = []

func verify(label: String, ok: bool, details = null) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label + " " + str(details))
	report.append({"name": label, "pass": ok, "details": details})
	failed = failed or not ok

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var base := ProjectSettings.globalize_path("res://../../../assets/vehicles/ztz99a").simplify_path()
	for budget in [4000, 2000, 1000]:
		var path := base.path_join("ztz99a_%s.glb" % budget)
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(path, state)
		verify("%s glTF parse" % budget, error == OK, error)
		if error != OK:
			continue
		var tank := doc.generate_scene(state)
		root.add_child(tank)
		var triangle_count := 0
		var pbr_ok := true
		var mesh_count := 0
		for node in tank.find_children("*", "MeshInstance3D", true, false):
			mesh_count += 1
			for surface in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var indices = arrays[Mesh.ARRAY_INDEX]
				triangle_count += (indices.size() if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
				var mat = node.get_active_material(surface)
				pbr_ok = pbr_ok and mat is StandardMaterial3D and mat.normal_enabled and mat.normal_texture != null and mat.albedo_texture != null and mat.roughness_texture != null and mat.metallic_texture != null and mat.ao_enabled
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("ztz99a_%s.manifest.json" % budget)))
		verify("%s engine triangle count" % budget, triangle_count == int(manifest.actual_triangles) and triangle_count <= budget, triangle_count)
		verify("%s engine PBR channels" % budget, pbr_ok, mesh_count)
		var turret = tank.find_child("turret", true, false)
		var barrel = tank.find_child("barrel", true, false)
		var recoil = tank.find_child("gun_recoil", true, false)
		var muzzle = tank.find_child("muzzle", true, false)
		verify("%s independent motion nodes" % budget, turret != null and barrel != null and recoil != null and muzzle != null)
		if muzzle != null:
			verify("%s muzzle meter scale and -Z forward" % budget, muzzle.global_position.distance_to(Vector3(0, 2.06, -7.20)) < 0.003, str(muzzle.global_position))
			var before: Vector3 = muzzle.global_position
			turret.rotation.y = 0.7
			verify("%s turret rotation propagates" % budget, muzzle.global_position.distance_to(before) > 2.0)
			var pre_elevation: Vector3 = muzzle.global_position
			barrel.rotation.x = 0.18
			verify("%s gun elevation propagates" % budget, absf(muzzle.global_position.y - pre_elevation.y) > 0.5)
			turret.rotation = Vector3.ZERO
			barrel.rotation = Vector3.ZERO
			verify("%s pose restores" % budget, muzzle.global_position.distance_to(before) < 0.003)
			recoil.position.z += 0.15
			verify("%s recoil travel" % budget, absf(muzzle.global_position.z - before.z - 0.15) < 0.003)
		tank.queue_free()
		await process_frame
	var file := FileAccess.open("res://../godot_verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "checks": report, "engine": Engine.get_version_info()}, "  "))
	print("ZTZ99A_GODOT_CHECKS_PASS" if not failed else "ZTZ99A_GODOT_CHECKS_FAIL")
	quit(1 if failed else 0)
